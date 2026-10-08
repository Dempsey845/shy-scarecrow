shader_type sky;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float sunset : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_offset = 0.0;

uniform vec3 day_top : source_color = vec3(0.38, 0.64, 0.78);
uniform vec3 day_horizon : source_color = vec3(0.88, 0.85, 0.71);
uniform vec3 sunset_top : source_color = vec3(0.47, 0.37, 0.59);
uniform vec3 sunset_horizon : source_color = vec3(1.0, 0.57, 0.34);
uniform vec3 night_top : source_color = vec3(0.035, 0.045, 0.11);
uniform vec3 night_horizon : source_color = vec3(0.16, 0.13, 0.25);
uniform vec3 sun_color : source_color = vec3(1.0, 0.87, 0.59);
uniform vec3 moon_color : source_color = vec3(0.77, 0.84, 1.0);
uniform float sun_size : hint_range(0.1, 5.0) = 1.2;
uniform float moon_size : hint_range(0.1, 5.0) = 1.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.75;
uniform float star_brightness : hint_range(0.0, 3.0) = 0.8;

float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(vec3(cell, 0.0)), hash(vec3(cell + vec2(1.0, 0.0), 0.0)), f.x),
        mix(hash(vec3(cell + vec2(0.0, 1.0), 0.0)), hash(vec3(cell + vec2(1.0), 0.0)), f.x), f.y);
}

void sky() {
    vec3 direction = normalize(EYEDIR);
    vec3 sun = normalize(sun_direction);
    float height = pow(clamp(direction.y, 0.0, 1.0), 0.55);
    vec3 top = mix(night_top, day_top, daylight);
    vec3 horizon = mix(night_horizon, day_horizon, daylight);
    top = mix(top, sunset_top, sunset);
    horizon = mix(horizon, sunset_horizon, sunset);
    vec3 color = mix(horizon, top, height);
    float above_horizon = smoothstep(-0.015, 0.025, direction.y);

    vec3 star_grid = direction * 180.0;
    vec3 star_cell = floor(star_grid);
    float star_random = hash(star_cell);
    vec3 star_position = vec3(hash(star_cell + 11.0), hash(star_cell + 27.0), hash(star_cell + 53.0));
    float star = 1.0 - smoothstep(0.035, 0.12, length(fract(star_grid) - star_position));
    star *= step(0.975, star_random) * (1.0 - daylight) * (1.0 - sunset) * above_horizon;
    color += moon_color * star * star_brightness;

    float sun_dot = dot(direction, sun);
    float moon_dot = dot(direction, -sun);
    float sun_radius = radians(sun_size);
    float moon_radius = radians(moon_size);
    float sun_disc = smoothstep(cos(sun_radius * 1.08), cos(sun_radius), sun_dot);
    float moon_disc = smoothstep(cos(moon_radius * 1.08), cos(moon_radius), moon_dot);
    color += sun_color * pow(max(sun_dot, 0.0), 32.0) * 0.22 * above_horizon;
    color = mix(color, sun_color * 2.0, sun_disc * above_horizon);
    color = mix(color, moon_color * 1.2, moon_disc * above_horizon);

    vec2 cloud_uv = direction.xz / max(direction.y + 0.25, 0.05) * 2.0;
    cloud_uv += vec2(cloud_offset, cloud_offset * 0.3);
    float cloud_noise = noise(cloud_uv) * 0.57;
    cloud_noise += noise(cloud_uv * 2.0 + 9.0) * 0.29;
    cloud_noise += noise(cloud_uv * 4.0 + 17.0) * 0.14;
    float clouds = smoothstep(1.0 - cloud_coverage, 1.15 - cloud_coverage, cloud_noise);
    clouds *= smoothstep(0.03, 0.20, direction.y) * cloud_opacity;
    vec3 cloud_color = mix(vec3(0.12, 0.13, 0.22), vec3(0.96, 0.93, 0.83), daylight);
    cloud_color = mix(cloud_color, vec3(1.0, 0.72, 0.53), sunset * 0.7);
    color = mix(color, cloud_color, clouds);
    COLOR = color;
}
