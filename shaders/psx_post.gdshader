shader_type canvas_item;
// Ashen Crown — PSX пост-процесинг: пікселізація, дизеринг Байєра,
// квантування кольору, зерно та віньєтка. Застосовується до 3D-кадру
// (CanvasLayer нижче за HUD), тому інтерфейс залишається чітким.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;
uniform float color_levels = 32.0;      // 32 = 15-бітний колір PS1
uniform float dither_strength = 1.0;
uniform float grain_strength = 0.03;
uniform float vignette_strength = 0.42;
uniform float saturation = 0.88;
uniform float contrast = 1.06;
uniform vec3 shadow_tint : source_color = vec3(0.10, 0.08, 0.16);

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float bayer4(vec2 cell) {
	ivec2 i = ivec2(mod(cell, 4.0));
	return BAYER4[i.y * 4 + i.x] / 16.0;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float ps = max(pixel_size, 1.0);
	vec2 cell = floor(FRAGCOORD.xy / ps);
	vec2 uv = min((cell + 0.5) * ps, screen_size - 0.5) / screen_size;
	vec3 c = texture(screen_tex, uv).rgb;

	// Похмуре грейдування: менше насиченості, фіолетовий відтінок у тінях.
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c += shadow_tint * (1.0 - smoothstep(0.0, 0.35, luma)) * 0.12;

	vec2 q = (cell + 0.5) * ps / screen_size - 0.5;
	c *= 1.0 - dot(q, q) * vignette_strength * 1.6;

	float grain = hash12(cell + floor(TIME * 18.0) * vec2(37.0, 17.0)) - 0.5;
	c += grain * grain_strength;

	float levels = max(color_levels, 2.0) - 1.0;
	float d = (bayer4(cell) - 0.5) * dither_strength;
	c = floor(clamp(c, 0.0, 1.0) * levels + 0.5 + d) / levels;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
