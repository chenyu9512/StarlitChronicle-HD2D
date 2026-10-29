# Main2 CI unified QA

The sole automatically triggered Main2 QA workflow is .github/workflows/main2-ci.yml.
Twelve previously auto-triggered specialized workflows remain available through workflow_dispatch and no longer trigger on overlapping pushes or qa marker file changes. Other existing manual workflows are unchanged.

Each relevant push uses exactly one Godot import in an automatic QA job, caches the official 4.7.2 binary, runs relevant tests once each for source-only checks and all map/art/system gates on release-eligible pushes, and preserves the outcomes. Only successful QA allows the separately validated, pruned Runtime publication via workflow_call. Main is not modified.

Known failures are not waived: full smoke #36 at 893573d reported 7 failing smoke tests relating to map reachability and art; all seven are included in the automatic affected-domain suite. The separate seven-gate assets failure #12 remains visible through manual acceptance; investigate retired art records and actual missing resources rather than declaring them successful.

Runtime verification is intentionally repeated against the PRUNED playable snapshot, because it tests a different build from the source checkout.
