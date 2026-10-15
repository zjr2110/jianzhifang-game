# 剪纸坊
# game_state.gd - 全局状态与存档
extends Node

const SAVE_PATH := "user://jianzhi_save.json"

# 测试版全部免费开放
const TEST_MODE := true

# 纸张
const PAPERS := {
	"red": {"name": "大红宣纸", "color": Color(0.72, 0.07, 0.06), "value": 1.0, "price": 0,
		"desc": "最常见的剪纸用纸，色正耐看"},
	"peach": {"name": "桃红纸", "color": Color(0.86, 0.30, 0.42), "value": 1.1, "price": 120,
		"desc": "粉嫩喜气，适合小花样"},
	"wannian": {"name": "万年红", "color": Color(0.60, 0.03, 0.05), "fiber": 0.8, "value": 1.25, "price": 180,
		"desc": "传统矿物染色，经年不褪"},
	"white": {"name": "本色宣纸", "color": Color(0.93, 0.89, 0.80), "fiber": 1.6, "value": 1.2, "price": 150,
		"desc": "未染色的生宣，纤维清晰，适合素雅剪影"},
	"gold": {"name": "洒金红纸", "color": Color(0.66, 0.05, 0.05), "gold": 1.0, "value": 1.8, "price": 300,
		"desc": "纸面洒满金箔碎屑，喜庆贵气"},
	"glossy": {"name": "蜡光纸", "color": Color(0.74, 0.05, 0.08), "gloss": 1.0, "fiber": 0.3, "value": 1.4, "price": 260,
		"desc": "表面打蜡，光亮挺括"},
	"indigo": {"name": "靛蓝染纸", "color": Color(0.14, 0.23, 0.46), "cloud": 1.9, "value": 1.7, "price": 350,
		"desc": "手工蓝染，颜色有深浅变化"},
	"ink": {"name": "墨色纸", "color": Color(0.11, 0.10, 0.10), "fiber": 1.2, "value": 1.6, "price": 400,
		"desc": "乌黑的剪影纸，配浅色衬底最显精神"},
	"foil": {"name": "金箔纸", "color": Color(0.88, 0.70, 0.30), "metal": 1.0, "fiber": 0.2, "value": 2.6, "price": 800,
		"desc": "真金箔贴面，富丽堂皇"},
}
const PAPER_ORDER := ["red", "peach", "wannian", "white", "gold", "glossy", "indigo", "ink", "foil"]

# 折法
const FOLDS := {
	"none": {"name": "不折", "value": 1.15, "price": 0, "desc": "单层刻纸，图案自由，不对称"},
	"half": {"name": "对折", "value": 0.95, "price": 0, "desc": "左右对称，剪人物、动物剪影"},
	"four": {"name": "四折", "value": 1.0, "price": 100, "desc": "上下左右都对称"},
	"five": {"name": "五角折", "value": 1.3, "price": 250, "desc": "五瓣花、五角星，十层一起剪"},
	"twelve": {"name": "六角窗花", "value": 1.35, "price": 200, "desc": "十二层，雪花、六角窗花"},
	"eight": {"name": "八折团花", "value": 1.0, "price": 0, "desc": "方纸折八层，四方对称的团花"},
	"sixteen": {"name": "十六折", "value": 1.5, "price": 400, "desc": "八角形，十六层，花样最繁"},
	"accordion": {"name": "连续拉花", "value": 1.3, "price": 300, "desc": "长条纸来回折，展开一排连续图案"},
}
const FOLD_ORDER := ["eight", "half", "none", "four", "twelve", "five", "sixteen", "accordion"]

# 纹样印章
const STAMPS := {
	"moon": {"name": "月牙纹", "price": 0},
	"saw": {"name": "锯齿纹", "price": 0},
	"drop": {"name": "水滴纹", "price": 0},
	"hole": {"name": "圆孔", "price": 60},
	"leaf": {"name": "柳叶纹", "price": 80},
	"plum": {"name": "梅花纹", "price": 120},
	"scale": {"name": "鱼鳞纹", "price": 180},
	"cloud": {"name": "云纹", "price": 200},
	"coin": {"name": "铜钱纹", "price": 220},
	"fret": {"name": "回纹", "price": 260},
}
const STAMP_ORDER := ["moon", "saw", "drop", "hole", "leaf", "plum", "scale", "cloud", "coin", "fret"]

# 工具
const TOOLS := {
	"scissors": {"name": "剪刀", "price": 0},
	"knife": {"name": "直线刻刀", "price": 150},
}

var coins := 0
var owned := {}
var selected_paper := "red"
var selected_fold := "eight"
var total_sold := 0
var best_price := 0
var first_launch_done := false
# 成交作品记录
var works: Array = []
var next_work_id := 1
# 铜钱收支明细
var ledger: Array = []
# 累计统计
var stats := {"cuts": 0, "hidden": 0, "papers": {}, "folds": {}, "stamps": {}}
var player_level := ""
var sound_on := true
var skip_splash := false
var tutorial_done := false

