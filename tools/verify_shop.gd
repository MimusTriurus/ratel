# Checks the 3D preview's shop between rounds (docs/shop-plan.md,
# docs/shop-implementation.md) on the preview itself, a fresh one for each
# part: the rounds and the run kept between them, the shop, the passive
# upgrades and the devices. No window needed:
#
#     godot --path . --headless --script tools/verify_shop.gd
#
# Each part drives the preview as a player would not have the patience to --
# scores set, keys held through _held (--hold's list), the shop's cursor put
# on a tile -- and checks what comes of it. A failure prints FAIL; the exit
# code is the count of them. A few minutes, most of it the stage built four
# times over.
extends SceneTree

var scene: Node
var failures := 0


func _init() -> void:
	_all()


func check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


func _fresh() -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
		await process_frame
	paused = false
	scene = load("res://src/game3d/level3d_preview.tscn").instantiate()
	root.add_child(scene)


func _all() -> void:
	print("-- Rounds: the run kept between them, the summary to the shop to round 2, CONTINUE, R.")
	await _fresh()
	await _rounds()
	print("-- The shop: buying, taking back, both players at once, READY.")
	await _fresh()
	await _shop()
	print("-- The passive upgrades: spares, armour, twin gun, loopholes, radar, the ram cage.")
	await _fresh()
	await _passives()
	print("-- The devices: the key, nitro, mines, the airstrike, not at the boss.")
	await _fresh()
	await _devices()
	print("failures: %d" % failures)
	quit(failures)


# Rounds: the run kept between them, the summary to the shop to round 2, CONTINUE, R.
func _rounds() -> void:
	while not scene.get("_live"):
		await process_frame
	scene.call("_start_game", 2)
	for i in 30:
		await process_frame
	var crews: Array = scene.get("crews")
	var a = crews[0]
	var b = crews[1]
	check("new game: 4 lives, no score, grenade", a.lives == 4 and a.score == 0 and not a.carrier.has_missiles)
	check("round 1, normal", scene.get("_round") == 1 and not Level3DMap.hard)

	# Snapshot and back.
	var saved: Level3DRun = scene.call("_capture")
	a.score = 1234; a.lives = 9; a.carrier.has_missiles = true; a.carrier.missile_power = 2
	a.upgrades.append("zip"); b.score = 77; b.device = "nitro"
	scene.call("_restore", saved)
	check("restore: first player as captured", a.score == 0 and a.lives == 4 and not a.carrier.has_missiles
			and a.upgrades.is_empty())
	check("restore: second player as captured", b.score == 0 and b.device == "")

	# Points earn no lives.
	scene.call("_add_points", a, 25000)
	check("25000 points, still 4 lives", a.lives == 4 and a.score == 25000)

	# The boss beaten: the summary closed goes on to round 2.
	a.carrier.has_missiles = true
	a.carrier.missile_power = 1
	a.lives = 2
	var summary: Level3DSummary = scene.get("_summary")
	var by: Array[int] = [0, 1]
	summary.show_summary(by, 5, 1000)
	summary.dismiss()
	summary.dismiss()
	for i in 60:
		await process_frame
	var shop: Level3DShop = scene.get("_shop")
	check("the shop after the summary", shop.is_open())
	for i in 60:
		await process_frame
	for p in 2:
		shop._cursor[p] = Vector2i(0, Level3DShop.READY_ROW)
		shop._fire(p)
	for i in 200:
		await process_frame
	check("round 2 after the shop", scene.get("_round") == 2)
	check("round 2 plays the hard list", Level3DMap.hard)
	check("round 2 keeps score, lives, launcher", a.score == 25000 and a.lives == 2
			and a.carrier.has_missiles and a.carrier.missile_power == 1)

	# Spend it, die out, CONTINUE: back to the round's start.
	a.score = 5; a.lives = 0; a.carrier.has_missiles = false
	scene.call("_continue_game")
	for i in 10:
		await process_frame
	check("continue: round 2 as it started", scene.get("_round") == 2 and a.score == 25000 and a.lives == 2
			and a.carrier.has_missiles and a.carrier.missile_power == 1)

	# R: the run from nothing.
	scene.call("_restart")
	check("R: round 1, fresh", scene.get("_round") == 1 and a.score == 0 and a.lives == 4
			and not a.carrier.has_missiles and not Level3DMap.hard)


