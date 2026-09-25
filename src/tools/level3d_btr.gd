# The BTR on the 3D stage 1 preview: its model, and how it drives.
#
# Nothing here is part of the game. The model is resources/3d/ratel_btr.glb,
# exported from ratel_btr_lowpoly.blend with the single gun and all four
# rocket launcher fits, which level3d_rocket.gd shows one at a time; the level
# it drives on is level3d_preview.gd's.
#
# The driving is the tank bench's in BlenderMCP/godot -- TankTick.AdvanceOrder
# with a MovementProfile row -- carried from hex legs to free ground:
#
#   * A class is a top speed, an acceleration and a turn rate, and it is the
#     acceleration that reads as mass, not the top speed.
#   * Braking is a ceiling, not a pedal: the fastest the vehicle may be going
#     and still stop in what is left, sqrt(v_end^2 + 2 a d). Read every frame it
#     has no moment of engagement to miss, so an order ends at rest on the point
#     instead of arriving at a third of cruise and stopping dead.
#   * At a bend the speed comes down to a crawl, and the ceiling for a straight
#     run ends at that crawl rather than at zero. A standing start with the goal
#     off the nose begins with the turn.
#   * What it cannot drive into is the game's to say, in either mode: the
#     jeep's three sensors on the map's collision grid (_blocked).
#   * The body pitch is BodyPitch's spring, driven by acceleration.
#   * The turret has its own traverse rate; unaimed, it comes round to the bow
#     while the hull is moving and stays where it was left when it is not.
#   * The gun (level3d_gun.gd) asks it where the muzzle is and kicks the same
#     pitch spring on every round; the rocket launcher (level3d_rocket.gd)
#     turns its own mount on the hull and kicks it harder.
#
# One deliberate departure: wheels cannot pivot. The bench's tanks swing round
# on the spot at the crawl floor; a BTR has to roll to turn, so the crawl is a
# target it speeds up to while turning, the yaw rate is capped by the speed over
# MIN_TURN_RADIUS, and a goal inside the turning circle is reached by backing
# out of it first -- a three-point turn instead of a pivot.
#
# All of that is the free mode. The classic mode, the default, drives by the
# keys as the game's jeep does, Player.update line for line on the game's map
# (level3d_map.gd) rather than on the scene:
#
#   * The keys are the screen's eight directions, not a throttle and a wheel,
#     and the BTR goes the way they point at once, at Player.SPEED -- 2.5 px a
#     tick, 3.66 m/s at the map's PX -- and half that in swamp. No
#     acceleration, no braking: it stops the tick the keys are let go.
#   * The hull turns after it, 45 degrees every ANGLE_STEPS ticks and always the
#     short way round, while the BTR is already moving the new way; letting go
#     of one half of a diagonal keeps the diagonal for DIAGONAL_DELAY ticks.
#   * What stops it is the game's three sensors ahead of it, asked of the map's
#     collision grid.
#   * The turret, and the rocket launcher's mount with it, come round in a
#     tick or two rather than at the free mode's traverse rates: the game's
#     jeep fires the way it is asked to the tick it is asked, and a gun that
#     lagged would put its rounds somewhere the player did not aim.
#
# It is written per tick: the preview's physics runs at the game's 100 Hz. The
# bottom of the frame does not hold it back, as the game's camera does; the
# preview's camera follows the BTR wherever it goes. Orders from the middle
# button are the free mode's in either, at the classic mode's top speed.
#
# Both modes stop at the same things, the classic mode's: the grid's solid,
# shield and water tiles, and the forest, which the grid has as solid. The
# scene's own collision -- walls, palm trunks, the sea -- used to decide it
# for the free mode, and the two disagreed where the level's models and the
# game's tiles do: the free BTR went over the rocks and sandbags, which the
# grid does not let the jeep on to, and stopped at every palm trunk, which it
# does. The scene is still asked for the ground's height, to sit and tilt the
# hull on.
#
# The same code drives the jeep, the default -- --btr for the BTR --
# resources/3d/jackal_jeep.glb,
# built from jackal_jeep_lowpoly.blend with the BTR's part names, Jeep_ for
# BTR_, so the gun and the launchers read it the same way. VEHICLES says what
# differs. The jeep is also livelier, which the BTR keeps out of:
#
#   * Its body rolls out of a turn as well as pitching to the throttle, on a
#     softer spring than the BTR's -- the roll taken off the heading's turn,
#     which the classic mode's 45 degree steps turn fast enough to show.
#   * It rumbles while it drives, as the game's sprite does: Player.RUMBLE's
#     1.6 px, 0.74 rad a frame, here up and down on its wheels, and dies
#     away when it stops: standing, it stands still.
#   * Its two whip aerials bend: each a chain of links (aerials() in the
#     builder) on a spring of its own, pushed by the hull's acceleration --
#     the change of its velocity, so the classic mode's starts, stops and
#     turns in a tick kick them -- and dragged by the hull's tilt.
class_name Level3DBtr
extends Node3D

# The model is modelled at 1:1 (5.8 m long, 3.5 m over the wheels); the level
# is not. The scale is the game's jeep's: the hut is 192 px across in the game
# and its model 3.3 m, so a map pixel is 1.7 cm, and the jeep's 64 x 92 px
# sprite is 1.10 x 1.58 m. At 0.31 the BTR is the jeep's width, 1.1 m, and
# 1.8 m long -- 15% longer, being the longer vehicle for its width. It was 0.5
# once, set by eye against the bunkers, which made it nearly twice the jeep.
# The Chinook is at this scale too, whichever vehicle it carries.
const MODEL_SCALE := 0.31