# 当前一局
var mode := "free"
var cut_paper := "red"
var cut_fold := "eight"
var current_template := {}
var current_target := {}
var current_model = null
var current_result := {}
var tutorial_active := false
var resume_cut := false

const WORKS_DIR := "user://works"
const KEEP_MASKS := 10
const KEEP_THUMBS := 120


func _ready() -> void:
	load_game()


func item_info(id: String) -> Dictionary:
	for table in [PAPERS, FOLDS, STAMPS, TOOLS]:
		if table.has(id):
			return table[id]
	return {}


func price_of(id: String) -> int:
	if id.begins_with("tpl:"):
		for t in preload("res://scripts/templates.gd").all():
			if "tpl:" + t["id"] == id:
				return int(t["price"])
		return 0
	return int(item_info(id).get("price", 0))


func is_owned(id: String) -> bool:
	return TEST_MODE or price_of(id) == 0 or owned.get(id, false)


# 价格说明文字
func price_text(id: String) -> String:
	var p := price_of(id)
	if p == 0:
		return "基础款"
	if TEST_MODE:
		return "原价 %d 铜钱 · 测试版免费" % p
	if owned.get(id, false):
		return "已拥有"
	return "解锁：%d 铜钱" % p


func buy(id: String) -> bool:
	if is_owned(id):
		return true
	var price := price_of(id)
	if coins < price:
		return false
	coins -= price
	owned[id] = true
	_log("buy", -price, "解锁 · " + item_name(id), {"item": id})
	save_game()
	return true


# 物品名称
func item_name(id: String) -> String:
	if id.begins_with("tpl:"):
		for t in preload("res://scripts/templates.gd").all():
			if "tpl:" + t["id"] == id:
				return "样稿「%s」" % t["name"]
		return "样稿"
	return str(item_info(id).get("name", id))


# 物品类别
func item_kind(id: String) -> String:
	if id.begins_with("tpl:"):
		return "样稿"
	if PAPERS.has(id):
		return "纸张"
	if FOLDS.has(id):
		return "折法"
	if STAMPS.has(id):
		return "纹样"
	if TOOLS.has(id):
		return "工具"
	return "其他"


func _log(kind: String, amount: int, title: String, extra := {}) -> void:
	var e := {"t": int(Time.get_unix_time_from_system()), "amount": amount, "kind": kind, "title": title}
	e.merge(extra)
	ledger.append(e)


func record_sale(price: int) -> void:
	coins += price
	total_sold += 1
	best_price = maxi(best_price, price)
	save_game()


# 成交后保存作品
func record_work(result: Dictionary, model, price: int, buyer: String, hidden: bool, photo: Image) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(WORKS_DIR)
	var id := next_work_id
	next_work_id += 1
	var name: String
	if result.get("mode", "free") == "template":
		name = str(result.get("template", "照样剪"))
	else:
		name = "%s · %s" % [PAPERS[result["paper"]]["name"], FOLDS[result["fold"]]["name"]]
	var w := {
		"id": id,
		"time": int(Time.get_unix_time_from_system()),
		"price": price,
		"buyer": buyer,
		"hidden": hidden,
		"stars": int(result.get("stars", 1)),
		"mode": result.get("mode", "free"),
		"paper": result.get("paper", "red"),
		"fold": result.get("fold", "eight"),
		"name": name,
		"accuracy": float(result.get("accuracy", -1.0)),
		"holes": int(result.get("holes", 0)),
		"cut_ratio": float(result.get("cut_ratio", 0.0)),
		"fineness": float(result.get("fineness", 0.0)),
		"cuts": int(model.cut_count) if model else 0,
		"has_mask": false,
		"has_photo": false,
	}
	if model:
		# 遮罩存档最长边 2048
		var mimg: Image = model.mask
		while maxi(mimg.get_width(), mimg.get_height()) > 2048:
			mimg = mimg.duplicate()
			mimg.resize(mimg.get_width() / 2, mimg.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		mimg.save_png("%s/%d_mask.png" % [WORKS_DIR, id])
		w["has_mask"] = true
		for t in model.tool_uses:
			if STAMPS.has(t):
				stats["stamps"][t] = int(stats["stamps"].get(t, 0)) + int(model.tool_uses[t])
	if photo:
		photo.save_jpg("%s/%d_photo.jpg" % [WORKS_DIR, id], 0.85)
		w["has_photo"] = true
	works.append(w)
	_log("sale", price, "拍卖成交 · " + name, {"work": id, "buyer": buyer})
	stats["papers"][w["paper"]] = int(stats["papers"].get(w["paper"], 0)) + 1
	stats["folds"][w["fold"]] = int(stats["folds"].get(w["fold"], 0)) + 1
	if hidden:
		stats["hidden"] = int(stats["hidden"]) + 1
	_prune_files()
	save_game()
	return w


# 旧存档补建收支明细
func _backfill_ledger() -> void:
	ledger = []
	var sum := 0
	var first_t := int(Time.get_unix_time_from_system())
	for w in works:
		ledger.append({"t": int(w["time"]), "amount": int(w["price"]), "kind": "sale",
				"title": "拍卖成交 · " + str(w["name"]), "work": int(w["id"]), "buyer": str(w.get("buyer", ""))})
		sum += int(w["price"])
		first_t = mini(first_t, int(w["time"]))
	var diff := coins - sum
	if diff != 0:
		ledger.push_front({"t": first_t - 60, "amount": diff, "kind": "init", "title": "更早的收支（未留明细）"})


func work_by_id(id: int) -> Dictionary:
	for w in works:
		if int(w["id"]) == id:
			return w
	return {}


func add_cuts(n := 1) -> void:
	stats["cuts"] = int(stats["cuts"]) + n


# 卖价前十
func top_works(n := 10) -> Array:
	var list := works.duplicate()
	list.sort_custom(func(a, b): return a["price"] > b["price"] if a["price"] != b["price"] else a["id"] < b["id"])
	return list.slice(0, n)


func work_mask(w: Dictionary) -> Image:
	if not w.get("has_mask", false):
		return null
	var path := "%s/%d_mask.png" % [WORKS_DIR, w["id"]]
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)


