# What the shop between the 3D preview's rounds sells (docs/shop-plan.md),
# and what it costs a player: one list, which the shop's matrix is laid out
# from, the run (Level3DRun.Kit) is bought into, and the checks read.
#
# Everything is on sale from the first round; what keeps the strong things
# for later is their price -- a cleared round is worth about 35 000. In the
# preview's font (Level3DFont), which has capitals and no Cyrillic: the
# names and the lines under them are English.
#
# Four kinds:
#   UPGRADE  bought once and kept for the run; most show on the jeep
#            (Level3DBtr.UPGRADE_PARTS)
#   DEVICE   an upgrade that goes off on the device key, one in the slot
#   STEP     the launcher's next step, as a prisoner's (Carrier.upgrade_weapon):
#            bought again until the missile's last, each dearer
#   SUPPLY   a life: bought again and again, each 5 000 dearer than the last
#   CLASSIFIED  not for sale yet: a tile under a CLASSIFIED stamp, for what
#            the player is to unlock later, nothing behind it for now
class_name Level3DShopCatalog
extends RefCounted

enum Kind { UPGRADE, DEVICE, STEP, SUPPLY, CLASSIFIED }

# The matrix: rows 0-4 of three, weapons, protection, devices, then the
# Arena and two tiles still classified, and a row of three more; row 5 the
# life, across all three columns.
const ITEMS := [
	{"id": "twin", "name": "TWIN GUN", "row": 0, "col": 0, "kind": Kind.UPGRADE, "price": 20000,
		"text": "TWO BARRELS IN TURN: TWICE THE RATE, THE SAME REACH."},
	{"id": "launcher", "name": "LAUNCHER", "row": 0, "col": 1, "kind": Kind.STEP,
		"steps": [10000, 15000, 20000],
		"text": "THE NEXT STEP OF THE LAUNCHER, AS A PRISONER GIVES IT, FROM THE NEXT ROUND ON."},
	# The radar where the loopholes were, which are off the shelves for now
	# (docs/shop-plan.md); their code is still there, and --upgrades gives them.
	{"id": "radar", "name": "RADAR", "row": 0, "col": 2, "kind": Kind.UPGRADE, "price": 8000,
		"text": "MARKS THE GUNS AND TANKS OFF THE SCREEN AT ITS EDGE."},
	{"id": "zip", "name": "SPARES", "row": 1, "col": 0, "kind": Kind.UPGRADE, "price": 15000,
		"text": "DIE AND THE LAUNCHER LOSES ONE STEP, NOT ALL OF THEM."},
	{"id": "armor", "name": "ARMOR", "row": 1, "col": 1, "kind": Kind.UPGRADE, "price": 25000,
		"text": "DIE AND EVERY PRISONER ABOARD JUMPS OUT ALIVE."},
	# Lost to the first ram it saves the jeep from (level3d_preview.gd,
	# _shed_cage), and then for sale again.
	{"id": "hull", "name": "RAM CAGE", "row": 1, "col": 2, "kind": Kind.UPGRADE, "price": 10000,
		"text": "RAM A GUN OR A TANK AND LIVE. THE CAGE IS LOST: BUY ANOTHER."},
	{"id": "nitro", "name": "NITRO", "row": 2, "col": 0, "kind": Kind.DEVICE, "price": 10000,
		"text": "A DASH AHEAD, THROUGH THE LINE OF FIRE. RELOADS."},
	{"id": "mines", "name": "MINES", "row": 2, "col": 1, "kind": Kind.DEVICE, "price": 15000,
		"text": "A MINE DROPPED BEHIND, FOR THE TANK ON YOUR TAIL."},
	{"id": "airstrike", "name": "AIRSTRIKE", "row": 2, "col": 2, "kind": Kind.DEVICE, "price": 30000,
		"text": "WIPES OUT THE ENEMIES ON THE SCREEN FOR 2000, 4000, 8000 A CALL. NOT THE BOSS."},
	# Only of use where enemy missiles fly (docs/shop-plan.md): none on
	# stage-0 as yet.
	{"id": "arena", "name": "ARENA", "row": 3, "col": 0, "kind": Kind.UPGRADE, "price": 20000,
		"text": "SHOOTS DOWN A MISSILE ABOUT TO HIT YOU. ONE EVERY 10 SECONDS."},
	{"id": "classified1", "name": "???", "row": 3, "col": 1, "kind": Kind.CLASSIFIED,
		"text": "CLASSIFIED. NOT FOR SALE - YET."},
	{"id": "classified2", "name": "???", "row": 3, "col": 2, "kind": Kind.CLASSIFIED,
		"text": "CLASSIFIED. NOT FOR SALE - YET."},
	{"id": "classified3", "name": "???", "row": 4, "col": 0, "kind": Kind.CLASSIFIED,
		"text": "CLASSIFIED. NOT FOR SALE - YET."},
	{"id": "classified4", "name": "???", "row": 4, "col": 1, "kind": Kind.CLASSIFIED,
		"text": "CLASSIFIED. NOT FOR SALE - YET."},
	{"id": "classified5", "name": "???", "row": 4, "col": 2, "kind": Kind.CLASSIFIED,
		"text": "CLASSIFIED. NOT FOR SALE - YET."},
	{"id": "life", "name": "LIFE", "row": 5, "col": 0, "kind": Kind.SUPPLY,
		"text": "ONE MORE LIFE. EACH ONE COSTS 5000 MORE THAN THE LAST."},
]
const ROWS := 6
const COLUMNS := 3
const LIFE_PRICE := 15000
const LIFE_STEP := 5000
const MAX_LIVES := 9
const LAUNCHER_TOP := 3          # Level3DRun.Kit.weapon(): the missile's last step

