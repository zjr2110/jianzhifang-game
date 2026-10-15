shader_type canvas_item;
// 剪纸坊
// spotlight.gdshader - 教学聚光圈
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 hole = vec4(0.0);
uniform float radius = 24.0;
uniform float dim = 0.55;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	float a = dim;
	if (hole.z > 1.0 && hole.w > 1.0) {
		vec2 c = hole.xy + hole.zw * 0.5;
		float r = min(radius, min(hole.z, hole.w) * 0.5);
		float d = sd_round_box(p - c, hole.zw * 0.5, r);
		a = dim * smoothstep(-1.0, 6.0, d);
	}
	COLOR = vec4(0.08, 0.06, 0.04, a);
}
