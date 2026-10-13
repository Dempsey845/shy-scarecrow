shader_type spatial;
render_mode cull_disabled;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;

uniform float bottom_y = -1.0;
uniform float top_y = 1.0;
uniform float bottom_radius = 0.3;
uniform float top_radius = 0.5;

uniform vec4 chocolate_color : source_color =
    vec4(0.20, 0.075, 0.025, 1.0);

void vertex() {
    float fill = clamp(fill_amount, 0.0, 1.0);
    float height = max(top_y - bottom_y, 0.0001);

    float original_fraction = clamp(
        (VERTEX.y - bottom_y) / height, 0.0, 1.0
    );
    float filled_fraction = original_fraction * fill;

    float original_radius = mix(
        bottom_radius, top_radius, original_fraction
    );
    float new_radius = mix(
        bottom_radius, top_radius, filled_fraction
    );

    VERTEX.xz *= new_radius / max(original_radius, 0.0001);
    VERTEX.y = bottom_y + filled_fraction * height;

    if (abs(NORMAL.y) < 0.999) {
        float slope = (top_radius - bottom_radius) / height;
        NORMAL = normalize(vec3(normalize(NORMAL.xz).x,
                                -slope,
                                normalize(NORMAL.xz).y));
    }
}

void fragment() {
    if (fill_amount <= 0.0) {
        discard;
    }

    ALBEDO = chocolate_color.rgb;
    ROUGHNESS = 0.35;
}