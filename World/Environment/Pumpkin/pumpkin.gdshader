shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 skin_color : source_color = vec3(0.839216, 0.462745, 0.329412);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.701961, 0.474510);
uniform vec3 groove_color : source_color = vec3(0.592157, 0.254902, 0.2);

uniform vec3 stem_socket_color : source_color = vec3(0.20, 0.09, 0.055);
uniform float stem_socket_radius : hint_range(0.01, 1.0) = 0.22;
uniform float stem_socket_softness : hint_range(0.001, 0.2) = 0.04;
uniform float stem_socket_height : hint_range(-2.0, 2.0) = 0.42;
uniform float stem_socket_height_fade : hint_range(0.001, 0.5) = 0.12;

uniform int segment_count : hint_range(4, 16) = 8;
uniform float ridge_rotation : hint_range(0.0, 6.283185) = 0.0;

uniform float indentation : hint_range(0.0, 0.15) = 0.045;

uniform float ridge_strength : hint_range(0.0, 1.0) = 0.65;
uniform float groove_darkness : hint_range(0.0, 1.0) = 0.55;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.25;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.8;

varying vec3 pumpkin_position;
varying vec3 pumpkin_normal;
varying mat3 local_to_view;

void vertex() {
	// Preserve original coordinates for consistent ridge placement.
	pumpkin_position = VERTEX;
	pumpkin_normal = NORMAL;

	local_to_view = MODELVIEW_NORMAL_MATRIX;
	
	float radius = length(VERTEX.xz);

	if (radius > 0.0001) {
		float angle = atan(VERTEX.z, VERTEX.x);
		float phase = (angle + ridge_rotation) * float(segment_count);

		// Narrow rounded grooves between broad segments.
		float wave = 0.5 + 0.5 * cos(phase);
		float groove = wave * wave * wave;

		// Fade deformation on upward/downward-facing surfaces.
		float side_mask = 1.0 - smoothstep(
			0.65, 0.98, abs(NORMAL.y)
		);

		VERTEX.xz *= 1.0 - indentation * groove * side_mask;
	}
}

void fragment() {
	vec3 base_normal = normalize(pumpkin_normal);
	float radius = length(pumpkin_position.xz);

	float groove = 0.0;
	float crest = 0.0;
	vec3 shaped_normal = base_normal;

	if (radius > 0.0001) {
		float angle = atan(
			pumpkin_position.z,
			pumpkin_position.x
		);

		float phase = (angle + ridge_rotation)
			* float(segment_count);

		float wave = 0.5 + 0.5 * cos(phase);

		float side_mask = 1.0 - smoothstep(
			0.65, 0.98, abs(base_normal.y)
		);

		groove = wave * wave * wave * side_mask;
		crest = (1.0 - wave) * side_mask;

		// Direction around the pumpkin's circumference.
		vec3 around = vec3(
			-pumpkin_position.z / radius,
			0.0,
			pumpkin_position.x / radius
		);

		// Slope of the groove profile creates rounded lighting depth.
		float slope = 1.5 * indentation
			* float(segment_count)
			* wave * wave * sin(phase);

		// Keep the adjustment tangent to the original surface.
		vec3 surface_tangent = around
			- base_normal * dot(around, base_normal);

		shaped_normal = normalize(
			base_normal
			- surface_tangent * slope
			* ridge_strength * side_mask
		);
	}

	vec3 color = mix(
		skin_color,
		highlight_color,
		crest * highlight_strength
	);

	color = mix(
		color,
		groove_color,
		groove * groove_darkness
	);

	float stem_distance = length(pumpkin_position.xz);

	float stem_circle = 1.0 - smoothstep(
		stem_socket_radius,
		stem_socket_radius + stem_socket_softness,
		stem_distance
	);

	float top_mask = smoothstep(
		stem_socket_height - stem_socket_height_fade,
		stem_socket_height,
		pumpkin_position.y
	);

	float stem_socket = stem_circle * top_mask;

	color = mix(
		color,
		stem_socket_color,
		stem_socket
	);

	ALBEDO = color;
	NORMAL = normalize(local_to_view * shaped_normal);

	ROUGHNESS = surface_roughness;
	METALLIC = 0.0;
	SPECULAR = 0.25;
}