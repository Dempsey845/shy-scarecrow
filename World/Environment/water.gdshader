shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep_color : source_color = vec4(0.045, 0.23, 0.25, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.19, 0.43, 0.40, 1.0);
uniform vec4 foam_color : source_color = vec4(0.73, 0.83, 0.72, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.45;
uniform float ripple_strength : hint_range(0.0, 0.3) = 0.065;
uniform float foam_width : hint_range(0.01, 0.15) = 0.045;
varying vec3 world_pos;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 float t = TIME * flow_speed;
 float a = world_pos.z * 3.8 + world_pos.x * 1.7 - t * 3.2;
 float b = world_pos.z * 7.6 - world_pos.x * 2.4 - t * 5.1;
 float wave = sin(a) * 0.65 + sin(b) * 0.35;
 float edge = min(UV.x, 1.0 - UV.x);
 float shore = 1.0 - smoothstep(0.0, 0.22, edge);
 float noise = sin(world_pos.z * 6.0 - t * 2.0) * sin(world_pos.x * 8.0 + t);
 float foam = 1.0 - smoothstep(foam_width * 0.3, foam_width * (1.0 + 0.25 * noise), edge);
 float streak = smoothstep(0.83, 1.0, wave) * (0.5 + 0.5 * sin(world_pos.x * 3.0 + t));
 vec3 color = mix(deep_color.rgb, shallow_color.rgb, clamp(shore * 0.7 + wave * 0.12 + 0.18, 0.0, 1.0));
 ALBEDO = mix(color, foam_color.rgb, clamp(foam * 0.8 + streak * 0.22, 0.0, 1.0));
 vec3 n = normalize(vec3(-(cos(a)*1.7*0.65-cos(b)*2.4*0.35)*ripple_strength, 1.0, -(cos(a)*3.8*0.65+cos(b)*7.6*0.35)*ripple_strength));
 NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
 ROUGHNESS = mix(0.23, 0.75, foam);
 SPECULAR = 0.6;
 METALLIC = 0.0;
}