# What differs between the two, in each model's own metres and axes:
#   path, prefix   the glb, and the prefix of its part names
#   scale          model to level. The jeep's is its sprite's: jackal_jeep.py
#                  makes 92 x 64 px 3.6 x 2.5 m, and 92 px is 1.35 m
#   facing         the model's yaw to face +X, the heading's zero: the BTR is
#                  modelled along +X, the jeep along Godot's +Z
#   axles          wheel pairs, <prefix>Wheel_L1.., the first one steering
#   wheel_radius, wheelbase
#   nose, half_width   where the ground is sampled for the tilt: ahead of and
#                  behind the origin by half the nose, and beside it
#   body           what it covers from above, hull and wheels: back, front
#                  (along the heading) and half its width (push_out)
#   ramp_axles     the front and rear axles, along the heading: what it rides
#                  the Chinook's ramp by
#   pitch, roll    each spring's gain (radians at full acceleration, or at
#                  ROLL_FULL of sideways acceleration), stiffness, damping
#   kick           rad/s into the pitch spring for every m/s the speed changes
#                  in a tick: the classic mode's starts and stops are a tick
#                  long, which the gain alone, held for one tick, never shows
#   rumble         the driving rumble's height, level metres
#   aerials        the aerial chains' names, without the prefix and link
#   spare_fits     launcher fits the model has and the game's four weapons do
#                  not use (level3d_rocket.gd's FITS): hidden
const VEHICLES := {
	"btr": {"path": "res://resources/3d/ratel_btr.glb", "prefix": "BTR_", "scale": MODEL_SCALE,
			"facing": 0.0, "axles": 3, "wheel_radius": 0.66, "wheelbase": 3.06,
			"nose": 3.5, "half_width": 1.3, "body": [-2.45, 3.74, 1.83], "ramp_axles": [2.25, -1.52],
			# BodyPitch, verbatim: zeta 0.65 at omega 21.9.
			"pitch": [0.030, 480.0, 28.5], "roll": [0.0, 480.0, 28.5], "kick": 0.0,
			"rumble": 0.0, "aerials": []},
	"jeep": {"path": "res://resources/3d/jackal_jeep.glb", "prefix": "Jeep_", "scale": 0.375,
			"facing": PI / 2.0, "axles": 2, "wheel_radius": 0.44, "wheelbase": 2.3,
			"nose": 2.3, "half_width": 1.0, "body": [-1.97, 2.01, 1.33], "ramp_axles": [1.2, -1.1],
			# Softer than the BTR's and less damped, zeta 0.45 at omega 16: a
			# light vehicle on long travel.
			"pitch": [0.045, 256.0, 14.4], "roll": [0.07, 256.0, 14.4], "kick": 0.25,
			"rumble": 1.6 * Level3DMap.PX, "aerials": ["AerialL", "AerialR"],
			"spare_fits": ["GradBase", "TubeLauncherBase"]},
}
# Sideways acceleration, m/s^2, that leans the body over by all its roll gain:
# the free mode's tightest turn at its top speed.
const ROLL_FULL := 8.0
# Player.RUMBLE's step, radians a rendered frame at the game's 60.
const RUMBLE_RATE := 0.74 * 60.0
const RUMBLE_FADE := 0.15
# The aerials' spring: omega, rad/s, for each of the two -- a little apart, so
# they do not sway in step -- and zeta; how hard acceleration pushes them,
# rad/s^2 per m/s^2; and the most acceleration that counts, which the classic
# mode's changes of velocity in a tick would otherwise make infinite.
const AERIAL_OMEGA := [15.0, 16.5]
const AERIAL_ZETA := 0.12
const AERIAL_PUSH := 4.6
const AERIAL_ACCEL_MAX := 60.0
# How much of the bend each link takes, foot to tip.
const AERIAL_SHARES := [0.25, 0.35, 0.4]

# The profile row, in level metres. Top speed is the jeep's: 2.5 px a tick at
# 100 ticks a second is 250 px/s, 4.3 m/s. It is reached in the tank bench's
# 0.58 s (BlenderMCP/godot, MTP's MovementProfile row).
const TOP_SPEED := 4.3
# The classic mode's, which is the game's own: Player.SPEED at 100 ticks a
# second, converted by the map's PX like every other game distance.
const CLASSIC_SPEED := Player.SPEED * 100.0 * Level3DMap.PX
const ACCEL := 7.4
const TURN_RATE := deg_to_rad(110.0)
const REVERSE_FRACTION := 0.4
# The bench's CornerFraction is 0.12 for a tank that pivots; a vehicle that has
# to roll through a corner needs more than that to get round at all.
const CORNER_FRACTION := 0.35
# Scaled with the model from the 2.2 m it had at 0.5.
const MIN_TURN_RADIUS := 1.4
const TURRET_RATE := deg_to_rad(175.0)
# The classic mode's, for the turret and the launcher: half a turn in five
# ticks, 45 degrees in one or two.
const CLASSIC_TURRET_RATE := deg_to_rad(3600.0)
# Above this much heading error the order slows to the crawl to swing round.
const SWING_THRESHOLD := deg_to_rad(25.0)
const ARRIVE_RADIUS := 0.3
# The hull follows the ground's slope, but not across a jump bigger than this
# between its ends, which is an edge rather than a slope.
const TILT_STEP := 0.3
# The same where either end is on a ruined bunker's ramp (level3d_preview.gd,
# _add_bunker_ramp), which is steeper than any slope of the level's: it climbs
# a bunker's 0.72 m in well under a metre.
const RAMP_TILT_STEP := 1.0

