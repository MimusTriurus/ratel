# Dust in the title splash's look as one cloud: puffs handed in as spheres,
# drawn on one quad facing the camera and flowed into one shape by a smooth
# union of their outlines, with one ink line round it (Level3DSplash3D's
# clouds). Drawn one by one, each with its own rim -- as cards or as balls --
# the same puffs were a heap of separate lumps, none of them a cloud.
#
# A port of CelCloud in the tank bench (BlenderMCP/godot,
# scripts/CelCloud.cs), which draws the tanks' track dust so, with two
# changes. Its camera is orthographic and ours is not, so the shader works in
# the camera's tangent plane -- x and y over depth -- where a sphere is a disc
# whatever its distance, and the depth it writes is found back along the
# pixel's own ray. And its light is the model's ramp, which against our sun
# low behind everything would make every cloud one dark shape: ours keeps the
# splash's own two tones (DUST_* in Level3DSplash3D), lit through where the
# cloud is thin and a rim inside the ink where it is against the sun.
#
# On the stage (Level3DWash) it is lit instead, `lit` true: one albedo, the
# ground's dust's (Level3DPuffs.COLOURS), and the blended normal handed to
# the stage's two-tone light, as every material there is (Level3DPreview.
# _toon), so that it is lit as the puffs and the models are under whatever
# preset; it takes no shadows, since the light sees the quad and not the
# cloud. The stage's top view is orthographic, as the bench's camera is:
# there the tangent plane is the view plane itself.
#
# A frame is clear(), add() a puff, then draw(). The puffs' motion is the
# owner's; this knows only where each is this frame, how big, how far it is
# eaten and how old.
class_name Level3DCelCloud
extends RefCounted

# Puffs in one cloud at most -- the shader's arrays: the stage's wash
# (Level3DWash) wants some 90 to be one body.
const POOL := 96

static var _shaders := {}   # lit -> Shader

var _quad: MeshInstance3D
var _paint: ShaderMaterial
var _where := PackedVector4Array()
var _looks := PackedVector4Array()
var _n := 0
var _blend := 0.2


# A cloud under `parent`, its puffs flowing into one within `blend` metres;
# lit by the scene's light rather than painted in tones, `lit`.
func _init(parent: Node3D, blend: float, ink: float, ink_px: float, lit := false) -> void:
	_blend = blend
	_where.resize(POOL)
	_looks.resize(POOL)
	if not _shaders.has(lit):
		var shader := Shader.new()
		shader.code = SHADER.replace("POOL", str(POOL)).replace("HEAD", LIT_HEAD if lit else PAINTED_HEAD)
		_shaders[lit] = shader
	_paint = ShaderMaterial.new()
	_paint.shader = _shaders[lit]
	_paint.set_shader_parameter("blend", blend)
	_paint.set_shader_parameter("ink_width", ink)
	_paint.set_shader_parameter("ink_min_px", ink_px)
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	_quad = MeshInstance3D.new()
	_quad.mesh = card
	_quad.material_override = _paint
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false
	parent.add_child(_quad)


func clear() -> void:
	_n = 0


func hide() -> void:
	_n = 0
	_quad.visible = false


# A puff this frame: its middle in the world, its radius, how far it is eaten
# (0..1), its age as a share of its life and a seed for its lumps. Past POOL
# it is dropped.
func add(at: Vector3, radius: float, erode: float, age: float, seed: float) -> void:
	if _n >= POOL:
		return
	_where[_n] = Vector4(at.x, at.y, at.z, radius)
	_looks[_n] = Vector4(erode, age, seed, 0.0)
	_n += 1


# The paint's tones and the frame's sides (Level3DSplash3D._region), which
# the owner changes as the sun rises and the frame opens.
func paint(body: Color, lit: Color, rim: Color, sides: Vector2) -> void:
	_paint.set_shader_parameter("body", body)
	_paint.set_shader_parameter("lit", lit)
	_paint.set_shader_parameter("rim", rim)
	_paint.set_shader_parameter("sides", sides)


# A lit cloud's albedo and how sharp its light's edge is (Level3DPreview.
# TOON_EDGE).
func tint(albedo: Color, toon_edge: float) -> void:
	_paint.set_shader_parameter("albedo", albedo)
	_paint.set_shader_parameter("toon_edge", toon_edge)


# The ground's height under the cloud: a puff sat low, its middle near the
# ground, is partly under it, and the ground in front of its foot cut the
# cloud off there, ink and all. Where the cloud's depth is under the ground,
# it is put on the ground along the pixel's ray instead. Brought forward by
# the radius everywhere instead, its far side stood in front of the hull.
func set_ground(height: float) -> void:
	_paint.set_shader_parameter("ground_y", height)


