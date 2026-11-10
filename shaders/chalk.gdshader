shader_type canvas_item;

// Chalk on a board. The stroke breaks up where the chalk skipped, and the
// pressure is uneven, so a letter is never one flat colour.
uniform float grit : hint_range(0.0, 0.6) = 0.16;
uniform float press : hint_range(0.0, 1.0) = 0.3;
uniform float cell = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 g = floor(FRAGCOORD.xy / cell);
	float gap = step(grit, hash(g));
	float weight = mix(1.0 - press, 1.0, hash(g + vec2(31.0, 17.0)));
	COLOR.a *= gap * weight;
}
