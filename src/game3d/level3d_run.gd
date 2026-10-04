# The 3D preview's run between rounds (docs/shop-plan.md): which round of the
# stage it is, and for each player what a round leaves him for the next --
# his score, which is what the shop takes, his lives, the launcher's step,
# what the shop sold him. What lives only inside a round -- the prisoners
# aboard, the stage's enemies, where the jeep is -- is not here.
#
# Nothing in the game has one: the game's PlayerState lasts the game and its
# continue starts the stage again from nothing. The preview keeps the run as
# the last shop left it (level3d_preview.gd, _saved), and its CONTINUE goes
# back to that rather than to nothing.
#
# level3d_preview.gd's Crew holds the live values; _capture and _restore copy
# them out and back.
class_name Level3DRun
extends RefCounted

# One player's share of it.
class Kit:
	var score := 0
	var lives := 0
	# Lives bought so far in the run, which prices the next (Level3DShopCatalog).
	var lives_bought := 0
	# The launcher: Level3DFriends.Carrier's, Main's has_missiles and
	# missile_power.
	var has_missiles := false
	var missile_power := 0
	# Level3DShopCatalog ids, and the device in the slot ("" none).
	var upgrades: Array[String] = []
	var device := ""

	func copy() -> Kit:
		var k := Kit.new()
		k.score = score
		k.lives = lives
		k.lives_bought = lives_bought
		k.has_missiles = has_missiles
		k.missile_power = missile_power
		k.upgrades = upgrades.duplicate()
		k.device = device
		return k

	# The launcher's step: 0 the grenade, 1 to 3 the missile and its two
	# upgrades -- --weapon's numbers.
	func weapon() -> int:
		return 1 + missile_power if has_missiles else 0

	func set_weapon(step: int) -> void:
		has_missiles = step > 0
		missile_power = clampi(step - 1, 0, 2)


var round := 1
var kits: Array[Kit] = []


func copy() -> Level3DRun:
	var run := Level3DRun.new()
	run.round = round
	for k in kits:
		run.kits.append(k.copy())
	return run