# The puffs added since clear(), seen from `camera`; `sun_toward` the way to
# the sun, for how much the cloud is against it.
func draw(camera: Camera3D, sun_toward: Vector3) -> void:
	var ortho := camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var eye := camera.global_transform
	var right := eye.basis.x.normalized()
	var up := eye.basis.y.normalized()
	var back := eye.basis.z.normalized()
	# The puffs in front of the camera, in its tangent plane: a puff behind it
	# has no place in the frame.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var mid := Vector3.ZERO
	var front := INF
	var seen := 0
	for i in _n:
		var at := Vector3(_where[i].x, _where[i].y, _where[i].z)
		var rel := at - eye.origin
		var depth := -rel.dot(back)
		if depth < camera.near * 2.0:
			continue
		# Over its depth in perspective, as it is in the orthographic view.
		var over := 1.0 if ortho else depth
		var reach := (_where[i].w * 1.4 + _blend + 0.1) / over
		var s := Vector2(rel.dot(right), rel.dot(up)) / over
		lo = Vector2(minf(lo.x, s.x - reach), minf(lo.y, s.y - reach))
		hi = Vector2(maxf(hi.x, s.x + reach), maxf(hi.y, s.y + reach))
		mid += at
		front = minf(front, depth - _where[i].w)
		seen += 1
	if seen == 0:
		_quad.visible = false
		return
	mid /= seen
	# Covering every puff's disc and lumps, half way to the nearest of them:
	# its own depth is not used, the shader writes the cloud's. Half a metre
	# from the camera, a step of the camera's after the quad was placed moved
	# the quad's cover a good share of the frame, and the cloud was cut off
	# along its edge; this far, and drawn after the camera has moved
	# (Level3DSplash3D._draw_cel_clouds), it holds.
	var near := maxf(camera.near * 4.0, front * 0.5)
	var centre := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5 * 1.03
	# Orthographic, the plane's size is the same at any depth.
	var spread := 1.0 if ortho else near
	_quad.global_transform = Transform3D(Basis(right * (2.0 * half.x * spread), up * (2.0 * half.y * spread), back),
			eye.origin + (right * centre.x + up * centre.y) * spread - back * near)
	_quad.visible = true
	_paint.set_shader_parameter("puffs", _where)
	_paint.set_shader_parameter("looks", _looks)
	_paint.set_shader_parameter("count", _n)
	_paint.set_shader_parameter("near_cut", camera.near * 2.0)
	_paint.set_shader_parameter("ortho", ortho)
	_paint.set_shader_parameter("mid_depth", 1.0 if ortho else maxf(-(mid - eye.origin).dot(back), near))
	_paint.set_shader_parameter("behind", pow(clampf((mid - eye.origin).normalized().dot(sun_toward.normalized()), 0.0, 1.0), 4.0))


# The cloud: every puff a disc in the camera's tangent plane, and the discs
# flowed into one shape -- a smooth union of their distances, `blend` metres
# wide at the cloud's depth -- with one ink line round it. Each disc's rim is
# made lumpy by a noise in its own frame, so that the lumps go with the puff,
# and it is eaten as it ages from the rim in, as a share of what is left of
# it: holes through the middle, each inked, read as cheese, and bitten as a
# share of the whole, a puff nearly gone was a star. The normal is blended
# from the puffs' spheres with the union's weights, so the cloud has one
# body; the depth is the blended front of the same spheres, found along the
# pixel's ray, so the Chinook still hides what is behind it.
const PAINTED_HEAD := "render_mode unshaded, cull_disabled, shadows_disabled;"
const LIT_HEAD := "#define LIT\nrender_mode diffuse_toon, specular_disabled, cull_disabled, shadows_disabled;"

