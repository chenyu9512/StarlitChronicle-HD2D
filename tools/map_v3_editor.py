#!/usr/bin/env python3
"""Starlit Chronicle V3 visual region painter: stdlib only (Windows friendly).

Usage: python tools/map_v3_editor.py
Edits a selected 72x48 map without touching other maps; saves JSON atomically.
V3 manifest is the shipped game data. Export/import allows one-level handoff.
"""
from __future__ import annotations
import argparse
import json
import os
import tempfile
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/levels/world_levels_v3.json"
PALETTE = {"coastal":"#688d73","highland":"#879a8e","volcanic":"#a07562",
           "archipelago":"#518795","mistforest":"#658a7e","badlands":"#a58d6c",
           "celestial":"#9898bb","metropolis":"#938b91"}
TOOLS = ["road","trail","obstacle","water","clearing","floor","wall","erase"]
CELL = 12
WIDTH, HEIGHT = 72, 48

def parse(source: Path = SOURCE) -> dict:
    data = json.loads(source.read_text(encoding="utf-8"))
    assert data["schema"] == "starlit.world_level_collection.v3"
    assert len(data["levels"]) == 40
    for key, level in data["levels"].items():
        assert key == level["map_id"] and level["size"] == [WIDTH, HEIGHT]
        for item in level["paint_overrides"] + level["collision_overrides"]:
            x,y = item["cell"]
            assert 0 <= x < WIDTH and 0 <= y < HEIGHT, (key, item)
    return data

def atomic_save(target: Path, data: dict) -> None:
    target.parent.mkdir(parents=True,exist_ok=True)
    blob = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    fd, name = tempfile.mkstemp(prefix=".map_v3_",suffix=".json",dir=target.parent)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as stream:
            stream.write(blob)
        os.replace(name,target)
    finally:
        if os.path.exists(name): os.unlink(name)

