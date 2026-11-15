// Ashen Crown — спільні функції PSX-рендеру.
// Глобальні параметри задає RetroFX (scripts/psx/retro_fx.gd).
global uniform vec2 psx_snap_resolution;
global uniform float psx_snap_enabled;

// Прив'язує вершину до грубої екранної сітки — класичне «тремтіння» PS1.
vec4 psx_snap(vec4 clip) {
	if (psx_snap_enabled < 0.5 || clip.w <= 0.0001) {
		return clip;
	}
	vec2 grid = max(psx_snap_resolution, vec2(16.0)) * 0.5;
	vec2 ndc = clip.xy / clip.w;
	ndc = floor(ndc * grid + 0.5) / grid;
	return vec4(ndc * clip.w, clip.zw);
}

// Вибір домінантної осі без змішування: чіткі «пікселі» на кожній грані.
vec2 psx_planar_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	} else if (a.x >= a.z) {
		return p.zy;
	}
	return p.xy;
}
