shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.05, 0.03, 0.10, 1.0);

uniform float outline_thickness : hint_range(0.0, 0.1) = 0.02;
instance uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;

uniform int segment_count : hint_range(4, 16) = 8;
uniform float ridge_rotation : hint_range(0.0, 6.283185) = 0.0;
uniform float indentation : hint_range(0.0, 0.15) = 0.045;

void vertex() {
	float radius = length(VERTEX.xz);

	if (radius > 0.0001) {
		float angle = atan(VERTEX.z, VERTEX.x);
		float phase = (angle + ridge_rotation) * float(segment_count);

		float wave = 0.5 + 0.5 * cos(phase);
		float groove = wave * wave * wave;

		float side_mask = 1.0 - smoothstep(
			0.65, 0.98, abs(NORMAL.y)
		);

		VERTEX.xz *= 1.0 - indentation * groove * side_mask;
	}

	VERTEX += NORMAL * outline_thickness * outline_strength;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}