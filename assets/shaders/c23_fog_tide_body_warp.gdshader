shader_type canvas_item;
// C2.3 first-act B03 source-preserving body deformation.
// This is procedural deformation of the 768px master, NOT repainted full-body frames.
uniform float elapsed_time = 0.0;
uniform float idle_weight : hint_range(0.0, 1.0) = 1.0;
uniform float charge_weight : hint_range(0.0, 1.0) = 0.0;
uniform float attack_weight : hint_range(0.0, 1.0) = 0.0;
uniform float hit_weight : hint_range(0.0, 1.0) = 0.0;
uniform float defeat_weight : hint_range(0.0, 1.0) = 0.0;
uniform float phase_weight : hint_range(0.0, 1.0) = 0.0;
uniform float reduced_motion : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 uv = UV;
    float safe_motion = 1.0 - reduced_motion;
    float upper = 1.0 - smoothstep(0.15, 0.91, uv.y);
    float edge = smoothstep(0.0, 0.07, uv.x) * (1.0 - smoothstep(0.93, 1.0, uv.x));
    float breath = sin(elapsed_time * 2.7 + uv.y * 4.8) * 0.0065 * idle_weight;
    float water = sin(elapsed_time * 6.0 + uv.y * 11.5) * 0.012 * phase_weight;
    float recoil = hit_weight * sin(uv.y * 10.0 + elapsed_time * 25.0) * 0.009;
    float surge = attack_weight * (1.0 - smoothstep(0.25, 0.95, uv.y));
    uv.x -= safe_motion * (upper * edge * (breath + water + recoil) + surge * 0.016);
    uv.y += safe_motion * (charge_weight * 0.007 * upper - surge * 0.013 * upper);
    uv.y -= safe_motion * defeat_weight * 0.014;
    vec2 inner_uv = clamp(uv, vec2(0.001), vec2(0.999));
    vec4 tex = texture(TEXTURE, inner_uv);
    tex.rgb = mix(tex.rgb, vec3(0.91, 0.63, 0.73), 0.23 * hit_weight);
    tex.rgb = mix(tex.rgb, vec3(0.68, 0.77, 0.96), 0.11 * phase_weight);
    tex.a *= 1.0 - 0.90 * defeat_weight;
    COLOR = tex * COLOR;
}
