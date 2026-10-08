# What the shop between the 3D preview's rounds sells (docs/shop-plan.md),
# and what it costs a player: one list, which the shop's matrix is laid out
# from, the run (Level3DRun.Kit) is bought into, and the checks read.
#
# The list is a table, assets/shop/items.json, read the first time it is
# asked for (items); what the goods do is code, under their ids. A row:
#
#   id          what the run (Kit.upgrades), --upgrades and the code know it
#               by; a device's is its action in Level3DSettings.DEVICES too
#   name        on its tile; title, where there is one, in full in the words
#   text        the shop's words for it
#   kind        upgrade, device, step, supply or classified (Kind)
#   row, col    its cell in the matrix; a supply's row is all of it
#   price       an upgrade's and a device's; a supply's first, each after it
#               price_step dearer
#   steps       a step's prices, one for each
#   press       a device's line under its words, what to press for it: {key}
#               is the key or the pad's button the player is on, and the
#               table's unbound stands in for it all when there is none
#   note        for whoever edits the table; nothing reads it
#
# A row that is wrong is left out and said in the errors; check says what is
# wrong with the whole table, and tools/verify_shop.gd runs it.
#
# Everything is on sale from the first round; what keeps the strong things
# for later is their price -- a cleared round is worth about 35 000. In the
# preview's font (Level3DFont), which has capitals and no Cyrillic: the
# names and the lines under them are English, and check holds them to it.
#
# Five kinds:
#   UPGRADE  bought once and kept for the run; most show on the jeep
#            (Level3DBtr.UPGRADE_PARTS)
#   DEVICE   an upgrade that goes off on a key of its own
#            (Level3DSettings.DEVICES)
#   STEP     the launcher's next step, as a prisoner's (Carrier.upgrade_weapon):
#            bought again until the missile's last, each dearer
#   SUPPLY   a life: bought again and again, each dearer than the last
#   CLASSIFIED  not for sale yet: a tile under a CLASSIFIED stamp, for what
#            the player is to unlock later, nothing behind it for now
class_name Level3DShopCatalog
extends RefCounted

enum Kind { UPGRADE, DEVICE, STEP, SUPPLY, CLASSIFIED }

const PATH := "res://assets/shop/items.json"
const KINDS := {"upgrade": Kind.UPGRADE, "device": Kind.DEVICE, "step": Kind.STEP,
		"supply": Kind.SUPPLY, "classified": Kind.CLASSIFIED}
const FIELDS := ["id", "name", "title", "text", "kind", "row", "col", "price", "price_step",
		"steps", "press", "note"]
# What each kind has of the fields only some have.
const NEEDS := {"upgrade": ["price"], "device": ["price", "press"], "step": ["steps"],
		"supply": ["price", "price_step"], "classified": []}
const KEY := "{key}"
const MOST := 1 << 30

# The matrix: rows 0-4 of three, weapons, protection, devices, then the
# Arena and two tiles still classified, and a row of three more; row 5 the
# life, across all three columns.
const ROWS := 6
const COLUMNS := 3
const MAX_LIVES := 9
const LAUNCHER_TOP := 3          # Level3DRun.Kit.weapon(): the missile's last step

# What an item is to a player, for its tile.
enum State { BUY, POOR, OWNED, FULL, LOCKED }

# The table's rows as read: a Dictionary each, of its fields but the note,
# kind a Kind, the numbers ints, title and press only where it has them.
static var _items: Array[Dictionary] = []
static var _unbound := ""
static var _read := false


static func items() -> Array[Dictionary]:
	if not _read:
		_read = true
		var doc := read()
		for problem in check(doc):
			push_error("%s: %s" % [PATH, problem])
		if typeof(doc.get("unbound")) == TYPE_STRING:
			_unbound = doc.unbound
		var ids := {}
		for row in doc.get("items", []):
			if _row_problems(row, ids).is_empty():
				_items.append(_typed(row))
				ids[row.id] = true
	return _items


static func read() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s is not a JSON object" % PATH)
		return {}
	return parsed


