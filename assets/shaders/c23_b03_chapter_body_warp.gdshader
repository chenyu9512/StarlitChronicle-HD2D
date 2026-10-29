shader_type canvas_item;
// Real B03 PNG body is sampled unchanged except subtle pose-responsive UV warp.
// The animation images are separately authored scene overlays, not full-body frames.
uniform int chapter_style = 3;
uniform float elapsed_time = 0.0;
uniform float idle_weight : hint_range(0.0,1.0) = 1.0;
uniform float charge_weight : hint_range(0.0,1.0) = 0.0;
uniform float attack_weight : hint_range(0.0,1.0) = 0.0;
uniform float hit_weight : hint_range(0.0,1.0) = 0.0;
uniform float defeat_weight : hint_range(0.0,1.0) = 0.0;
uniform float phase_weight : hint_range(0.0,1.0) = 0.0;
uniform float reduced_motion : hint_range(0.0,1.0) = 0.0;
void fragment() {
    vec2 uv = UV;
    float motion = 1.0 - reduced_motion;
    float upper = 1.0 - smoothstep(0.17,0.87,uv.y);
    float feather = smoothstep(0.01,0.09,uv.x)*(1.0-smoothstep(0.91,0.99,uv.x));
    float breath = sin(elapsed_time*2.15 + uv.y*4.7) * 0.0038*idle_weight;
    float recoil = sin(uv.y*13.0+elapsed_time*22.0)*0.007*hit_weight;
    float charge = charge_weight*upper;
    float strike = attack_weight*upper;
    if (chapter_style == 3) {
        // Rigid ancient guardian: small armor-limb sway and barrier recoil.
        uv.x -= motion*feather*(breath*0.48+recoil*0.65+strike*0.010);
        uv.y -= motion*(charge*0.005+strike*0.008);
    } else if (chapter_style == 4) {
        // Sailor: diagonal lunge rather than vertical squash.
        uv.x -= motion*feather*(breath+recoil+strike*(0.010+uv.y*0.008));
        uv.y -= motion*(strike*0.006+charge*0.004)*(0.9-uv.x*0.4);
    } else if (chapter_style == 5) {
        // Chained ancient beast: weight settles. Defeat means RELEASE, not death.
        uv.x += motion*feather*(breath*0.5+recoil*0.8-strike*0.007);
        uv.y += motion*(charge*0.003-strike*0.006+recoil*0.005);
    } else {
        // Gatekeeper: harmonic water movement around a stable central face.
        float wave = sin(elapsed_time*3.7+uv.y*15.0)*0.006;
        uv.x -= motion*feather*(breath+wave*(0.2+phase_weight)+recoil+strike*0.009);
        uv.y -= motion*(charge*0.004+strike*0.005);
    }
    vec4 character = texture(TEXTURE,clamp(uv,vec2(0.001),vec2(0.999)));
    float hit_tint = hit_weight*0.18;
    character.rgb = mix(character.rgb,vec3(0.91,0.65,0.62),hit_tint);
    float release_opacity = (chapter_style == 5) ? 0.0 : (chapter_style == 3 ? 0.62 : 0.85);
    character.a *= 1.0 - defeat_weight * release_opacity;
    COLOR = character;
}