# The body spring's (VEHICLES' pitch) knock on running into something at
# TOP_SPEED, rad/s; less for slower. Positive pitch is nose down.
const BUMP_JOLT := 1.5
# How far along a tyre's mark its lugs repeat, level metres.
const TYRE_PITCH := 0.08

# Asked of the scene: `ground.call(x, z)` returns
# {"height": float, "kind": String, "hit": bool} for the top surface there.
var ground: Callable

var heading := 0.0          # radians, 0 = +X, counter-clockwise from above
var speed := 0.0            # m/s along the heading, negative in reverse
var yaw_rate := 0.0
var turret := 0.0           # relative to the hull
var aim_point = null        # Vector3 or null
var turret_input := 0.0     # -1..1 from the keys
var throttle := 0.0         # -1..1 from the keys
var steer := 0.0            # -1..1 from the keys
var waypoints: Array[Vector3] = []
var backing := false

# The classic mode: Player's keys, read as up / down / left / right, and its
# state, in the game's degrees -- 0 east, 90 south, clockwise on the screen.
# The map is the preview's, asked for the grid.
var classic := true
var map: Level3DMap
var key_up := false
var key_down := false
var key_left := false
var key_right := false
var angle := 270
var next_angle := 270
var display_angle := 270.0
var angle_velocity := 0.0
var angle_steps := 0
var diagonal_delay := 0
var target_angle := -1
var last_target_angle := 270
var fire_angle := 270.0
var _classic_synced := false

# VEHICLES' entry for the one driven, and what it scales to in the level.
var vehicle: Dictionary
var model_scale: float

var _pitch := 0.0
var _pitch_velocity := 0.0
var _roll := 0.0
var _roll_velocity := 0.0
var _wheel_spin := 0.0
var _steer_angle := 0.0
var _model: Node3D
var _hull: Node3D
var _turret_pivot: Node3D
var _bore: Node3D
var _hull_rest: Transform3D
var _turret_rest: Transform3D
var _wheels: Array[Node3D] = []
var _wheel_rest: Array[Transform3D] = []
var _front_wheels: Array[bool] = []
var _rear_wheels: Array[bool] = []
var _tyre_width := 0.0         # level metres, for the marks it leaves
var _tilt := Basis()
# The model's own forward and the axis across it that pitches the nose down
# and rolls the wheels forward, in its parent's space: VEHICLES' facing.
var _ahead := Vector3.RIGHT
var _across := Vector3.BACK
# The rumble's phase and how much of it there is, and the last tick's
# velocity, for what the aerials feel.
var _rumble := 0.0
var _rumble_level := 0.0
var _velocity := Vector3.ZERO
# Each aerial: its links and their rests, and its spring's two angles --
# pitch and roll, as the body's -- with their rates.
var _aerials := []


func _ready() -> void:
	vehicle = VEHICLES["btr" if OS.get_cmdline_user_args().has("--btr") else "jeep"]
	model_scale = vehicle.scale
	var prefix: String = vehicle.prefix
	var scene: PackedScene = load(vehicle.path)
	_model = scene.instantiate()
	add_child(_model)
	_model.transform = Transform3D(Basis(Vector3.UP, vehicle.facing).scaled(Vector3.ONE * model_scale), Vector3.ZERO)
	_hull = _model.find_child(prefix + "Hull", true, false)
	_ahead = Basis(Vector3.UP, -vehicle.facing) * Vector3.RIGHT
	_across = Vector3.UP.cross(_ahead)
	_turret_pivot = _model.find_child(prefix + "TurretPivot", true, false)
	# The bore mesh's own axes are the cylinder's, its length along local Y, so
	# the muzzle is a node of its own: on the turret, where the bore is, facing
	# the way the gun points, which is the model's forward, as its +X.
	var bore := _turret_pivot.find_child(prefix + "GunBore", true, false) as Node3D
	_bore = Node3D.new()
	_bore.name = "Muzzle"
	_turret_pivot.add_child(_bore)
	_bore.position = _turret_pivot.global_transform.affine_inverse() * bore.global_position
	_bore.basis = Basis(Vector3.UP, -vehicle.facing)
	for spare in vehicle.get("spare_fits", []):
		var fit := _hull.find_child(prefix + spare, true, false) as Node3D
		if fit != null:
			fit.visible = false
	_hull_rest = _hull.transform
	_turret_rest = _turret_pivot.transform
	for side in ["L", "R"]:
		for axle in vehicle.axles:
			var wheel := _model.find_child("%sWheel_%s%d" % [prefix, side, axle + 1], true, false) as Node3D
			if wheel == null:
				continue
			_wheels.append(wheel)
			_wheel_rest.append(wheel.transform)
			_front_wheels.append(axle == 0)
			_rear_wheels.append(axle == vehicle.axles - 1)
	_tyre_width = _narrowest(_wheels[0]) if not _wheels.is_empty() else 0.0
	for i in vehicle.aerials.size():
		var links: Array[Node3D] = []
		var rests: Array[Transform3D] = []
		for k in AERIAL_SHARES.size():
			var link := _hull.find_child("%s%s%d" % [prefix, vehicle.aerials[i], k], true, false) as Node3D
			if link == null:
				break
			links.append(link)
			rests.append(link.transform)
		_aerials.append({"links": links, "rests": rests, "omega": AERIAL_OMEGA[i % AERIAL_OMEGA.size()],
				"angle": Vector2.ZERO, "rate": Vector2.ZERO})


