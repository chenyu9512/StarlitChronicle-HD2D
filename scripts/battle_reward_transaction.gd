extends RefCounted
## A-line reward idempotency contract. D-line performs the actual reward/quest/save transaction.
## The ledger lives inside the already-serialized FirstAct V3 rpg Dictionary; no save migration.

const LEDGER_KEY: String = "battle_reward_transactions"

## For bosses the same authored ID always yields the same key, including after reload.
## Random encounters receive a unique ID once, at battle start (not during settlement).
static func make_id(is_boss: bool, chapter: int, boss_id: String = "") -> String:
    if is_boss:
        var stable_id: String = boss_id.strip_edges()
        if stable_id.is_empty():
            return ""
        return "boss:%s" % stable_id
    return "random:%s" % Crypto.new().generate_random_bytes(16).hex_encode()

static func valid_id(transaction_id: String) -> bool:
    if transaction_id.is_empty() or transaction_id.length() > 160:
        return false
    if transaction_id.begins_with("boss:"):
        return transaction_id.length() > 5
    if transaction_id.begins_with("random:"):
        return transaction_id.length() == 39
    return false

static func already_applied(rpg: Dictionary, transaction_id: String) -> bool:
    if not valid_id(transaction_id):
        return false
    var existing: Variant = rpg.get(LEDGER_KEY,{})
    return existing is Dictionary and existing.has(transaction_id)

## Invoke only after all reward, job XP, drops, boss flags and quest changes are
## applied in memory, BEFORE D-line persists that entire progress snapshot.
## If save fails D-line must restore its entire pre-settlement progress snapshot.
static func mark_applied(rpg: Dictionary, transaction_id: String, details: Dictionary = {}) -> bool:
    if not valid_id(transaction_id):
        return false
    var stored: Variant = rpg.get(LEDGER_KEY,{})
    if not (stored is Dictionary):
        return false
    var records: Dictionary = stored
    if records.has(transaction_id):
        return false
    var updated: Dictionary = records.duplicate(true)
    updated[transaction_id] = {
        "chapter": clampi(int(details.get("chapter",0)),0,72),
        "boss": transaction_id.begins_with("boss:"),
        "xp": maxi(0,int(details.get("xp",0))),
        "gold": maxi(0,int(details.get("gold",0)))
    }
    rpg[LEDGER_KEY] = updated
    return true