# The shop: buying, taking back, both players at once, READY.
func _shop() -> void:
	while not scene.get("_live"):
		await process_frame
	scene.call("_start_game", 2)
	for i in 30:
		await process_frame
	var crews: Array = scene.get("crews")
	crews[0].score = 40000
	crews[1].score = 9000
	scene.call("_open_shop", true)
	var shop: Level3DShop = scene.get("_shop")
	for i in 20:
		await process_frame
	check("shop open, tree paused", shop.is_open() and paused)
	var kit: Level3DRun.Kit = shop._run.kits[0]
	_at(shop, 0, "life"); shop._fire(0)
	_at(shop, 0, "launcher"); shop._fire(0); shop._fire(0)
	check("40000 - 15000 - 10000 - 15000 = 0", kit.score == 0)
	check("a life more, missile+", kit.lives == 5 and kit.weapon() == 2)
	shop._fire(0)
	check("nothing more for nothing", kit.score == 0 and kit.weapon() == 2)
	shop._take_back(0)
	check("the last step taken back: 15000, missile", kit.score == 15000 and kit.weapon() == 1)
	_at(shop, 0, "life"); shop._take_back(0)
	check("the life taken back: 30000, 4 lives", kit.score == 30000 and kit.lives == 4 and kit.lives_bought == 0)
	_at(shop, 0, "twin"); shop._fire(0)
	check("twin gun bought", kit.upgrades.has("twin") and kit.score == 10000)
	shop._fire(0)
	check("bought once", kit.score == 10000)
	_at(shop, 0, "nitro"); shop._fire(0)
	check("nitro bought goes in the slot", kit.device == "nitro" and kit.score == 0)
	# The second player's own money.
	var kit2: Level3DRun.Kit = shop._run.kits[1]
	_at(shop, 1, "radar"); shop._fire(1)
	check("2P: radar from his 9000", kit2.score == 1000 and kit2.upgrades.has("radar") and kit.score == 0)
	_at(shop, 1, "twin"); shop._fire(1)
	check("2P: short of the twin gun", not kit2.upgrades.has("twin"))
	# Ready, both.
	shop._cursor[0] = Vector2i(0, Level3DShop.READY_ROW)
	shop._cursor[1] = Vector2i(0, Level3DShop.READY_ROW)
	shop._fire(0)
	check("one ready is not enough", shop.is_open() and shop._state == Level3DShop.State.OPEN)
	shop._fire(1)
	# The jeeps' start and drive off, the black down and up again.
	await create_timer(Level3DShop.DRIVE_TIME + Level3DShop.LEAVE * 2.0 + 0.5).timeout
	check("both ready: the shop gone, round 2", not shop.is_open() and scene.get("_round") == 2 and not paused)
	var a = crews[0]
	check("1P carries what he bought", a.score == 0 and a.upgrades.has("twin") and a.device == "nitro"
			and a.carrier.has_missiles and a.carrier.missile_power == 0)
	check("1P's jeep has the twin gun", a.btr.has_twin())
	check("2P carries the radar", crews[1].upgrades.has("radar") and crews[1].score == 1000)
	var saved: Level3DRun = scene.get("_saved")
	check("what CONTINUE goes back to is the round's start", saved.round == 2 and saved.kits[0].upgrades.has("twin"))