# The gun's bore: where rounds leave from, its +X the way they go.
func muzzle_node() -> Node3D:
	return _bore


func muzzle() -> Transform3D:
	return _bore.global_transform.orthonormalized()


# A rocket launcher's mount, on the hull, by the name of its base:
# level3d_rocket.gd picks the fit and turns it.
func launcher_node(base_name: String) -> Node3D:
	return _hull.find_child(base_name, true, false)


# A shot's kick into the body spring, signed along the bow: firing ahead
# lifts the nose, firing astern dips it, firing abeam does neither.
func recoil(direction: Vector3, kick: float) -> void:
	_pitch_velocity -= kick * direction.dot(forward())


func top_speed() -> float:
	return CLASSIC_SPEED if classic else TOP_SPEED


func corner_speed() -> float:
	return top_speed() * CORNER_FRACTION


func forward() -> Vector3:
	return Vector3(cos(heading), 0.0, -sin(heading))


# How far, and which way, level point `p` has to go to be `margin` metres clear
# of what the BTR covers: out through the nearest side, or `sideways`, the
# nearer of the two flanks. Zero when it is clear.
func push_out(p: Vector3, margin := 0.0, sideways := false) -> Vector3:
	var d := p - global_position
	var ahead := forward()
	var side := Vector3(sin(heading), 0.0, cos(heading))
	var along := d.dot(ahead)
	var across := d.dot(side)
	var back: float = vehicle.body[0] * model_scale - margin
	var front := body_front() + margin
	var half: float = vehicle.body[2] * model_scale + margin
	if along <= back or along >= front or absf(across) >= half:
		return Vector3.ZERO
	var ways := [side * (half - across), -side * (half + across)]
	if not sideways:
		ways += [ahead * (front - along), -ahead * (along - back)]
	var best: Vector3 = ways[0]
	for way in ways:
		if (way as Vector3).length() < best.length():
			best = way
	return best


# How far its front is ahead of its origin, level metres.
func body_front() -> float:
	return vehicle.body[1] * model_scale


# Its front and rear axles, level metres along the heading from its origin.
func front_axle() -> float:
	return vehicle.ramp_axles[0] * model_scale


func rear_axle() -> float:
	return vehicle.ramp_axles[1] * model_scale


func _wheel_radius() -> float:
	return vehicle.wheel_radius * model_scale


# Level3DTracks' contacts: where the rear wheels touch the ground, a mark
# each. The ones ahead run in them going straight, and two marks laid over
# each other would come out darker than one. None while it is gone.
func wheel_tracks() -> Array:
	var contacts := []
	if not visible:
		return contacts
	for i in _wheels.size():
		if _rear_wheels[i]:
			contacts.append({"key": "wheel%d" % i,
					"at": _wheels[i].global_position - Vector3.UP * _wheel_radius(),
					"width": _tyre_width, "pitch": TYRE_PITCH, "tread": 0.0})
	return contacts


# A wheel's narrowest extent, level metres: its tyre's width, while it
# stands square to the axes, as it does before it has moved.
static func _narrowest(wheel: Node3D) -> float:
	var meshes: Array = wheel.find_children("*", "MeshInstance3D", true, false)
	if wheel is MeshInstance3D:
		meshes.append(wheel)
	var box := AABB()
	for i in meshes.size():
		var m := meshes[i] as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if i == 0 else box.merge(b)
	return minf(box.size.x, minf(box.size.y, box.size.z))


func place(at: Vector3, facing: float) -> void:
	position = at
	heading = facing
	speed = 0.0
	yaw_rate = 0.0
	waypoints.clear()
	backing = false
	_pitch = 0.0
	_pitch_velocity = 0.0
	_roll = 0.0
	_roll_velocity = 0.0
	_velocity = Vector3.ZERO
	for aerial in _aerials:
		aerial.angle = Vector2.ZERO
		aerial.rate = Vector2.ZERO
	_classic_synced = false
	_settle(0.0, true)
	_pose()


# Posed from outside, while the Chinook unloads it (level3d_chinook.gd): where
# it is, which way it faces and how far its nose is up, the wheels turning by
# how far it went. None of the driving runs.
func carry(at: Vector3, facing: float, nose_up: float) -> void:
	_wheel_spin -= (at - position).dot(forward()) / _wheel_radius()
	position = at
	heading = facing
	speed = 0.0
	yaw_rate = 0.0
	waypoints.clear()
	backing = false
	_classic_synced = false
	_velocity = Vector3.ZERO
	_tilt = Basis(Vector3(0, 0, 1), nose_up)
	_pose()


func order(to: Vector3, append: bool) -> void:
	if not append:
		waypoints.clear()
	waypoints.append(Vector3(to.x, 0.0, to.z))
	backing = false


func stop() -> void:
	waypoints.clear()
	backing = false


