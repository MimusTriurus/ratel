# The prisoners on the 3D stage 1 preview: jackal.FriendlySoldier, and what
# lets them out -- Hut, House and Help -- on jackal_pow.glb (jackal_units.blend).
#
# Nothing here is part of the game, and the rules are the game's, run as the
# soldiers' are (level3d_soldiers.gd): in map pixels and ticks on the game's
# own map, the level only where they are drawn.
#
# What the game does, and so this:
#   * A hut (HUT, the level's barracks) blown open lets out one prisoner who
#     carries a weapon and flashes through four colours. He walks out of the
#     door, down, then waves and wanders. 300 points.
#   * A POW house (HOUSE_LEFT / HOUSE_RIGHT, the level's hangars) blown open
#     shows HELP four times, then its prisoners come out of the side one at a
#     time -- two to four of them. Each walks out and waves; the next waits in
#     the door, waving, until the one before him is picked up. 800 points.
#   * A prisoner wanders at 1 px a tick, twice a soldier's pace, for one to
#     four seconds, waves for two, and wanders again. Nothing hurts him.
#   * The player picks him up by driving over his centre. The weapon carrier
#     is a weapon upgrade (Main.upgrade_weapon), any other one a prisoner
#     aboard; die with more than one aboard and some of them scatter again.
#   * Both buildings' footprints are solid until they are blown open, and then
#     their tiles become the ruin's (Level3DMap.trigger_group).
#
# The level's hangars are broken open on the side the game lets their
# prisoners out of: Hangar_N and Hangar_W, both HOUSE_RIGHT, were turned round
# in the stage file for it.
#
# The rescue helicopter at the landing port, and the 500 points a prisoner is
# worth there, are not here yet: prisoners are picked up and counted, and go
# nowhere. The weapon upgrade is counted, not given -- the BTR's rocket is
# what it is.
class_name Level3DFriends
extends Node3D

const POW_PATH := "res://resources/3d/jackal_pow.glb"
const PX := Level3DMap.PX

# FriendlySoldier.init(): a zero-width hit and mine box, 20 px tall -- the
# player has to drive over his middle. Centred on him here, as the enemy
# soldiers' are (level3d_soldiers.gd).
const MINE := Rect2(0, -10, 0, 20)
const SOLID := Rect2(-16, -60, 32, 66)
const HUT_POINTS := 300
const HOUSE_POINTS := 800
# Help: 60 ticks, then on and off every 12, four times.
const HELP_FIRST := 60
const HELP_BLINK := 12
const HELP_BLINKS := 4
const HELP_HEIGHT := 2.2

const WALK := "Pow_Walk"
const WAVE := "Pow_Wave"

# FriendlySoldier's colour sheets, green first: what J_PowColor and the black
# become as a weapon carrier flashes. Only the yellow sheet changes the black.
const SHEETS := [
	[Color8(13, 147, 0), Color()],
	[Color8(153, 78, 0), Color()],
	[Color8(102, 102, 102), Color()],
	[Color8(188, 190, 0), Color8(108, 7, 0)],
]

# The level's buildings the stage's POW buildings are: which destructible is
# which trigger is found by where they stand.
const HUT_NAMES: Array[String] = ["Barracks", "BarracksN", "BarracksN2", "BarracksN3"]
const HOUSE_NAMES: Array[String] = ["Hangar_E", "Hangar_N", "Hangar_W"]

var map: Level3DMap
var guns: Level3DGuns
var soldiers: Level3DSoldiers
var frame: Callable
var ground: Callable
var player_position: Callable
var scored: Callable
var verbose := false

# Player: pows and releaseable_pows; Main: has_missiles and missile_power.
var pows := 0
var releaseable_pows := 0
var has_missiles := false
var missile_power := 0

var friends: Array[Friend] = []
var _helps := []
var _bound := {}                # destructible name -> map building
var _scene: PackedScene
var _rng := RandomNumberGenerator.new()
var _furthest_top := INF


class Friend:
	var type: int
	var state: int
	var x: float            # map pixels
	var y: float
	var vx := 0.0
	var vy := 0.0
	var direction_x := 0.0
	var direction_y := 1.0
	var wandering := 0
	var leg_frames := 0
	var entry := 0
	var waving := 0
	var house_count := 0
	var left := false
	var colour_changing := false
	var colour_index := 0
	var brother: Friend
	var root: Node3D
	var player: AnimationPlayer
	var colour: StandardMaterial3D
	var dark: StandardMaterial3D
	var dark_colour: Color