def main() -> None:
    store = parse()
    window = tk.Tk()
    window.title("星灯纪行｜地图 V3 独立关卡编辑器")
    window.geometry("1180x760")
    window.minsize(1050,700)
    body = ttk.Frame(window,padding=8)
    body.pack(fill="both",expand=True)
    toolbar = ttk.Frame(body)
    toolbar.pack(fill="x",pady=5)
    maps = sorted(store["levels"])
    selected = tk.StringVar(value=maps[0])
    tool = tk.StringVar(value="road")
    status = tk.StringVar(value="左键绘制 / 右键擦除；线路笔刷连续点击创建节点，双击结束。")
    ttk.Label(toolbar,text="地区：").pack(side="left")
    picker = ttk.Combobox(toolbar,textvariable=selected,values=maps,width=22,state="readonly")
    picker.pack(side="left",padx=6)
    ttk.Label(toolbar,text="画笔：").pack(side="left",padx=(8,0))
    ttk.Combobox(toolbar,textvariable=tool,values=TOOLS,width=13,state="readonly").pack(side="left")
    canvas = tk.Canvas(body,width=WIDTH*CELL,height=HEIGHT*CELL,bg="#203b48",highlightthickness=1)
    canvas.pack(side="left",anchor="nw",padx=(0,12),pady=6)
    side = ttk.Frame(body)
    side.pack(side="left",fill="both",expand=True)
    info = tk.Text(side,width=34,height=23,wrap="word",font=("Microsoft YaHei UI",10))
    info.pack(fill="both",expand=True)
    ttk.Label(body,textvariable=status,wraplength=1110).pack(side="bottom",fill="x")
    drawing: dict[str,list] = {"current":[]}
    dirty = {"value":False}
    COLORS = {"road":"#d7bd85","trail":"#b6a987","obstacle":"#4c5262","water":"#3b81a7",
              "clearing":"#95b691","floor":"#a9c38a","wall":"#535663"}
    def level():
        return store["levels"][selected.get()]
    def coords(event):
        return max(0,min(WIDTH-1,event.x//CELL)),max(0,min(HEIGHT-1,event.y//CELL))
    def point_cell(raw):
        return tuple(map(int,raw))
    def paint_line(points,color,size=2):
        flat=[]
        for p in points: flat.extend((p[0]*CELL+CELL/2,p[1]*CELL+CELL/2))
        if len(flat)>=4:
            canvas.create_line(*flat,fill=color,width=size*CELL/2,smooth=False,capstyle="round",joinstyle="round")
    def render(*_):
        canvas.delete("all")
        entry=level()
        biome=entry["biome"]
        canvas.create_rectangle(0,0,WIDTH*CELL,HEIGHT*CELL,fill=PALETTE.get(biome,"#74877c"),outline="")
        for key,color in [("obstacles",COLORS["obstacle"]),("waterways",COLORS["water"])]:
            for record in entry[key]:
                paint_line(record["points"],color,int(record.get("width",1))*2)
        for record in entry["roads"]:
            paint_line(record["points"],COLORS["road"] if record["id"]!="route-secret" else COLORS["trail"],int(record.get("width",1))*2+1)
        for entry_c in entry["clearings"]:
            x,y=entry_c["center"];r=entry_c.get("radius",3)
            canvas.create_oval((x-r)*CELL,(y-r)*CELL,(x+r)*CELL,(y+r)*CELL,fill=COLORS["clearing"],outline="")
        for item in entry["paint_overrides"]:
            x,y=item["cell"]
            color=COLORS["wall"] if item.get("blocked",False) else COLORS["floor"]
            canvas.create_rectangle(x*CELL,y*CELL,(x+1)*CELL,(y+1)*CELL,fill=color,outline="")
        for item in entry["collision_overrides"]:
            x,y=item["cell"]
            canvas.create_rectangle(x*CELL+2,y*CELL+2,(x+1)*CELL-2,(y+1)*CELL-2,
                                    outline="#df6872" if item["blocked"] else "#d7e7e2",width=2)
        if drawing["current"]: paint_line(drawing["current"],"#fff2a4",2)
        canvas.create_oval(10*CELL,23*CELL,11*CELL,24*CELL,fill="#f5da8a",outline="")
        canvas.create_rectangle(0,0,WIDTH*CELL,HEIGHT*CELL,outline="#e9ca91",width=2)
        info.delete("1.0","end")
        info.insert("end", f'名称：{entry["title"]}\n地区：{entry["biome"]}\n'
                    f'设计：{entry["design_intent"]}\n大小：72 × 48\n'
                    f'道路：{len(entry["roads"])}\n'
                    f'地形障碍：{len(entry["obstacles"])}\n'
                    f'水域：{len(entry["waterways"])}\n'
                    f'手工绘制：{len(entry["paint_overrides"])}格\n'
                    f'碰撞覆盖：{len(entry["collision_overrides"])}格\n\n'
                    "操作：\n• road / trail 连续点创建一条路线；双击收笔\n"
                    "• obstacle / water 绘制折线\n• clearing 添加空地\n"
                    "• floor / wall 单格修正地表和阻挡\n"
                    "• erase 右键抹除最近标记\n"
                    "• 修改后点保存全部地图，游戏即加载新配置。\n"
                    "• 导出/导入支持每个地区独立的 JSON 交接。")
    def end_polyline():
        pts=drawing["current"]
        if len(pts)>1:
            selected_tool=drawing.get("kind","road")
            key="roads" if selected_tool in ("road","trail") else ("obstacles" if selected_tool=="obstacle" else "waterways")
            record={"id":"hand-"+str(len(level()[key])+1),"points":[list(p) for p in pts],"width":1 if selected_tool!="water" else 2}
            if key!="roads":record["tile_row"]=6
            level()[key].append(record)
            dirty["value"]=True
        drawing["current"]=[]
        render()
    def click(event):
        pos=coords(event)
        choice=tool.get()
        if choice in ("road","trail","obstacle","water"):
            if drawing["current"] and drawing["kind"]!=choice:end_polyline()
            drawing["kind"]=choice
            if not drawing["current"] or drawing["current"][-1]!=pos:
                drawing["current"].append(pos)
                dirty["value"]=True
        elif choice=="clearing":
            level()["clearings"].append({"id":"hand-"+str(len(level()["clearings"])+1),"center":list(pos),"radius":3})
            dirty["value"]=True
        elif choice in ("floor","wall"):
            overrides=level()["paint_overrides"]
            overrides[:]=[v for v in overrides if point_cell(v["cell"])!=pos]
            overrides.append({"cell":list(pos),"row":1 if choice=="floor" else 6,"blocked":choice=="wall"})
            dirty["value"]=True
        else: erase(event)
        render()
    def erase(event):
        pos=coords(event)
        selected_level=level()
        for key in ("paint_overrides","collision_overrides","clearings"):
            target=selected_level[key]
            filtered=[v for v in target if point_cell(v.get("cell",v.get("center",[-10,-10])))!=pos]
            if len(filtered)!=len(target):
                target[:]=filtered;dirty["value"]=True
        render()
    def save():
        end_polyline()
        atomic_save(SOURCE,store)
        dirty["value"]=False
        status.set("已保存：全部关卡 JSON；游戏将使用当前地图修正。")
    def export_one():
        end_polyline()
        path=filedialog.asksaveasfilename(defaultextension=".json",initialfile=selected.get()+".json")
        if path:atomic_save(Path(path),level())
    def import_one():
        path=filedialog.askopenfilename(filetypes=[("Map V3 JSON","*.json")])
        if not path:return
        incoming=json.loads(Path(path).read_text(encoding="utf-8"))
        if incoming.get("map_id") != selected.get():
            messagebox.showerror("地区不符","只能导入当前地区的独立关卡文件。")
            return
        if incoming.get("size") != [WIDTH,HEIGHT] or incoming.get("schema_version") != 3:
            messagebox.showerror("文件格式","这不是可用的 V3 独立关卡。")
            return
        store["levels"][selected.get()]=incoming
        dirty["value"]=True
        render()
    controls=ttk.Frame(side)
    controls.pack(fill="x",pady=10)
    for title,fn in [("完成路线",end_polyline),("保存全部地图",save),("导出单地区",export_one),("导入单地区",import_one)]:
        ttk.Button(controls,text=title,command=fn).pack(fill="x",pady=3)
    def changing(*_):
        drawing["current"]=[]
        render()
    selected.trace_add("write",changing)
    canvas.bind("<Button-1>",click)
    canvas.bind("<Double-Button-1>",lambda e:end_polyline())
    canvas.bind("<Button-3>",erase)
    def close():
        if dirty["value"] and not messagebox.askyesno("关卡未保存","修改尚未保存，确定退出？"):return
        window.destroy()
    window.protocol("WM_DELETE_WINDOW",close)
    render()
    window.mainloop()

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--check",action="store_true",help="Validate all level files without starting GUI")
    args=parser.parse_args()
    if args.check:
        parsed=parse()
        print(f'PASS: {len(parsed["levels"])} editable Godot 72x48 V3 maps')
    else:
        main()
