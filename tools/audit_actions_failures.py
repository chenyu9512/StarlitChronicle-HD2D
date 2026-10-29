#!/usr/bin/env python3
"""Inventory historical failed GitHub Actions runs with per-job failure steps.

Uses only GitHub REST + Python stdlib; requires GH_TOKEN / GITHUB_TOKEN with
read-only Actions access. The output never includes raw logs or secrets.
"""
import argparse
import collections
import csv
import json
import os
from pathlib import Path
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


def github_get(path: str, token: str):
    request = Request(
        "https://api.github.com" + path,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer " + token,
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "StarlitChronicle-Actions-Audit",
        },
    )
    for retry in range(4):
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except HTTPError as exc:
            if exc.code not in (429, 500, 502, 503, 504) and not (
                exc.code == 403 and exc.headers.get("Retry-After")
            ):
                raise
            delay = int(exc.headers.get("Retry-After", "0") or "0")
            time.sleep(min(max(delay, 2 ** retry), 30))
        except (TimeoutError, URLError):
            time.sleep(2 ** retry)
    raise RuntimeError("GitHub API retry limit exceeded for: " + path)


def all_failed_runs(repository: str, token: str, maximum: int):
    seen = set()
    page = 1
    runs = []
    while len(runs) < maximum:
        data = github_get(
            f"/repos/{repository}/actions/runs?status=failure&per_page=100&page={page}",
            token,
        )
        batch = data.get("workflow_runs", [])
        if not batch:
            break
        for run in batch:
            if run["id"] not in seen:
                runs.append(run)
                seen.add(run["id"])
                if len(runs) >= maximum:
                    break
        if len(batch) < 100:
            break
        page += 1
    return runs


def inspect_run(repository: str, token: str, run: dict):
    jobs = []
    page = 1
    while True:
        response = github_get(
            f"/repos/{repository}/actions/runs/{run['id']}/jobs?per_page=100&page={page}",
            token,
        )
        batch = response.get("jobs", [])
        jobs.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    steps = [s for job in jobs for s in (job.get("steps") or [])]
    failures = [s.get("name", "?") for s in steps if s.get("conclusion") == "failure"]
    if not jobs:
        category = "job_metadata_missing"
    elif not steps:
        category = "no_execution_steps"
    elif failures:
        category = "executed_step_failure"
    elif any(job.get("conclusion") == "failure" for job in jobs):
        category = "failed_without_named_step"
    else:
        category = "rerun_changed_status"
    return {
        "run_id": run["id"],
        "workflow": run.get("name", ""),
        "event": run.get("event", ""),
        "branch": run.get("head_branch", ""),
        "head_sha": run.get("head_sha", ""),
        "created_at": run.get("created_at", ""),
        "updated_at": run.get("updated_at", ""),
        "run_attempt": run.get("run_attempt", 1),
        "url": run.get("html_url", ""),
        "classification": category,
        "job_count": len(jobs),
        "step_count": len(steps),
        "failed_steps": "; ".join(failures),
    }


def emit(records: list[dict], directory: Path, repository: str):
    directory.mkdir(parents=True, exist_ok=True)
    keys = [
        "run_id", "workflow", "event", "branch", "head_sha",
        "created_at", "updated_at", "run_attempt", "url",
        "classification", "job_count", "step_count", "failed_steps",
    ]
    with (directory / "actions-failure-ledger.csv").open(
        "w", encoding="utf-8", newline=""
    ) as file:
        writer = csv.DictWriter(file, fieldnames=keys)
        writer.writeheader()
        writer.writerows(records)
    counts = collections.Counter(r["classification"] for r in records)
    workflow_counts = collections.Counter(r["workflow"] for r in records)
    escape = lambda val: str(val).replace("|", "/").replace("\n", " ")
    lines = [
        "# GitHub Actions historical failed-run audit",
        "",
        f"Repository: `{repository}`",
        "",
        f"Historical failed runs in snapshot: **{len(records)}**",
        "",
        "These are individual historical run IDs, not a list of currently broken code.",
        "No-execution-step failures indicate a job did not begin recorded steps;",
        "the previously exhausted private-runner quota is a plausible shared cause,",
        "but a single run's metadata alone cannot establish its precise billing cause.",
        "A successful rerun may no longer appear in this failure-only snapshot.",
        "",
        "## Categories",
        "",
    ]
    lines.extend(f"- `{key}`: **{val}**" for key, val in sorted(counts.items()))
    lines.extend(["", "## Affected workflows", ""])
    lines.extend(f"- {escape(key)}: {val}" for key, val in workflow_counts.most_common())
    lines.extend([
        "", "## Per-run record", "",
        "| Run | Date (UTC) | Workflow | Class | Failed step |",
        "|---|---|---|---|---|",
    ])
    for r in records:
        lines.append(
            f"| [#{r['run_id']}]({r['url']}) | {escape(r['created_at'])} | "
            f"{escape(r['workflow'])} | `{r['classification']}` | "
            f"{escape(r['failed_steps'] or '—')} |"
        )
    (directory / "actions-failure-ledger.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )
    print(json.dumps({"runs": len(records), "categories": counts}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--output-dir", default="build/actions-audit")
    parser.add_argument("--max-runs", type=int, default=2000)
    args = parser.parse_args()
    if not args.repository or len(args.repository.split("/")) != 2:
        parser.error("--repository must be owner/name")
    if args.max_runs < 1:
        parser.error("--max-runs must be positive")
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        parser.error("GH_TOKEN or GITHUB_TOKEN is required (read-only Actions access)")
    runs = all_failed_runs(args.repository, token, args.max_runs)
    records = []
    for index, run in enumerate(runs, 1):
        try:
            records.append(inspect_run(args.repository, token, run))
        except (HTTPError, URLError, RuntimeError) as exc:
            records.append({
                "run_id": run["id"],
                "workflow": run.get("name", ""),
                "event": run.get("event", ""),
                "branch": run.get("head_branch", ""),
                "head_sha": run.get("head_sha", ""),
                "created_at": run.get("created_at", ""),
                "updated_at": run.get("updated_at", ""),
                "run_attempt": run.get("run_attempt", 1),
                "url": run.get("html_url", ""),
                "classification": "metadata_request_failed",
                "job_count": 0,
                "step_count": 0,
                "failed_steps": type(exc).__name__,
            })
        if index % 50 == 0:
            print(f"Audited {index}/{len(runs)} historical failures", flush=True)
    emit(records, Path(args.output_dir), args.repository)


if __name__ == "__main__":
    main()