const SHADER := """
shader_type spatial;
HEAD
uniform vec4 puffs[POOL];
uniform vec4 looks[POOL];
uniform int count = 0;
uniform float blend = 0.2;
uniform float mid_depth = 10.0;
uniform float near_cut = 0.1;
uniform vec3 body : source_color = vec3(0.24, 0.11, 0.07);
uniform vec3 lit : source_color = vec3(0.72, 0.38, 0.16);
uniform vec3 rim : source_color = vec3(1.0, 0.8, 0.45);
uniform vec3 ink_colour : source_color = vec3(0.0);
// How much the cloud is against the sun (Level3DCelCloud.draw).
uniform float behind = 1.0;
// Its foot in shade where its normal turns down more than foot_at; thin
// enough to be lit through where it faces the camera less than thin_at; the
// rim this many ink widths in from the outline.
uniform float foot_at = -0.25;
uniform float thin_at = 0.5;
uniform float rim_inks = 2.5;
uniform float ink_width = 0.03;
uniform float ink_min_px = 1.2;
uniform float side_fade = 0.25;
// Far outside the frame unless painted (the splash's): no fade.
uniform vec2 sides = vec2(-1.0, 2.0);
// The tangent plane is the view plane (Level3DCelCloud.draw).
uniform bool ortho = false;
// Lit, its one colour and its light's edge.
uniform vec3 albedo : source_color = vec3(0.93, 0.76, 0.48);
uniform float toon_edge = 0.02;
// The ground's height (Level3DCelCloud.set_ground): no depth under it.
uniform float ground_y = -1e9;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	// The pixel in the tangent plane: its ray's x and y over its depth --
	// or, orthographic, as they are.
	vec2 p = ortho ? VERTEX.xy : VERTEX.xy / -VERTEX.z;
	float bl = blend / mid_depth;
	// A pixel in the plane, off the plane itself: the projection's own
	// numbers gave a fraction of one, and the ink was a dashed hairline.
	float px = abs(dFdx(p.x));
	float ink = max(ink_width / mid_depth, ink_min_px * px);
	float sd = 1e9;
	float wsum = 0.0;
	float zsum = 0.0;
	vec3 nsum = vec3(0.0);
	for (int i = 0; i < POOL; i++) {
		if (i >= count) break;
		vec3 c = (VIEW_MATRIX * vec4(puffs[i].xyz, 1.0)).xyz;
		if (-c.z < near_cut) continue;
		float over = ortho ? 1.0 : -c.z;
		float r = max(puffs[i].w, 1e-3) / over;
		vec4 lk = looks[i];
		vec2 q = p - c.xy / over;
		float len = length(q);
		vec2 u = q / max(len, 1e-6);
		float bite = noise3(vec3(u * 2.2 + lk.z * 31.0, lk.y * 1.2));
		float left = r * (1.0 - lk.x) * (1.0 + 0.3 * (bite - 0.5));
		// Gone, rather than a dot of ink.
		if (left < 2.0 * ink) continue;
		float bump = noise3(vec3(u * 1.4 + lk.z * 17.0, lk.y * 1.5)) - 0.5;
		float di = len - left * (1.0 + 0.35 * bump);
		// Round in the middle, where the noises of the way round have no way.
		float plain = r * (1.0 - lk.x);
		di = mix(len - plain, di, smoothstep(0.2, 0.7, len / max(plain, 1e-6)));
		float h = sqrt(max(0.0, 1.0 - len * len / (r * r)));
		float w = exp(-clamp(di, -r, 3.0 * bl) / bl);
		nsum += normalize(vec3(q / r, max(h, 0.2))) * w;
		// Its front towards the camera, in view depth.
		zsum += (c.z + puffs[i].w * h) * w;
		wsum += w;
		float k = clamp(0.5 + 0.5 * (di - sd) / bl, 0.0, 1.0);
		sd = mix(di, sd, k) - bl * k * (1.0 - k);
	}
	if (sd > 0.0 || wsum <= 0.0) {
		discard;
	}
	// Dithered out towards the frame's sides, as the puffs are.
	float across = (SCREEN_UV.x - sides.x) / (sides.y - sides.x);
	float side = 1.0 - smoothstep(0.03, side_fade, min(across, 1.0 - across));
	if (1.0 - side < bayer(FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(nsum);
#ifdef LIT
	ALBEDO = sd > -ink ? ink_colour : albedo;
	NORMAL = n;
	ROUGHNESS = toon_edge;
#else
	// Three tones, as the tanks' clouds step one lit top and one shaded
	// foot: the foot darker, the rest half lit, its thin edges lit through.
	// Lit only at the edges, the middle of every cloud was a dark hole; with
	// its foot as dark as the body, every cloud was a rock, shaded as ours are.
	float through = 0.35 + 0.65 * behind;
	vec3 colour = mix(body, lit, 0.55 * through);
	if (n.y < foot_at) {
		colour = mix(body, lit, 0.25 * through);
	} else if (n.z < thin_at) {
		colour = mix(body, lit, through);
	}
	if (sd > -ink * rim_inks && n.y > -0.4) {
		colour = mix(colour, rim, behind);
	}
	if (sd > -ink) {
		colour = ink_colour;
	}
	ALBEDO = colour;
#endif
	// The blended front, along this pixel's ray.
	float z = min(zsum / wsum, -near_cut);
	vec3 front = ortho ? vec3(VERTEX.xy, z) : VERTEX * (z / VERTEX.z);
	// Not under the ground: where the ray goes into it, a hair over it.
	if ((INV_VIEW_MATRIX * vec4(front, 1.0)).y < ground_y + 0.05) {
		vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		vec3 on = (VIEW_MATRIX * vec4(0.0, ground_y + 0.05, 0.0, 1.0)).xyz;
		vec3 from = ortho ? vec3(VERTEX.xy, 0.0) : vec3(0.0);
		vec3 way = ortho ? vec3(0.0, 0.0, -1.0) : VERTEX;
		float t = dot(up, on - from) / dot(up, way);
		if (t > 0.0) {
			front = from + way * t;
		}
	}
	vec4 clip = PROJECTION_MATRIX * vec4(front, 1.0);
	float ndc = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH = ndc * 0.5 + 0.5;
#else
	DEPTH = ndc;
#endif
}
"""
