shader_type canvas_item;
// C-line subtle moving shimmer on existing reflection sprites. No water-mask writes.
uniform float speed : hint_range(0.0, 2.0) = 0.65;
uniform float glint_strength : hint_range(0.0, 0.2) = 0.065;
void fragment() {
    vec2 ripple_uv = UV;
    ripple_uv.x += sin(UV.y * 18.0 + TIME * speed) * 0.0025;
    vec4 paint = texture(TEXTURE, ripple_uv) * COLOR;
    float highlight = (0.5 + 0.5 * sin(UV.x * 22.0 + UV.y * 9.0 + TIME * speed * 1.6));
    paint.rgb = min(vec3(1.0), paint.rgb + vec3(highlight * glint_strength * paint.a));
    COLOR = paint;
}
