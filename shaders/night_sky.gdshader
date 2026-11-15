shader_type sky;
// Ashen Crown — драматичне нічне/сутінкове небо: великий місяць з ореолом,
// шари хмар, що повільно пливуть, мерехтливі зорі. Параметри задає цикл доби.

uniform vec3 zenith_color : source_color = vec3(0.02, 0.025, 0.06);
uniform vec3 horizon_color : source_color = vec3(0.12, 0.11, 0.2);
uniform vec3 ground_color : source_color = vec3(0.02, 0.02, 0.035);
uniform vec3 moon_dir = vec3(-0.45, 0.3, -0.84);
uniform vec3 moon_color : source_color = vec3(0.92, 0.9, 0.82);
uniform float moon_size = 0.085;
uniform float moon_visibility = 1.0;
uniform vec3 halo_color : source_color = vec3(0.42, 0.46, 0.7);
uniform float star_intensity = 1.0;
uniform vec3 cloud_color : source_color = vec3(0.09, 0.08, 0.14);
uniform vec3 cloud_lit_color : source_color = vec3(0.55, 0.58, 0.75);
uniform float cloud_coverage = 0.55;
uniform float cloud_speed = 0.006;
uniform float sky_energy = 1.0;
// Фінальний світанок: диск сонця, ореол і промені (sun_amount = 0 — вимкнено).
uniform vec3 sun_dir = vec3(-0.6, 0.1, -0.78);
uniform float sun_amount = 0.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.8, 0.5);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += vnoise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.2, -h));
	} else {
		col = mix(horizon_color, zenith_color, pow(smoothstep(0.0, 0.65, h), 0.65));
	}

	vec3 md = normalize(moon_dir);
	float cos_angle = dot(dir, md);
	float angle = acos(clamp(cos_angle, -1.0, 1.0));
	float halo = exp(-(angle * angle) / (moon_size * moon_size * 10.0)) * 0.5 + exp(-angle * 2.6) * 0.16;
	col += halo_color * halo * moon_visibility;

	vec3 sun_d = normalize(sun_dir);
	float sun_cos = dot(dir, sun_d);
	float sun_ang = acos(clamp(sun_cos, -1.0, 1.0));
	float sun_glow = exp(-sun_ang * 3.0) * 0.55 + exp(-sun_ang * 13.0) * 0.95;
	col += sun_color * sun_glow * sun_amount;

	if (AT_CUBEMAP_PASS) {
		// Дешевий прохід для освітлення/відбиттів: без зірок і детальних хмар.
		COLOR = col * sky_energy;
	} else {
		if (h > 0.0) {
			vec3 sd = dir * 260.0;
			vec3 cell = floor(sd);
			float r = hash13(cell);
			float star = step(0.9978, r) * smoothstep(0.55, 0.05, length(fract(sd) - 0.5));
			star *= 0.55 + 0.45 * sin(TIME * (1.5 + r * 3.0) + r * 90.0);
			col += vec3(0.85, 0.88, 1.0) * star * star_intensity * smoothstep(0.03, 0.3, h);
		}

		vec3 right = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
		vec3 up = cross(right, md);
		vec2 mp = vec2(dot(dir, right), dot(dir, up)) / moon_size;
		float disc = (1.0 - smoothstep(0.96, 1.0, length(mp))) * step(0.0, cos_angle);
		float maria = fbm(mp * 2.2 + 7.0, 4);
		vec3 moon = moon_color * (0.62 + smoothstep(0.35, 0.7, maria) * 0.45) * (1.08 - 0.3 * dot(mp, mp));

		float cloud_alpha = 0.0;
		vec3 cloud = cloud_color;
		if (h > -0.03) {
			vec2 cuv = dir.xz / (h + 0.14) * 0.85;
			cuv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
			float n = fbm(cuv * 1.4, 5);
			float n2 = fbm(cuv * 0.6 - vec2(TIME * cloud_speed * 0.5, 0.0), 3);
			float density = n * 0.75 + n2 * 0.45;
			cloud_alpha = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.22, density);
			cloud_alpha *= smoothstep(-0.03, 0.1, h);
			// Хмари поруч із місяцем підсвічені сріблом, краї — яскравіші.
			float lit = pow(max(cos_angle, 0.0), 10.0) * moon_visibility;
			float rim = smoothstep(0.0, 0.5, cloud_alpha) * (1.0 - smoothstep(0.5, 1.0, cloud_alpha));
			cloud = mix(cloud_color, cloud_lit_color, clamp(lit * (0.6 + rim * 1.4), 0.0, 1.0));
			cloud *= 0.75 + n * 0.5;
			float sun_lit = pow(max(sun_cos, 0.0), 6.0) * sun_amount;
			cloud = mix(cloud, sun_color * 1.25, clamp(sun_lit * (0.45 + rim * 1.6), 0.0, 1.0));
		}
		col += moon * disc * moon_visibility * (1.0 - cloud_alpha * 0.85);
		col = mix(col, cloud, cloud_alpha * 0.94);
		if (sun_amount > 0.001 && sun_cos > 0.0) {
			vec3 sright = normalize(cross(sun_d, vec3(0.0, 1.0, 0.0)));
			vec3 sup = cross(sright, sun_d);
			vec2 sp = vec2(dot(dir, sright), dot(dir, sup));
			float sa = atan(sp.y, sp.x);
			float rays = pow(max(0.0, sin(sa * 9.0 + sin(sa * 3.0) * 1.5 + TIME * 0.04)), 8.0) * 0.55;
			rays += pow(max(0.0, sin(sa * 23.0 + 1.3 + TIME * 0.02)), 10.0) * 0.3;
			rays *= exp(-sun_ang * 2.0) * smoothstep(0.02, 0.14, sun_ang);
			float disc_s = (1.0 - smoothstep(0.036, 0.05, sun_ang)) * 6.0;
			col += sun_color * (rays * 0.75 + disc_s) * sun_amount * (1.0 - cloud_alpha * 0.55);
		}
		COLOR = col * sky_energy;
	}
}