# What is wrong with the table `doc`, empty when nothing.
static func check(doc: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for key in doc:
		if not key in ["unbound", "items"]:
			problems.append("unknown field %s" % key)
	if typeof(doc.get("unbound")) != TYPE_STRING or not _in_font(doc.unbound):
		problems.append("unbound is not a line in the font")
	if typeof(doc.get("items")) != TYPE_ARRAY:
		problems.append("items is not a list")
		return problems
	var ids := {}
	var cells := {}
	for row in doc.items:
		var id := str(row.get("id", "?")) if row is Dictionary else "?"
		var wrong := _row_problems(row, ids)
		for problem in wrong:
			problems.append("%s: %s" % [id, problem])
		if not wrong.is_empty():
			continue
		ids[id] = true
		var cols: Array = range(COLUMNS) if row.kind == "supply" else [int(row.col)]
		for col in cols:
			var cell := Vector2i(col, int(row.row))
			if cells.has(cell):
				problems.append("%s: its cell is %s's" % [id, cells[cell]])
			cells[cell] = id
	for device in Level3DSettings.DEVICES:
		if not ids.has(device):
			problems.append("no row for the device %s" % device)
	return problems


# What is wrong with one row, `ids` the good ones before it.
static func _row_problems(row: Variant, ids: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if not row is Dictionary:
		problems.append("not an object")
		return problems
	for key in row:
		if not key in FIELDS:
			problems.append("unknown field %s" % key)
	var id: Variant = row.get("id")
	if typeof(id) != TYPE_STRING or id == "":
		problems.append("no id")
	elif ids.has(id):
		problems.append("a second row with this id")
	for key in ["name", "text", "title"]:
		if (key != "title" or row.has(key)) \
				and (typeof(row.get(key)) != TYPE_STRING or not _in_font(row[key])):
			problems.append("%s is not a line in the font" % key)
	var kind: Variant = row.get("kind")
	if not KINDS.has(kind):
		problems.append("kind is none of %s" % ", ".join(KINDS.keys()))
		return problems
	if not _whole_in(row.get("row"), 0, ROWS - 1):
		problems.append("row is not 0 to %d" % (ROWS - 1))
	if not _whole_in(row.get("col"), 0, COLUMNS - 1):
		problems.append("col is not 0 to %d" % (COLUMNS - 1))
	for key in ["price", "price_step", "steps", "press"]:
		if row.has(key) != (key in NEEDS[kind]):
			problems.append(("kind %s has no %s" if row.has(key) else "kind %s needs %s") % [kind, key])
	if row.has("price") and not _whole_in(row.price, 1, MOST):
		problems.append("price is not a whole number over 0")
	if row.has("price_step") and not _whole_in(row.price_step, 0, MOST):
		problems.append("price_step is not a whole number")
	if row.has("steps") and (typeof(row.steps) != TYPE_ARRAY or row.steps.size() != LAUNCHER_TOP
			or row.steps.any(func(v): return not _whole_in(v, 1, MOST))):
		problems.append("steps are not %d whole numbers over 0" % LAUNCHER_TOP)
	if row.has("press") and (typeof(row.press) != TYPE_STRING or not row.press.contains(KEY)
			or not _in_font(row.press.replace(KEY, ""))):
		problems.append("press is not a line in the font with %s in it" % KEY)
	if kind == "device" and typeof(id) == TYPE_STRING and not Level3DSettings.DEVICES.has(id):
		problems.append("a device with no action in Level3DSettings.DEVICES")
	return problems


static func _typed(row: Dictionary) -> Dictionary:
	var it := {"id": row.id, "name": row.name, "text": row.text, "kind": KINDS[row.kind],
			"row": int(row.row), "col": int(row.col)}
	for key in ["title", "press"]:
		if row.has(key):
			it[key] = row[key]
	for key in ["price", "price_step"]:
		if row.has(key):
			it[key] = int(row[key])
	if row.has("steps"):
		var steps: Array[int] = []
		for v in row.steps:
			steps.append(int(v))
		it.steps = steps
	return it


static func _whole_in(v: Variant, lo: int, hi: int) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and v == floorf(v) and v >= lo and v <= hi


static func _in_font(text: String) -> bool:
	for c in text:
		if not Level3DFont.CHARS.contains(c):
			return false
	return true


static func item(id: String) -> Dictionary:
	for i in items():
		if i.id == id:
			return i
	return {}


# The item at a cell of the matrix, the life's row whatever the column.
static func at(row: int, col: int) -> Dictionary:
	for i in items():
		if i.row == row and (i.col == col or i.kind == Kind.SUPPLY):
			return i
	return {}


# A device's line under its words, `key` what the player presses for it, ""
# when nothing: the table's unbound then.
static func press(id: String, key: String) -> String:
	var line: String = item(id).get("press", "")
	return _unbound if key == "" else line.replace(KEY, key)


# What `id` costs `kit` now: the next step's, the next life's; -1 when there
# is nothing more of it to buy.
static func price(id: String, kit: Level3DRun.Kit) -> int:
	var i := item(id)
	match i.get("kind", -1):
		Kind.STEP:
			var step := kit.weapon()
			return -1 if step >= LAUNCHER_TOP else int(i.steps[step])
		Kind.SUPPLY:
			return -1 if kit.lives >= MAX_LIVES else int(i.price) + int(i.price_step) * kit.lives_bought
		Kind.UPGRADE, Kind.DEVICE:
			return -1 if kit.upgrades.has(id) else int(i.price)
	return -1


static func state(id: String, kit: Level3DRun.Kit) -> State:
	var i := item(id)
	if i.kind == Kind.CLASSIFIED:
		return State.LOCKED
	var p := price(id, kit)
	if p < 0:
		return State.OWNED if i.kind == Kind.UPGRADE or i.kind == Kind.DEVICE else State.FULL
	return State.BUY if kit.score >= p else State.POOR


# `id` bought into `kit`, its price off the score; whether it was.
static func buy(id: String, kit: Level3DRun.Kit) -> bool:
	var p := price(id, kit)
	if p < 0 or kit.score < p:
		return false
	kit.score -= p
	match item(id).kind:
		Kind.STEP:
			kit.set_weapon(kit.weapon() + 1)
		Kind.SUPPLY:
			kit.lives += 1
			kit.lives_bought += 1
		Kind.DEVICE, Kind.UPGRADE:
			kit.upgrades.append(id)
	return true


# A purchase taken back: `id`'s last, its price back on the score. Only what
# was bought in this visit may be (the shop keeps that list).
static func refund(id: String, kit: Level3DRun.Kit) -> void:
	var i := item(id)
	match i.kind:
		Kind.STEP:
			kit.set_weapon(kit.weapon() - 1)
			kit.score += int(i.steps[kit.weapon()])
		Kind.SUPPLY:
			kit.lives -= 1
			kit.lives_bought -= 1
			kit.score += int(i.price) + int(i.price_step) * kit.lives_bought
		_:
			kit.upgrades.erase(id)
			kit.score += int(i.price)