func step(delta: float) -> void:
	var before := speed
	var was := position
	var heading_was := heading
	var keys := key_up or key_down or key_left or key_right
	if classic and (keys or waypoints.is_empty()):
		if keys:
			waypoints.clear()
			backing = false
		_drive_classic(delta)
	else:
		_classic_synced = false
		_step_free(delta)

	# What the body felt, not which branch ran: signed along the bow, so pulling
	# away in reverse dips the nose just as braking does.
	var accel_ratio := clampf((speed - before) / (ACCEL * delta), -1.0, 1.0) if delta > 0.0 else 0.0
	_pitch_velocity -= vehicle.kick * (speed - before)
	_update_pitch(accel_ratio, delta)
	if delta > 0.0:
		var moved := position - was
		_update_roll(speed * wrapf(heading - heading_was, -PI, PI) / delta, delta)
		_update_aerials(Vector3(moved.x, 0.0, moved.z) / delta, delta)
	_update_turret(delta)
	_settle(delta, false)
	_update_engine(keys or absf(speed) > 0.05, delta)
	_pose()


# Where the grenade would go this tick, as Player.update fires it: the way the
# keys point, or with none held and the hull not turning, the way it faces.
func classic_fire_angle() -> float:
	return float(angle) if target_angle == -1 and angle_steps == 0 else fire_angle


func _step_free(delta: float) -> void:
	if throttle != 0.0 or steer != 0.0:
		waypoints.clear()
		_drive_by_keys(delta)
	elif not waypoints.is_empty():
		_drive_order(delta)
	else:
		_coast(delta)

	var moved := speed * delta
	var next := position + forward() * moved
	if moved != 0.0 and _blocked(position, signf(moved)):
		# Hit something. The hull stops where it is and the nose takes the
		# knock -- the bench's FallJolt, the other way round -- as hard as it
		# was going: a key held against the wall runs into it again every
		# tick from a standstill, and a whole jolt each time held the nose
		# down 34 degrees. The kick in step() takes the same stop, so this is
		# only what it leaves of the knock.
		_pitch_velocity += (BUMP_JOLT / TOP_SPEED - vehicle.kick) * speed
		speed = 0.0
		waypoints.clear()
		backing = false
		moved = 0.0
	else:
		position = next
	heading = wrapf(heading + yaw_rate * delta, -PI, PI)
	_wheel_spin -= moved / _wheel_radius()


# ----------------------------------------------------------------------------
# Classic

# Player.update's movement and turn, one tick of it. The position is the map's
# for the tick, in game pixels; the heading is the display angle's, which is
# what the game draws the jeep at.
func _drive_classic(delta: float) -> void:
	if not _classic_synced:
		_sync_classic()
	var from := Level3DMap.to_map(Vector2(position.x, position.z))
	var p := from
	var v := 0.5 * Player.SPEED if map.is_swamp(p.x, p.y) else Player.SPEED

	target_angle = -1
	if key_down and key_right:
		p = _classic_diagonal(p, 1, 1, v)
	elif key_down and key_left:
		p = _classic_diagonal(p, -1, 1, v)
	elif key_up and key_left:
		p = _classic_diagonal(p, -1, -1, v)
	elif key_up and key_right:
		p = _classic_diagonal(p, 1, -1, v)
	elif key_right:
		p = _classic_straight(p, 0, 45, 315, v)
	elif key_down:
		p = _classic_straight(p, 90, 45, 135, v)
	elif key_left:
		p = _classic_straight(p, 180, 135, 225, v)
	elif key_up:
		p = _classic_straight(p, 270, 225, 315, v)
	else:
		diagonal_delay = 0

	if angle_steps > 0:
		angle_steps -= 1
		if angle_steps == 0:
			angle = next_angle
			display_angle = next_angle
		else:
			display_angle += angle_velocity

	# Turning always takes the short way round, 45 degrees at a time.
	if angle_steps == 0 and target_angle != -1 and target_angle != angle:
		angle_steps = Player.ANGLE_STEPS
		if target_angle == 0:
			if angle >= 180:
				next_angle = angle + 45
				if next_angle == 360:
					next_angle = 0
				angle_velocity = Player.ANGLE_VELOCITY
			else:
				next_angle = angle - 45
				angle_velocity = -Player.ANGLE_VELOCITY
		elif target_angle == 180:
			if angle > 180:
				next_angle = angle - 45
				angle_velocity = -Player.ANGLE_VELOCITY
			elif angle == 0:
				next_angle = 315
				angle_velocity = -Player.ANGLE_VELOCITY
			else:
				next_angle = angle + 45
				angle_velocity = Player.ANGLE_VELOCITY
		elif target_angle > 180:
			if angle < target_angle and angle >= target_angle - 180:
				next_angle = angle + 45
				angle_velocity = Player.ANGLE_VELOCITY
			else:
				next_angle = angle - 45
				angle_velocity = -Player.ANGLE_VELOCITY
		else:
			if angle > target_angle and angle <= target_angle + 180:
				next_angle = angle - 45
				angle_velocity = -Player.ANGLE_VELOCITY
			else:
				next_angle = angle + 45
				angle_velocity = Player.ANGLE_VELOCITY
		if next_angle == -45:
			next_angle = 315
		elif next_angle == 360:
			next_angle = 0

	var moved := (p - from) * Level3DMap.PX
	position.x += moved.x
	position.z += moved.y
	speed = moved.length() / delta if delta > 0.0 else 0.0
	yaw_rate = 0.0
	# The game's angles run clockwise on a screen whose y points down the
	# stage; the heading runs counter-clockwise from above.
	heading = wrapf(-deg_to_rad(display_angle), -PI, PI)
	_wheel_spin -= moved.length() / _wheel_radius()
	# The front wheels show the turn while there is one; clockwise is to the
	# right, which is a negative wheel angle.
	var wheels := -0.35 * signf(angle_velocity) if angle_steps > 0 and speed > 0.0 else 0.0
	_steer_angle = move_toward(_steer_angle, wheels, 3.0 * delta)