# The passive upgrades: spares, armour, twin gun, loopholes, radar, the ram cage.
func _passives() -> void:
	while not scene.get("_live"):
		await process_frame
	scene.call("_start_game", 1)
	var settings: Level3DSettings = scene.get("settings")
	settings.bullet_hack = true
	settings.infinite_lives = true
	for i in 30:
		await process_frame
	var chinook = scene.get("chinook")
	if chinook != null:
		chinook.skip()
	for i in 30:
		await physics_frame
	var none: Array[String] = []
	var zip: Array[String] = ["zip"]
	var armor: Array[String] = ["armor"]
	check("no spares: missile++ to the grenade", _died(none, 3, 0)[0] == 0)
	check("spares: missile++ to missile+", _died(zip, 3, 0)[0] == 2)
	check("spares: missile to the grenade", _died(zip, 1, 0)[0] == 0)
	check("spares: the grenade stays", _died(zip, 0, 0)[0] == 0)
	var out: Array = _died(none, 0, 7)
	check("no armour: 7 aboard, 4 out (%d)" % out[1], out[1] == 4)
	out = _died(armor, 0, 7)
	check("armour: 7 aboard, 7 out (%d)" % out[1], out[1] == 7)
	out = _died(armor, 0, 1)
	check("armour: 1 aboard, 1 out (%d)" % out[1], out[1] == 1)

	# The twin gun: twice the rate, from each barrel in turn.
	var c = scene.get("crews")[0]
	c.upgrades.assign(["twin"])
	scene.call("_dress_crews")
	check("twin: the gun's rate doubled", c.gun.rate == 2.0 * settings.gun_rate and c.btr.has_twin())
	var muzzles := {}
	for i in 4:
		c.btr.cycle_muzzle()
		muzzles[c.btr.muzzle_node().position] = true
	check("twin: two muzzles in turn", muzzles.size() == 2)
	var single := await _shots(none)
	var twin := await _shots(["twin"])
	check("twin: %d shots to the single gun's %d" % [twin, single], twin >= single * 1.8 and single > 0)

	# The loopholes: prisoners aboard shoot what comes near, the trigger idle.
	c.upgrades.assign(["loopholes"])
	scene.call("_dress_crews")
	c.carrier.pows = 5
	c.carrier.releaseable_pows = 5
	var score: int = c.score
	for i in 1200:
		await physics_frame
	check("loopholes: points without firing (%d)" % (c.score - score), c.score > score)

	# The radar: marks the guns off the frame.
	c.upgrades.assign(["radar"])
	scene.call("_dress_crews")
	for i in 5:
		await process_frame
	var radar: Level3DRadar = scene.get("_radar")
	check("radar shown with %d targets" % radar.targets.size(), radar.shown and not radar.targets.is_empty())
	c.upgrades.clear()
	for i in 5:
		await process_frame
	check("no radar, none shown", not radar.shown)

	# The ram cage: a gun run into is gone and the jeep lives, once; the
	# next ram, without it, blows the jeep up.
	var guns: Level3DGuns = scene.get("guns")
	c.upgrades.assign(["hull"])
	scene.call("_dress_crews")
	var standing := guns.targets()
	if standing.is_empty():
		check("ram cage: a gun to run into", false)
		return
	c.btr.place(Vector3(standing[0].x, c.btr.position.y, standing[0].y), c.btr.heading)
	c.invincible = 0
	await physics_frame
	await physics_frame
	# That one gone: another may have come out meanwhile.
	check("ram cage: the gun run into gone", not guns.targets().has(standing[0]))
	check("ram cage: the jeep lives", c.respawning == 0 and c.btr.visible)
	check("ram cage: lost, a second's blinking", not c.upgrades.has("hull") and c.invincible > 0)
	# On up the stage, out of the bunkers' way, till the next one is out.
	var at: Vector3 = c.btr.position
	while guns.targets().is_empty() and at.z > -20.0:
		at.z -= 3.0
		c.btr.place(Vector3(-5.0, at.y, at.z), c.btr.heading)
		for i in 60:
			await physics_frame
	if guns.targets().is_empty():
		check("ram cage: a second gun to run into", false)
		return
	var next: Vector2 = guns.targets()[0]
	c.btr.place(Vector3(next.x, c.btr.position.y, next.y), c.btr.heading)
	c.invincible = 0
	await physics_frame
	await physics_frame
	check("ram cage: without it, the next ram kills", c.respawning > 0)


