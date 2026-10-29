shader_type canvas_item;
render_mode unshaded;
// The uploaded fragment sampled TEXTURE on a plain ColorRect. It never read
// the game scene. This production overlay samples the real screen buffer.
uniform sampler2D scene_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform int realm_mode : hint_range(0,2) = 0;
uniform float effect_strength : hint_range(0.0,1.0) = 0.4;
uniform vec2 lantern_screen_uv = vec2(0.5,0.5);
uniform float lantern_radius : hint_range(0.05,1.5) = 0.5;
uniform vec4 lantern_warm_tint : source_color = vec4(1.0,0.82,0.52,1.0);
uniform float sea_fog_density : hint_range(0.0,1.0) = 0.25;
uniform bool mirror_shadow_unlocked = false;
uniform float mirror_sun_angle_deg : hint_range(-60.0,60.0) = 0.0;
uniform float mirror_prismatic_aberration : hint_range(0.0,0.01) = 0.002;
uniform float chronicle_dual_echo_blend : hint_range(0.0,1.0) = 0.5;
uniform float vignette_intensity : hint_range(0.0,1.0) = 0.3;
void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 original = texture(scene_tex,uv);
    vec3 styled = original.rgb;
    if (realm_mode == 0) {
        // Screen-space inverse-square falloff in the present-world lantern.
        float r = max(0.05,lantern_radius);
        float d = distance(uv,lantern_screen_uv)/r;
        float attenuation = 1.0/(1.0+6.5*d*d);
        vec3 unlit = original.rgb*vec3(0.78,0.83,0.93);
        vec3 lit = original.rgb*lantern_warm_tint.rgb*1.30;
        styled = mix(unlit,lit,attenuation);
        float fog = smoothstep(0.28,1.0,uv.y)*sea_fog_density;
        styled = mix(styled,vec3(0.74,0.82,0.88),fog*0.6);
    } else if (realm_mode == 1) {
        vec2 delta = vec2(mirror_prismatic_aberration,0.0);
        vec3 chroma = vec3(texture(scene_tex,clamp(uv+delta,vec2(0.0),vec2(1.0))).r,
            original.g,texture(scene_tex,clamp(uv-delta,vec2(0.0),vec2(1.0))).b);
        styled = chroma*vec3(1.10,1.07,1.02);
        if (mirror_shadow_unlocked) {
            float a = radians(mirror_sun_angle_deg);
            vec2 axis = vec2(sin(a),cos(a));
            float shade = dot(texture(scene_tex,clamp(uv-axis*0.009,vec2(0.0),vec2(1.0))).rgb,
                vec3(0.299,0.587,0.114));
            // A 2D screen-space directional cue, not real-world geometry.
            styled *= 0.94+0.06*shade;
        }
    } else {
        float gray = dot(original.rgb,vec3(0.299,0.587,0.114));
        vec3 monochrome = mix(vec3(gray)*vec3(0.85,0.89,0.97),original.rgb,0.20);
        float phase = TIME*1.3;
        vec2 echo = vec2(sin(phase)*0.005,cos(phase*0.7)*0.003)*
            chronicle_dual_echo_blend;
        vec3 past = texture(scene_tex,clamp(uv+echo,vec2(0.0),vec2(1.0))).rgb;
        vec3 future = texture(scene_tex,clamp(uv-echo,vec2(0.0),vec2(1.0))).rgb;
        styled = mix(monochrome,mix(past*vec3(0.96,0.89,0.82),
            future*vec3(0.77,0.86,0.99),0.5),0.44*chronicle_dual_echo_blend);
    }
    float v = smoothstep(0.18,0.72,distance(uv,vec2(0.5)));
    styled *= 1.0-v*vignette_intensity;
    COLOR = vec4(clamp(mix(original.rgb,styled,effect_strength),0.0,1.0),1.0);
}
