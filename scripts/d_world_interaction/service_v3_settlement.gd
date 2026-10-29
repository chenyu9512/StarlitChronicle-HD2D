extends RefCounted
## M0.1: regional services must commit inventory, currency, recovery, clock and
## guild receipts as a single durable V3 transaction. UI/world animation is
## deliberately outside the transaction so failed saves cannot fake success.
const Tx = preload("res://scripts/d_world_interaction/world_object_settlement.gd")

static func execute(progress: Object, core: Object, town_life: Object,
        events: Object, action: String, region_id: String) -> Dictionary:
    if progress == null or core == null or town_life == null or events == null:
        return {"ok":false,"reason":"missing_service_dependency"}
    if not (action.begins_with("buy:") or action.begins_with("sell:")
            or action.begins_with("forge:") or action in ["rest","blessing","guild"]):
        return {"ok":false,"reason":"unsupported_service_action"}
    return Tx.transact(progress,func() -> Dictionary:
        var message: String = ""
        var changed: bool = false
        if action.begins_with("buy:"):
            var item_id: String = action.trim_prefix("buy:")
            message = core.buy(item_id)
            changed = message.begins_with("购买了 ")
            if changed:
                events.record("shop_purchase",{"region":region_id,"item":item_id})
        elif action.begins_with("sell:"):
            message = core.sell(action.trim_prefix("sell:"))
            changed = message.begins_with("出售获得 ")
        elif action.begins_with("forge:"):
            message = core.forge(action.trim_prefix("forge:"))
            changed = message.begins_with("锻造成品")
            if changed:
                events.record("forge_success",{"region":region_id})
        elif action == "rest":
            if progress.gold < 30:
                message = "金币不足，无法入住。"
            else:
                progress.gold -= 30
                events.advance_time(480)
                progress.heal_all()
                events.record("inn_rest",{"region":region_id})
                message = "在客栈安睡一晚，队伍 HP / MP 已全部恢复。"
                changed = true
        elif action == "blessing":
            if progress.gold < 20:
                message = "祝福需要 20 G。"
            else:
                progress.gold -= 20
                progress.heal_all()
                events.advance_time(35)
                events.record("shrine_blessing",{"region":region_id})
                message = "祈灯仪式完成，队伍 HP / MP 全部恢复。"
                changed = true
        elif action == "guild":
            message = town_life.guild_action(region_id,progress)
            # Preserve the existing guild-visit event even on active/claimed
            # contracts; the event and the claim must persist in one snapshot.
            events.record("guild_visit",{"region":region_id})
            changed = true
        return {"ok":true,"changed":changed,"message":message}
    )