# The four diagonal branches of Player.update: the diagonal sensors mirrored
# into the quadrant, and the move if all three are on driveable ground.
func _classic_diagonal(p: Vector2, dx: int, dy: int, v: float) -> Vector2:
	var a := 45 if dx > 0 and dy > 0 else 135 if dy > 0 else 225 if dx < 0 else 315
	fire_angle = a
	target_angle = a
	last_target_angle = a
	diagonal_delay = Player.DIAGONAL_DELAY
	if map.is_driveable(p.x + dx * Player.SENSOR_D_X0, p.y + dy * Player.SENSOR_D_Y0) \
			and map.is_driveable(p.x + dx * Player.SENSOR_D_X1, p.y + dy * Player.SENSOR_D_Y1) \
			and map.is_driveable(p.x + dx * Player.SENSOR_D_X2, p.y + dy * Player.SENSOR_D_Y2):
		p += Vector2(dx, dy) * v
	return p


# The four axis branches: unless one half of a diagonal was just let go of, in
# which case the diagonal is kept for a few ticks without moving, the sensor
# SENSOR_X + SPEED ahead and SENSOR_Y either side of it.
func _classic_straight(p: Vector2, a: int, keep_a: int, keep_b: int, v: float) -> Vector2:
	fire_angle = a
	if (last_target_angle == keep_a or last_target_angle == keep_b) and diagonal_delay > 0:
		diagonal_delay -= 1
		return p
	target_angle = a
	last_target_angle = a
	diagonal_delay = 0
	var d := Level3DMap.unit_vector(a)
	var ahead := p + d * (Player.SENSOR_X + Player.SPEED)
	var side := Vector2(-d.y, d.x) * Player.SENSOR_Y
	if map.is_driveable(ahead.x, ahead.y) \
			and map.is_driveable(ahead.x - side.x, ahead.y - side.y) \
			and map.is_driveable(ahead.x + side.x, ahead.y + side.y):
		p += d * v
	return p


# Into the game's eight directions from wherever the free mode, an order or a
# placing left the hull: the nearest of them, turned into over one step of the
# game's own turn rather than snapped to.
func _sync_classic() -> void:
	var current := -rad_to_deg(heading)
	var nearest := posmod(45 * roundi(current / 45.0), 360)
	var off := wrapf(nearest - current, -180.0, 180.0)
	angle = nearest
	next_angle = nearest
	last_target_angle = nearest
	fire_angle = nearest
	target_angle = -1
	diagonal_delay = 0
	if absf(off) < 0.01:
		display_angle = nearest
		angle_steps = 0
	else:
		display_angle = nearest - off
		angle_velocity = off / Player.ANGLE_STEPS
		angle_steps = Player.ANGLE_STEPS
	_classic_synced = true


# ----------------------------------------------------------------------------
# Driving

func _drive_by_keys(delta: float) -> void:
	var target := throttle * top_speed() * (1.0 if throttle >= 0.0 else REVERSE_FRACTION)
	speed = move_toward(speed, target, ACCEL * delta)
	_set_yaw(steer * TURN_RATE)


func _coast(delta: float) -> void:
	speed = move_toward(speed, 0.0, ACCEL * delta)
	_set_yaw(0.0)


func _drive_order(delta: float) -> void:
	var goal: Vector3 = waypoints[0]
	var to := Vector3(goal.x - position.x, 0.0, goal.z - position.z)
	var distance := to.length()
	if distance < ARRIVE_RADIUS:
		waypoints.remove_at(0)
		if waypoints.is_empty():
			_coast(delta)
		return

	var wanted := atan2(-to.z, to.x)
	var diff := wrapf(wanted - heading, -PI, PI)

	# A goal inside the turning circle on the side it lies can never be driven
	# on to forwards; back out, wheels the other way, until it is outside.
	var side := signf(diff) if diff != 0.0 else 1.0
	var left := Vector3(-sin(heading), 0.0, -cos(heading))
	var centre := position + left * side * MIN_TURN_RADIUS
	var inside := Vector3(goal.x - centre.x, 0.0, goal.z - centre.z).length() < MIN_TURN_RADIUS * 1.05
	if backing:
		backing = inside or absf(diff) > deg_to_rad(100.0) and distance < MIN_TURN_RADIUS * 2.0
	else:
		backing = inside and absf(diff) > SWING_THRESHOLD
	if backing:
		speed = move_toward(speed, -corner_speed(), ACCEL * delta)
		_set_yaw(-side * TURN_RATE)
		return

	if absf(diff) > SWING_THRESHOLD:
		# Slow to the crawl and swing round. The bench's crawl is a floor it
		# never speeds up to, because a tank pivots; wheels have to roll to
		# turn, so here it is the target from below as well.
		speed = move_toward(speed, corner_speed(), ACCEL * delta)
		_set_yaw(side * TURN_RATE)
		return

	var run := _remaining_run()
	var ceiling := sqrt(run.y * run.y + 2.0 * ACCEL * maxf(run.x, 0.0))
	var allowed := minf(top_speed(), ceiling)
	# Slowed into rather than snapped to: a cap that drops by more than the
	# engine can take off in a frame is approached at the engine's own rate.
	speed = maxf(allowed, speed - ACCEL * delta) if speed > allowed \
			else minf(speed + ACCEL * delta, allowed)
	_set_yaw(clampf(diff / maxf(delta, 0.0001), -TURN_RATE, TURN_RATE))


