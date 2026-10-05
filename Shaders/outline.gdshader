shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.05, 0.03, 0.10, 1.0);
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.02;
instance uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX += NORMAL * outline_thickness * outline_strength;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}