func work_photo(w: Dictionary) -> Texture2D:
	if not w.get("has_photo", false):
		return null
	var path := "%s/%d_photo.jpg" % [WORKS_DIR, w["id"]]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null


# 清理多余的作品文件
func _prune_files() -> void:
	var keep_ids := {}
	for w in top_works(KEEP_MASKS):
		keep_ids[w["id"]] = true
	for w in works:
		if w.get("has_mask", false) and not keep_ids.has(w["id"]):
			DirAccess.remove_absolute("%s/%d_mask.png" % [WORKS_DIR, w["id"]])
			w["has_mask"] = false
	var n := works.size()
	for i in n - KEEP_THUMBS:
		var w: Dictionary = works[i]
		if w.get("has_photo", false):
			DirAccess.remove_absolute("%s/%d_photo.jpg" % [WORKS_DIR, w["id"]])
			w["has_photo"] = false


func reset_save() -> void:
	coins = 0
	owned = {}
	selected_paper = "red"
	selected_fold = "eight"
	total_sold = 0
	best_price = 0
	first_launch_done = false
	player_level = ""
	tutorial_done = false
	for w in works:
		DirAccess.remove_absolute("%s/%d_mask.png" % [WORKS_DIR, w["id"]])
		DirAccess.remove_absolute("%s/%d_photo.jpg" % [WORKS_DIR, w["id"]])
	works = []
	ledger = []
	next_work_id = 1
	stats = {"cuts": 0, "hidden": 0, "papers": {}, "folds": {}, "stamps": {}}
	save_game()


func save_game() -> void:
	var data := {
		"coins": coins,
		"owned": owned.keys(),
		"selected_paper": selected_paper,
		"selected_fold": selected_fold,
		"total_sold": total_sold,
		"best_price": best_price,
		"first_launch_done": first_launch_done,
		"player_level": player_level,
		"tutorial_done": tutorial_done,
		"sound_on": sound_on,
		"skip_splash": skip_splash,
		"works": works,
		"ledger": ledger,
		"next_work_id": next_work_id,
		"stats": stats,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", 0))
	for id in data.get("owned", []):
		owned[str(id)] = true
	selected_paper = str(data.get("selected_paper", "red"))
	selected_fold = str(data.get("selected_fold", "eight"))
	if not PAPERS.has(selected_paper) or not is_owned(selected_paper):
		selected_paper = "red"
	if not FOLDS.has(selected_fold) or not is_owned(selected_fold):
		selected_fold = "eight"
	total_sold = int(data.get("total_sold", 0))
	best_price = int(data.get("best_price", 0))
	first_launch_done = bool(data.get("first_launch_done", false))
	player_level = str(data.get("player_level", ""))
	tutorial_done = bool(data.get("tutorial_done", false))
	sound_on = bool(data.get("sound_on", true))
	skip_splash = bool(data.get("skip_splash", false))
	works = []
	for w in data.get("works", []):
		if typeof(w) == TYPE_DICTIONARY:
			for k in ["id", "time", "price", "stars", "holes", "cuts"]:
				w[k] = int(w.get(k, 0))
			works.append(w)
	next_work_id = int(data.get("next_work_id", works.size() + 1))
	ledger = []
	if data.has("ledger"):
		for e in data.get("ledger", []):
			if typeof(e) == TYPE_DICTIONARY:
				e["t"] = int(e.get("t", 0))
				e["amount"] = int(e.get("amount", 0))
				if e.has("work"):
					e["work"] = int(e["work"])
				ledger.append(e)
	else:
		_backfill_ledger()
	var st = data.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in ["papers", "folds", "stamps"]:
			if typeof(st.get(k)) != TYPE_DICTIONARY:
				st[k] = {}
		st["cuts"] = int(st.get("cuts", 0))
		st["hidden"] = int(st.get("hidden", 0))
		stats = st