# Distance left along the straight run and the speed to be doing at its end:
# the run carries on through waypoints that do not bend it, and ends at the
# crawl at a bend or at rest at the last one -- the bench's RemainingRun.
func _remaining_run() -> Vector2:
	var from := Vector3(position.x, 0.0, position.z)
	var total := 0.0
	var direction := Vector3.ZERO
	for i in waypoints.size():
		var leg := waypoints[i] - from
		var d := leg.normalized()
		if i > 0 and d.dot(direction) < cos(SWING_THRESHOLD):
			return Vector2(total, corner_speed())
		total += leg.length()
		direction = d
		from = waypoints[i]
	return Vector2(total, 0.0)


# The yaw asked for, cut to what the wheels allow at this speed. No speed, no
# turn: the one place the bench's pivoting tank and this vehicle differ.
func _set_yaw(wanted: float) -> void:
	var cap := minf(TURN_RATE, absf(speed) / MIN_TURN_RADIUS)
	yaw_rate = clampf(wanted, -cap, cap) * (1.0 if speed >= 0.0 else -1.0) \
			if absf(speed) > 0.001 else 0.0
	# A reversing vehicle's yaw goes the other way for the same wheel angle, so
	# the wheel angle is what is kept in the sign above, and the steering shown
	# on the front axle follows it.
	var target := atan(vehicle.wheelbase * model_scale * yaw_rate / speed) if absf(speed) > 0.05 else 0.0
	_steer_angle = move_toward(_steer_angle, clampf(target, -0.6, 0.6), 3.0 * get_physics_process_delta_time())


# The free mode's question, the classic mode's rule: Player.update's three
# sensors, SENSOR_X + SPEED ahead of where it is and SENSOR_Y either side,
# turned to the heading rather than to one of eight directions -- on one of
# them they are the game's own -- and behind it when it is reversing, on the
# map's grid.
func _blocked(at: Vector3, direction: float) -> bool:
	var p := Level3DMap.to_map(Vector2(at.x, at.z))
	var f := Vector2(cos(heading), -sin(heading)) * direction
	var side := Vector2(-f.y, f.x) * Player.SENSOR_Y
	var ahead := p + f * (Player.SENSOR_X + Player.SPEED)
	return not (map.is_driveable(ahead.x, ahead.y)
			and map.is_driveable(ahead.x - side.x, ahead.y - side.y)
			and map.is_driveable(ahead.x + side.x, ahead.y + side.y))


# ----------------------------------------------------------------------------
# Body