# What an item is to a player, for its tile.
enum State { BUY, POOR, OWNED, FULL, LOCKED }


static func item(id: String) -> Dictionary:
	for i in ITEMS:
		if i.id == id:
			return i
	return {}


# The item at a cell of the matrix, the life's row whatever the column.
static func at(row: int, col: int) -> Dictionary:
	for i in ITEMS:
		if i.row == row and (i.col == col or i.kind == Kind.SUPPLY):
			return i
	return {}


# What `id` costs `kit` now: the next step's, the next life's; -1 when there
# is nothing more of it to buy.
static func price(id: String, kit: Level3DRun.Kit) -> int:
	var i := item(id)
	match i.get("kind", -1):
		Kind.STEP:
			var step := kit.weapon()
			return -1 if step >= LAUNCHER_TOP else int(i.steps[step])
		Kind.SUPPLY:
			return -1 if kit.lives >= MAX_LIVES else LIFE_PRICE + LIFE_STEP * kit.lives_bought
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


# `id` bought into `kit`, its price off the score; whether it was. A device
# bought with the slot empty goes in it.
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
		Kind.DEVICE:
			kit.upgrades.append(id)
			if kit.device == "":
				kit.device = id
		Kind.UPGRADE:
			kit.upgrades.append(id)
	return true


# A purchase taken back: `id`'s last, its price back on the score. Only what
# was bought in this visit may be (the shop keeps that list).
static func refund(id: String, kit: Level3DRun.Kit) -> void:
	match item(id).kind:
		Kind.STEP:
			kit.set_weapon(kit.weapon() - 1)
			kit.score += int(item(id).steps[kit.weapon()])
		Kind.SUPPLY:
			kit.lives -= 1
			kit.lives_bought -= 1
			kit.score += LIFE_PRICE + LIFE_STEP * kit.lives_bought
		_:
			kit.upgrades.erase(id)
			kit.score += int(item(id).price)
			if kit.device == id:
				kit.device = ""
				for other in kit.upgrades:
					if item(other).get("kind", -1) == Kind.DEVICE:
						kit.device = other
						break


# The devices `kit` has, in the matrix's order: the slot's choices.
static func devices(kit: Level3DRun.Kit) -> Array[String]:
	var out: Array[String] = []
	for i in ITEMS:
		if i.kind == Kind.DEVICE and kit.upgrades.has(i.id):
			out.append(i.id)
	return out