func _ready() -> void:
	_rng.seed = 4
	_scene = load(POW_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export_pow() in jackal_units.blend" % POW_PATH)


# Each of the level's barracks and hangars to the nearest HUT or HOUSE of the
# map. `centres` is name -> level x, z of the building's footprint.
func bind(centres: Dictionary) -> void:
	for name in centres:
		var hut := HUT_NAMES.has(name)
		if not hut and not HOUSE_NAMES.has(name):
			continue
		var at := Level3DMap.to_map(centres[name])
		var best = null
		var best_d := INF
		for b in map.buildings:
			if (b.type == Triggers.HUT) != hut:
				continue
			var d := at.distance_to(_centre(b))
			if d < best_d:
				best_d = d
				best = b
		if best != null:
			_bound[name] = best
			if verbose:
				print("%s is the %s at %d, %d (%.0f px off)" % [name, "hut" if hut else "house",
						best.x, best.y, best_d])


static func _centre(b: Dictionary) -> Vector2:
	return Vector2(b.x + 96, b.y + (80 if b.type == Triggers.HUT else 96))


func reset() -> void:
	for f in friends:
		f.root.queue_free()
	friends.clear()
	for h in _helps:
		(h.label as Node).queue_free()
	_helps.clear()
	pows = 0
	releaseable_pows = 0
	has_missiles = false
	missile_power = 0
	_furthest_top = INF


# ----------------------------------------------------------------------------
# Buildings

# Hut.attack / House.attack, from the preview when a building is blown up.
func building_destroyed(name: String) -> void:
	if not _bound.has(name):
		return
	var b: Dictionary = _bound[name]
	map.trigger_group(b.group)
	if b.type == Triggers.HUT:
		guns.explode(_level3(Vector2(b.x + 80, b.y + 96)))
		_spawn(b.x + 96, b.y + 48, FriendlySoldierType.WEAPON_CARRIER, 0)
		scored.call(HUT_POINTS)
	else:
		guns.explode(_level3(Vector2(b.x + 96, b.y + 96)))
		var label := Label3D.new()
		label.text = "HELP"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.outline_size = 24
		label.modulate = Color(1, 1, 1)
		label.no_depth_test = true
		label.visible = false
		add_child(label)
		var at := Level3DMap.to_level(Vector2(b.x + 96, b.y + 84))
		label.position = Vector3(at.x, HELP_HEIGHT, at.y)
		_helps.append({"x": b.x + 96, "y": b.y + 84, "left": b.type == Triggers.HOUSE_LEFT,
				"count": HELP_FIRST, "blinks": 0, "label": label})
		scored.call(HOUSE_POINTS)


func _level3(p: Vector2) -> Vector3:
	var at := Level3DMap.to_level(p)
	return Vector3(at.x, 0.0, at.y)


# Help.update.
func _update_help(h: Dictionary) -> bool:
	h.count -= 1
	if h.count != 0:
		return false
	h.count = HELP_BLINK
	var label: Label3D = h.label
	label.visible = not label.visible
	if label.visible:
		return false
	h.blinks += 1
	if h.blinks < HELP_BLINKS:
		return false
	label.queue_free()
	_spawn(h.x + (-24 if h.left else 24), h.y + 28,
			FriendlySoldierType.HOUSE_LEFT_WALKING if h.left else FriendlySoldierType.HOUSE_RIGHT_WALKING,
			2 + _rng.randi_range(0, 2))
	return true


# ----------------------------------------------------------------------------
# The prisoners

func _spawn(x: float, y: float, type: int, house_count: int = -1) -> Friend:
	var f := Friend.new()
	f.x = x
	f.y = y
	f.type = type
	f.root = _scene.instantiate() as Node3D
	add_child(f.root)
	f.player = f.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_own_materials(f)
	friends.append(f)
	# FriendlySoldier._init
	if house_count < 0:
		f.colour_changing = type == FriendlySoldierType.WEAPON_CARRIER_WANDERER
		_start_wandering(f)
	else:
		f.house_count = house_count
		f.left = type == FriendlySoldierType.HOUSE_LEFT_WALKING or type == FriendlySoldierType.HOUSE_LEFT_WAVING
		match type:
			FriendlySoldierType.WEAPON_CARRIER:
				f.state = FriendlySoldier.STATE_ENTRY_DOWN
				f.colour_changing = true
				f.direction_x = 0
				f.direction_y = 1
				f.entry = 100
			FriendlySoldierType.HOUSE_LEFT_WALKING, FriendlySoldierType.HOUSE_RIGHT_WALKING:
				_promote(f)
			FriendlySoldierType.HOUSE_LEFT_WAVING, FriendlySoldierType.HOUSE_RIGHT_WAVING:
				f.state = FriendlySoldier.STATE_WAVING
	_place(f)
	if verbose:
		print("prisoner out at %.0f, %.0f" % [x, y])
	return f


func _own_materials(f: Friend) -> void:
	for mesh_instance in f.root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			if material.resource_name == "J_PowColor":
				f.colour = material.duplicate()
				mi.set_surface_override_material(surface, f.colour)
			elif material.resource_name == "J_SoldierDark":
				f.dark = material.duplicate()
				mi.set_surface_override_material(surface, f.dark)
	f.dark_colour = f.dark.albedo_color


# FriendlySoldier.promote and the walking half of _init: out of the house's
# side, with the next one behind him in the door.
func _promote(f: Friend) -> void:
	f.type = FriendlySoldierType.HOUSE_LEFT_WALKING if f.left else FriendlySoldierType.HOUSE_RIGHT_WALKING
	f.state = FriendlySoldier.STATE_ENTRY_LEFT if f.left else FriendlySoldier.STATE_ENTRY_RIGHT
	f.direction_x = -1 if f.left else 1
	f.direction_y = 0
	f.entry = 141
	if f.house_count > 0:
		f.brother = _spawn(f.x, f.y,
				FriendlySoldierType.HOUSE_LEFT_WAVING if f.left else FriendlySoldierType.HOUSE_RIGHT_WAVING,
				f.house_count - 1)


func _start_wandering(f: Friend) -> void:
	f.state = FriendlySoldier.STATE_WANDERING
	for i in 16:
		var angle := 6.283 * _rng.randf()
		f.direction_x = cos(angle)
		f.direction_y = sin(angle)
		if map.is_driveable(f.x + f.direction_x * 32, f.y + f.direction_y * 32):
			break
	f.vx = f.direction_x * FriendlySoldier.WALK_SPEED
	f.vy = f.direction_y * FriendlySoldier.WALK_SPEED
	f.wandering = FriendlySoldier.MIN_WANDER_TIME \
		+ _rng.randi_range(0, FriendlySoldier.MAX_WANDER_TIME - FriendlySoldier.MIN_WANDER_TIME - 1)


func _start_waving(f: Friend) -> void:
	f.state = FriendlySoldier.STATE_WAVING
	f.waving = FriendlySoldier.WAVING_DELAY


func tick() -> void:
	var view: Rect2 = frame.call()
	_furthest_top = minf(_furthest_top, Level3DMap.to_map(view.position).y)
	for i in range(_helps.size() - 1, -1, -1):
		if _update_help(_helps[i]):
			_helps.remove_at(i)
	for i in range(friends.size() - 1, -1, -1):
		var f := friends[i]
		_update(f)
		_place(f)
		# Enemy.check_bounds
		if f.y + SOLID.position.y > _furthest_top + Level3DSoldiers.CAMERA_BOUND + Level3DSoldiers.REMOVE_BOUND:
			_remove(f)


# FriendlySoldier.update.
func _update(f: Friend) -> void:
	match f.state:
		FriendlySoldier.STATE_ENTRY_DOWN:
			f.entry -= 1
			if f.entry <= 0:
				_start_waving(f)
			elif f.entry < 79:
				f.y += 2.0
				_legs(f)
		FriendlySoldier.STATE_ENTRY_LEFT, FriendlySoldier.STATE_ENTRY_RIGHT:
			f.entry -= 1
			if f.entry <= 0:
				_start_waving(f)
			elif f.entry < 120:
				f.x += -1.0 if f.state == FriendlySoldier.STATE_ENTRY_LEFT else 1.0
				_legs(f)
		FriendlySoldier.STATE_WAVING:
			_legs(f)
			if f.type == FriendlySoldierType.WEAPON_CARRIER or f.type == FriendlySoldierType.WANDERER \
					or f.type == FriendlySoldierType.WEAPON_CARRIER_WANDERER:
				f.waving -= 1
				if f.waving <= 0:
					_start_wandering(f)
		FriendlySoldier.STATE_WANDERING:
			_wander(f)


func _legs(f: Friend) -> void:
	if f.leg_frames == 0:
		f.leg_frames = FriendlySoldier.LEG_FRAMES - 1
	f.leg_frames -= 1


func _wander(f: Friend) -> void:
	var next_x := f.x + f.vx
	var next_y := f.y + f.vy
	var walkable := map.is_driveable_box(next_x - 16, next_y - 6, next_x + 16, next_y + 6)
	if walkable:
		var now := Rect2(Vector2(f.x, f.y) + SOLID.position, SOLID.size)
		var then := Rect2(Vector2(next_x, next_y) + SOLID.position, SOLID.size)
		for box in solids(f):
			if box.intersects(then) and not box.intersects(now):
				walkable = false
				break
	if walkable:
		f.x = next_x
		f.y = next_y
		_legs(f)
	else:
		var d := Level3DMap.suggest_direction_bounce(f.direction_x, f.direction_y, _rng)
		f.direction_x = d.x
		f.direction_y = d.y
		f.vx = FriendlySoldier.WALK_SPEED * d.x
		f.vy = FriendlySoldier.WALK_SPEED * d.y
	f.wandering -= 1
	if f.wandering <= 0:
		_start_waving(f)


# Everyone else's solid box, map px: the guns', the soldiers', the other
# prisoners'.
func solids(me = null) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for box in guns.solid_boxes():
		boxes.append(Rect2(Level3DMap.to_map(box.position), box.size / PX))
	boxes.append_array(soldiers.solid_boxes())
	boxes.append_array(solid_boxes(me))
	return boxes


# The prisoners' own solid boxes, map px, for the soldiers to walk round too.
func solid_boxes(me = null) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for f in friends:
		if f != me:
			boxes.append(Rect2(Vector2(f.x, f.y) + SOLID.position, SOLID.size))
	return boxes


# Where he is, which way he faces and the frame he is on. Waving, he faces
# the player; the sprite waves at the screen.
func _place(f: Friend) -> void:
	var at := Level3DMap.to_level(Vector2(f.x, f.y))
	f.root.position = Vector3(at.x, ground.call(at.x, at.y).height, at.y)
	var clip := WAVE if f.state == FriendlySoldier.STATE_WAVING else WALK
	var facing := Vector2(f.direction_x, f.direction_y)
	if clip == WAVE:
		var player: Vector2 = player_position.call()
		facing = player - at
	if facing.length_squared() > 1e-6:
		f.root.rotation.y = atan2(facing.x, facing.y)
	if f.player.current_animation != clip:
		f.player.play(clip)
		f.player.pause()
	var length := f.player.get_animation(clip).length
	var phase := float(FriendlySoldier.LEG_FRAMES - 1 - f.leg_frames) / FriendlySoldier.LEG_FRAMES
	f.player.seek(phase * length, true)


# FriendlySoldier.render's colour, a sheet a frame while he flashes.
func _process(_delta: float) -> void:
	for f in friends:
		if f.colour_changing:
			f.colour_index = (f.colour_index + 1) & 3
		var sheet: Array = SHEETS[f.colour_index]
		f.colour.albedo_color = sheet[0]
		f.dark.albedo_color = sheet[1] if sheet[1] != Color() else f.dark_colour


func _remove(f: Friend) -> void:
	friends.erase(f)
	f.root.queue_free()


# FriendlySoldier.bump from Player.update: driven over, he is aboard. Not while
# the player is gone (respawning), which the preview sees to.
func bump(player_box: Rect2) -> void:
	for f in friends.duplicate():
		var box := Rect2(Vector2(f.x, f.y) + MINE.position, MINE.size)
		var level := Rect2(Level3DMap.to_level(box.position), box.size * PX)
		if not player_box.intersects(level, true):
			continue
		_remove(f)
		if f.type == FriendlySoldierType.WEAPON_CARRIER or f.type == FriendlySoldierType.WEAPON_CARRIER_WANDERER:
			# Player.pick_up_flashing_soldier
			pows += 1
			_upgrade_weapon()
		else:
			# Player.collect_pow
			pows += 1
			releaseable_pows += 1
		if f.brother != null:
			_promote(f.brother)
		if verbose:
			print("prisoner picked up: %d aboard, weapon %s" % [pows, weapon_name()])


# Main.upgrade_weapon, without the Konami code.
func _upgrade_weapon() -> void:
	if has_missiles:
		missile_power = mini(missile_power + 1, 2)
	else:
		has_missiles = true


func weapon_name() -> String:
	if not has_missiles:
		return "grenade"
	return ["missile", "missile+", "missile++"][missile_power]


# Player.explode's half about the prisoners: with more than one aboard, some
# scatter where he blew up -- one of them carrying the weapon, sometimes --
# and he loses the lot, and the weapon.
func player_died(at: Vector3) -> void:
	if releaseable_pows > 1:
		var weapon_carrier := has_missiles and _rng.randi_range(0, 4) == 3
		if weapon_carrier:
			releaseable_pows += 1
		var release := mini(releaseable_pows - 2, 3)
		var p := Level3DMap.to_map(Vector2(at.x, at.z))
		for i in range(release, -1, -1):
			_spawn(p.x, p.y, FriendlySoldierType.WEAPON_CARRIER_WANDERER if (weapon_carrier and i == 0)
					else FriendlySoldierType.WANDERER)
	pows = 0
	releaseable_pows = 0
	missile_power = 0
	has_missiles = false