func _update_pitch(accel_ratio: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var spring: Array = vehicle.pitch
	var target: float = -spring[0] * clampf(accel_ratio, -1.0, 1.0)
	_pitch_velocity += (-spring[1] * (_pitch - target) - spring[2] * _pitch_velocity) * delta
	_pitch += _pitch_velocity * delta


# The body leaning out of a turn: `sideways`, m/s^2, positive turning left,
# rolls it to the right, which is positive.
func _update_roll(sideways: float, delta: float) -> void:
	var spring: Array = vehicle.roll
	if spring[0] == 0.0:
		return
	var target: float = spring[0] * clampf(sideways / ROLL_FULL, -1.0, 1.0)
	_roll_velocity += (-spring[1] * (_roll - target) - spring[2] * _roll_velocity) * delta
	_roll += _roll_velocity * delta


# The rumble's phase and how much of it there is. The
# game's sprite stops wherever its rumble was when the jeep stops, a pixel or
# so off; a hull stopped in the air reads as stuck, so the rumble dies away
# over RUMBLE_FADE instead, and comes up as quickly.
func _update_engine(driving: bool, delta: float) -> void:
	_rumble_level = move_toward(_rumble_level, 1.0 if driving else 0.0, delta / RUMBLE_FADE)
	if _rumble_level > 0.0:
		_rumble = fmod(_rumble + RUMBLE_RATE * delta, TAU)


# The hull's height off its rest: the rumble.
func _rumble_height() -> float:
	return vehicle.rumble * _rumble_level * sin(_rumble)


# Each aerial's spring: its tilt, pitch and roll as the body's, pulled towards
# the hull's -- the body springs' -- and pushed the other way
# by the hull's acceleration, along it and across it. What it is bent by is
# how far its tilt is off the hull's.
func _update_aerials(velocity: Vector3, delta: float) -> void:
	if _aerials.is_empty():
		_velocity = velocity
		return
	var accel := (velocity - _velocity) / delta
	_velocity = velocity
	if accel.length() > AERIAL_ACCEL_MAX:
		accel = accel.normalized() * AERIAL_ACCEL_MAX
	var ahead := forward()
	var left := Vector3(-sin(heading), 0.0, -cos(heading))
	# Speeding up tips it back, nose-up; turning left, to the right.
	var push := Vector2(-accel.dot(ahead), accel.dot(left)) * AERIAL_PUSH
	var hull := _hull_tilt()
	for aerial in _aerials:
		var omega: float = aerial.omega
		var off: Vector2 = aerial.angle - hull
		aerial.rate += (-omega * omega * off - 2.0 * AERIAL_ZETA * omega * aerial.rate + push) * delta
		aerial.angle += aerial.rate * delta


# The hull's pitch and roll off the vehicle's: the springs.
func _hull_tilt() -> Vector2:
	return Vector2(_pitch, _roll)


# The turret's one writer. Aimed: it turns towards the aim point at its own
# rate, holding a world bearing through the hull's turns. Keys: the keys.
# Neither: stowed to the bow while moving, left alone while standing -- the
# bench's UpdateTurret.
func _update_turret(delta: float) -> void:
	var budget := (CLASSIC_TURRET_RATE if classic else TURRET_RATE) * delta
	if turret_input != 0.0:
		turret = wrapf(turret + turret_input * budget, -PI, PI)
		return
	var wanted := turret
	if aim_point != null:
		var to: Vector3 = aim_point - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			wanted = wrapf(atan2(-to.z, to.x) - heading, -PI, PI)
	elif absf(speed) > 0.05:
		wanted = 0.0
	# The bearing is taken against this frame's heading, so an aimed turret
	# holds it through the hull's turns instead of being carried round with it.
	var diff := wrapf(wanted - turret, -PI, PI)
	turret = wrapf(turret + clampf(diff, -budget, budget), -PI, PI)


# Sits the vehicle on the ground under it, tilted to the ground under its ends
# and sides.
func _settle(delta: float, snap: bool) -> void:
	var centre: Dictionary = ground.call(position.x, position.z)
	var target_y: float = centre.height
	position.y = target_y if snap else lerpf(position.y, target_y, clampf(delta * 8.0, 0.0, 1.0))

	var f := forward()
	var left := Vector3(-sin(heading), 0.0, -cos(heading))
	var half: float = vehicle.nose * 0.5 * model_scale
	var side: float = vehicle.half_width * model_scale
	var hf: Dictionary = ground.call(position.x + f.x * half, position.z + f.z * half)
	var hb: Dictionary = ground.call(position.x - f.x * half, position.z - f.z * half)
	var hl: Dictionary = ground.call(position.x + left.x * side, position.z + left.z * side)
	var hr: Dictionary = ground.call(position.x - left.x * side, position.z - left.z * side)
	var pitch := 0.0
	var roll := 0.0
	# Only over a jump it could be a slope, so a wall beside the hull does not
	# tip it over. A ramp over a ruined bunker is a slope however steep.
	var dp: float = hf.height - hb.height
	var dr: float = hl.height - hr.height
	if absf(dp) < (RAMP_TILT_STEP if "ruin" in [hf.kind, hb.kind] else TILT_STEP):
		pitch = atan2(dp, half * 2.0)
	if absf(dr) < (RAMP_TILT_STEP if "ruin" in [hl.kind, hr.kind] else TILT_STEP):
		roll = atan2(dr, side * 2.0)
	# Only the slope is eased, in the hull's own axes; the heading is taken as it
	# is. Eased with it, the hull trailed its heading by an eighth of a second,
	# which a classic 45 degree step turned into a launcher 16 degrees off the
	# way the rocket was fired.
	var target := Basis(Vector3(0, 0, 1), pitch) * Basis(Vector3(1, 0, 0), roll)
	_tilt = target if snap else _tilt.slerp(target, clampf(delta * 8.0, 0.0, 1.0))


# The model's parts, in its own axes (_ahead, _across). Nose down is positive
# pitch, about _across; right side down is positive roll, about _ahead; and a
# wheel rolls forward about _across as the nose goes down.
func _pose() -> void:
	basis = Basis(Vector3.UP, heading) * _tilt
	var hull := _hull_tilt()
	# The rumble is the model's height, and the model is scaled: taken back out.
	var lift := Vector3.UP * _rumble_height() / model_scale
	_hull.transform = Transform3D(Basis(_ahead, hull.y) * Basis(_across, hull.x) * _hull_rest.basis,
			_hull_rest.origin + lift)
	_turret_pivot.transform = Transform3D(Basis(Vector3.UP, turret) * _turret_rest.basis, _turret_rest.origin)
	for i in _wheels.size():
		var rest := _wheel_rest[i]
		var steer_basis := Basis(Vector3.UP, _steer_angle) if _front_wheels[i] else Basis()
		_wheels[i].transform = Transform3D(steer_basis * Basis(_across, -_wheel_spin) * rest.basis, rest.origin)
	# Each link takes its share of the bend, in the hull's axes, which are the
	# model's: the links are parented down the chain to it.
	for aerial in _aerials:
		var bend: Vector2 = aerial.angle - hull
		for k in aerial.links.size():
			var rest: Transform3D = aerial.rests[k]
			var share: float = AERIAL_SHARES[k]
			aerial.links[k].transform = Transform3D(
					Basis(_ahead, bend.y * share) * Basis(_across, bend.x * share) * rest.basis, rest.origin)
