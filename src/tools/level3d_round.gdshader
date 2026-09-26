// A machine-gun round in the 3D preview, the player's and the enemies'
// (Level3DFx.round_node): the game's EnemyBullet sprite, yellow or white,
// drawn as the fire is (level3d_fire.gdshader) -- flat bands with hard edges
// and a black line round them -- rather than as the sprite's pixels, which
// read as a sticker on a cel-shaded stage.
//
// The sprite is a rounded diamond: a white core in a coloured ring in a dark
// rim, the yellow round's rim red and the white one's black. So is this, on a
// quad turned to the camera, as the sprite was: a round a few centimetres
// across has no sides worth seeing, and a ball's bands, seen from anywhere,
// are these rings anyway. The core twinkles, drawn afresh TWINKLES times a
// second at a size of its own for each round, so that a burst glitters.
//
// Over everything, as the sprite was (Level3DGuns.ROUND_PRIORITY): at the
// height a round flies it would go through a ruin or a wall it passes, and
// the height does not decide what it hits. Unshaded: it is fire.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

// How round the diamond is: 1 a diamond, 2 a circle.
const float ROUNDNESS = 1.4;
const float TWINKLES = 20.0;

uniform vec4 core : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 ring : source_color = vec4(1.0, 0.86, 0.12, 1.0);
uniform vec4 rim : source_color = vec4(0.6, 0.06, 0.02, 1.0);
uniform vec4 line : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	// Turned to the camera, at the node's size.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y,
			INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float d = pow(pow(p.x, ROUNDNESS) + pow(p.y, ROUNDNESS), 1.0 / ROUNDNESS);
	if (d > 1.0) {
		discard;
	}
	vec3 own = floor(NODE_POSITION_WORLD * 8.0);
	float glint = fract(sin(dot(own, vec3(12.9898, 78.233, 37.719)) + floor(TIME * TWINKLES) * 7.13) * 43758.5453);
	vec3 colour = line.rgb;
	if (d < 0.3 + glint * 0.1) {
		colour = core.rgb;
	} else if (d < 0.6) {
		colour = ring.rgb;
	} else if (d < 0.84) {
		colour = rim.rgb;
	}
	ALBEDO = colour;
}