# The devices: the key, nitro, mines, the airstrike, not at the boss.
func _devices() -> void:
	while not scene.get("_live"):
		await process_frame
	scene.call("_start_game", 1)
	var settings: Level3DSettings = scene.get("settings")
	settings.bullet_hack = true
	settings.infinite_lives = true
	for i in 30:
		await process_frame
	if scene.get("chinook") != null:
		scene.get("chinook").skip()
	for i in 60:
		await physics_frame
	var c = scene.get("crews")[0]
	check("the device key is in the settings", Level3DSettings.ACTIONS.has("device")
			and settings.key("device") == KEY_K)

	# No device: the key does nothing.
	await _press(c)
	check("no device, nothing", c.device_wait == 0 and c.btr.dash == 0)

	# Nitro: a dash, then the reload.
	_give(c, "nitro")
	var from: Vector3 = c.btr.position
	await _press(c)
	check("nitro: dashing", c.btr.dash > 0 and c.device_wait > 0)
	for i in 70:
		await physics_frame
	var dashed: float = c.btr.position.distance_to(from)
	check("nitro: moved %.2f m with no key held" % dashed, dashed > 1.0)
	var wait: int = c.device_wait
	await _press(c)
	check("nitro: not again while it reloads", c.btr.dash == 0 and c.device_wait < wait)

	# Mines: down behind, MAX_MINES at most.
	_give(c, "mines")
	for k in 4:
		c.device_wait = 0
		await _press(c)
	check("mines: %d down, 3 at most" % c.mines.size(), c.mines.size() == 3)
	var mine: Node3D = c.mines[0]
	check("mines: behind the jeep", mine.position.distance_to(c.btr.position) < 1.5)

	# The airstrike: 2000, then 4000, then 8000 -- short of the third.
	_give(c, "airstrike")
	c.score = 10000
	var soldiers: Level3DSoldiers = scene.get("soldiers")
	var view: Rect2 = scene.call("_view_frame")
	var in_view := 0
	for at in soldiers.targets():
		if view.has_point(at):
			in_view += 1
	await _press(c)
	check("airstrike: 2000 paid, nothing for the dead (%d)" % c.score, c.score == 8000)
	var left := 0
	for at in soldiers.targets():
		if view.has_point(at):
			left += 1
	check("airstrike: the soldiers in the frame dead (%d of %d left)" % [left, in_view], left == 0 or in_view == 0)
	c.device_wait = 0
	await _press(c)
	check("airstrike: 4000 the second", c.score == 4000)
	await _press(c)
	check("airstrike: short of 8000, not called", c.score == 4000 and c.strikes == 2)
	var hud: Level3DHud = c.hud
	check("HUD: AIR 8000, dimmed (%s)" % hud.device, hud.device == "AIR 8000" and not hud.device_ready)

	# A mine under a boss tank, and no airstrike while the boss has the camera.
	scene.call("_jump_to_boss")
	var boss: Level3DBoss = scene.get("boss")
	var now: int = scene.get("_ticks")
	(scene.get("_held") as Array).append(["up", now, now + 1500, 0])
	for i in 3000:
		await physics_frame
		if boss.camera_top() >= 0.0 and not boss.targets().is_empty():
			break
	c.score = 50000
	check("the boss came (%s)" % boss.camera_top(), boss.camera_top() >= 0.0 and not boss.targets().is_empty())
	if boss.targets().is_empty():
		failures += 1
		return
	check("airstrike: not while the boss has the camera", not scene.call("_airstrike_ready", c))
	_give(c, "mines")
	var target: Vector2 = boss.targets()[0]
	c.mines.clear()
	var m := Node3D.new()
	m.position = Vector3(target.x, 0.0, target.y)
	scene.add_child(m)
	c.mines.append(m)
	await physics_frame
	await physics_frame
	check("mines: one under a boss tank goes off", c.mines.is_empty())


# The rounds fired over three seconds of the gun's trigger held.
func _shots(upgrades: Array[String]) -> int:
	var c = scene.get("crews")[0]
	c.upgrades = upgrades
	scene.call("_dress_crews")
	for i in 100:
		await physics_frame
	var ticks: int = scene.get("_ticks")
	(scene.get("_held") as Array).append(["gun", ticks, ticks + 300, 0])
	var shots := 0
	var last: int = c.gun.get("_in_flight")
	for i in 300:
		await physics_frame
		var now: int = c.gun.get("_in_flight")
		if now > last:
			shots += now - last
		last = now
	return shots


func _at(shop: Level3DShop, player: int, id: String) -> void:
	var it := Level3DShopCatalog.item(id)
	shop._cursor[player] = Vector2i(it.col, it.row)


func _died(upgrades: Array[String], weapon: int, pows: int) -> Array:
	var friends: Level3DFriends = scene.get("friends")
	var c = scene.get("crews")[0]
	c.upgrades = upgrades
	scene.call("_dress_crews")
	var kit := Level3DRun.Kit.new()
	kit.set_weapon(weapon)
	c.carrier.has_missiles = kit.has_missiles
	c.carrier.missile_power = kit.missile_power
	c.carrier.pows = pows
	c.carrier.releaseable_pows = pows
	var before := friends.friends.size()
	friends.player_died(c.btr.position, c.carrier)
	var after := Level3DRun.Kit.new()
	after.has_missiles = c.carrier.has_missiles
	after.missile_power = c.carrier.missile_power
	return [after.weapon(), friends.friends.size() - before]


func _press(c, ticks := 3) -> void:
	var now: int = scene.get("_ticks")
	(scene.get("_held") as Array).append(["device", now, now + ticks, c.index])
	for i in ticks + 2:
		await physics_frame


func _give(c, device: String) -> void:
	c.upgrades.assign([device])
	c.device = device
	c.device_wait = 0
	scene.call("_dress_crews")
