extends Node
## Ch17: real-time 180-second hospital oxygen rescue. Six player actions
## safely allocate all four power circuits before the existing boss fight.
const INITIAL: Dictionary = {"CANNON":55,"CITY_DEFENSE":20,"HOSPITAL":15,"RESIDENTIAL":10}
const ACTIONS: Array[String] = ["start_oxygen","connect_battery","cannon_zero",
    "hospital_25","residential_20","confirm_defense"]
const PROMPTS: Array[String] = [
    "岚音必须先接管医院手动供氧泵。",
    "供氧启动。请解除主炮与医院恶意并线。",
    "东库电池已接入。单独切断主炮。",
    "主炮已切断。医院供氧必须不低于25%。",
    "医院供氧正常。居民区供暖必须不低于20%。",
    "城防保留20%供电。核对四阀门总负荷。"]
const GOOD: Array[String] = [
    "启动180秒手动供氧","朔弦接入东库备用电池",
    "主炮阀门调整至0%","医院阀门调整至25%",
    "居民区阀门调整至20%","确认城防20%，负荷不超过100%"]
const BAD: Array[String] = [
    "直接拉闸医院和主炮","不接备用电池直接切线",
    "主炮升至80%","医院降至10%",
    "居民区降至5%","继续叠加超过100%的负荷"]

func _expired(state: Dictionary) -> bool:
    return int(state.get("step",0)) > 0 and not bool(state.get("done",false)) \
        and Time.get_unix_time_from_system() >= float(state.get("oxygen_deadline",0.0))

func get_prompt(state: Dictionary) -> Dictionary:
    if bool(state.get("done",false)):
        return {"done":true}
    var step: int = int(state.get("step",0))
    if step < 0 or step >= ACTIONS.size():
        return {}
    if _expired(state):
        return {"prompt":"180秒供氧倒计时已结束，必须重新执行安全操作。",
            "options":[{"id":"safe_restart","label":"隔离故障并重新启动"}]}
    var valves: Dictionary = state.get("valves",INITIAL)
    var seconds: int = maxi(0,int(ceil(float(state.get("oxygen_deadline",0.0))
        - Time.get_unix_time_from_system())))
    var timer: String = "\n供氧剩余%d秒" % seconds if step > 0 else ""
    return {"prompt":"赤炉主炉 %d/6\n%s%s\n炮口%d / 城防%d / 医院%d / 居民区%d" % [
        step+1,PROMPTS[step],timer,
        int(valves.get("CANNON",55)),int(valves.get("CITY_DEFENSE",20)),
        int(valves.get("HOSPITAL",15)),int(valves.get("RESIDENTIAL",10))],
        "options":[{"id":ACTIONS[step],"label":GOOD[step]},
            {"id":"unsafe","label":BAD[step]}]}

func apply_action(state: Dictionary, action_id: String) -> Dictionary:
    if bool(state.get("done",false)):
        return {"ok":false,"message":"主炉已安全停炮，不能重复结算。"}
    if _expired(state):
        if action_id != "safe_restart":
            return {"ok":false,"message":"供氧已超时，必须重新启动。"}
        state.clear()
        state["step"] = 0
        state["valves"] = INITIAL.duplicate(true)
        return {"ok":true,"done":false,"message":"故障已隔离，允许重新操作。"}
    var step: int = int(state.get("step",0))
    if step < 0 or step >= ACTIONS.size() or action_id != ACTIONS[step]:
        return {"ok":false,"message":"顺序不正确，不得牺牲医院或居民区供电。"}
    if step == 0:
        state["oxygen_deadline"] = Time.get_unix_time_from_system() + 180.0
    var valves: Dictionary = (state.get("valves",INITIAL) as Dictionary).duplicate(true)
    match step:
        1: state["hospital_decoupled"] = true
        2:
            if not bool(state.get("hospital_decoupled",false)):
                return {"ok":false,"message":"医院仍与主炮并线，禁止切断。"}
            valves["CANNON"] = 0
        3: valves["HOSPITAL"] = 25
        4: valves["RESIDENTIAL"] = 20
        5: valves["CITY_DEFENSE"] = 20
    state["valves"] = valves
    state["step"] = step+1
    if step == 5:
        var total: int = 0
        for value in valves.values():
            if int(value) < 0:
                return {"ok":false,"message":"不允许负值阀门配置。"}
            total += int(value)
        if total > 100 or not bool(state.get("hospital_decoupled",false)) \
                or int(valves.get("CANNON",-1)) != 0 \
                or int(valves.get("CITY_DEFENSE",0)) < 20 \
                or int(valves.get("HOSPITAL",0)) < 25 \
                or int(valves.get("RESIDENTIAL",0)) < 20:
            return {"ok":false,"message":"负荷超载或居民、医院保障不足。"}
        state["done"] = true
    return {"ok":true,"done":bool(state.get("done",false)),
        "message":"四阀门操作已完成当前阶段，真正的赤炉Boss仍需玩家击败。"}
