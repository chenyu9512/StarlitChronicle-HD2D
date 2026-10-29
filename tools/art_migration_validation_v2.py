"""Read-only migration ledger resolver. A valid file path is not visual approval."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

def migration_index():
    obj = json.loads((ROOT / "data/assets/c_third_party_only_migration_v1.json").read_text(encoding="utf-8"))
    assert len(obj.get("mappings", [])) >= 616, "Migration ledger incomplete"
    result = {}
    for row in obj["mappings"]:
        a, b = row.get("old_path", ""), row.get("new_source", "")
        if a.startswith("assets/") and b.startswith("assets/art/external/cc0_named_v1/"):
            assert a not in result, "Duplicate legacy redirect: " + a
            result[a] = b
    return result

def exists_or_migrated(source, migration):
    relative = source.removeprefix("res://")
    if not relative.startswith("assets/") or ".." in Path(relative).parts:
        return False
    if (ROOT / relative).is_file():
        return True
    mapped = migration.get(relative, "")
    return bool(mapped and (ROOT / mapped).is_file())
