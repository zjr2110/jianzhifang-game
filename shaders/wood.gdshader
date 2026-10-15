shader_type canvas_item;
// 剪纸坊
// wood.gdshader - 桌面木纹背景

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform float plank_width = 210.0;
uniform vec3 c_dark = vec3(0.70, 0.56, 0.41);
uniform vec3 c_mid = vec3(0.84, 0.73, 0.59);
uniform vec3 c_light = vec3(0.92, 0.84, 0.72);
uniform float grain = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * rect_size;
	float plank = floor(p.x / plank_width);
	float lx = p.x - plank * plank_width;
	float pr = hash(vec2(plank, 4.2));

	float warp = fbm(vec2(p.x * 0.005 + plank * 3.1, p.y * 0.001 + pr * 7.0)) * 20.0;
	float rings = 0.5 + 0.5 * sin(p.x * 0.05 + warp + plank * 11.0);
	rings = pow(rings, 2.0);
	float fiber = noise(vec2(p.x * 0.5, p.y * 0.01 + plank * 13.0));

	vec3 col = mix(c_mid, c_dark, rings * 0.55 * grain);
	col = mix(col, c_light, smoothstep(0.5, 1.0, fiber) * 0.4 * grain);
	col *= 0.95 + 0.08 * pr;

	// 板缝
	float seam = smoothstep(0.0, 3.0, lx) * smoothstep(0.0, 3.0, plank_width - lx);
	col *= mix(0.78, 1.0, seam);

	// 顶光与暗角
	vec2 c = UV - vec2(0.5, 0.36);
	col *= 1.06 - dot(c, c) * 0.7;
	col = mix(col, c_light * 1.04, 0.12 * (1.0 - UV.y));

	COLOR = vec4(col, 1.0);
}
