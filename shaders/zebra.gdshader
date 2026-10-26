shader_type canvas_item;

uniform bool zebras_enabled = false;
//uniform float zebra_threshold = 0.95;
uniform float zebra_threshold = 0.98;
uniform bool false_colour_enabled = false;

// White balance is applied to the lights' colours (see main.gd
// update_white_balance), so it is already in the image by the time it gets here.

// Sensor noise (see exposure_controller.gd update_noise). The 3D view arrives
// as linear light (the Environment's tonemapper is Linear) encoded as sRGB, so
// a value s in 0..1 is a fraction of a full pixel. At base ISO a full pixel
// holds `full_well` electrons; ISO is amplification, so at gain g a full pixel
// only took full_well / g electrons of real light. Counting photons is random
// (Poisson), giving a noise of sqrt(electrons), plus a fixed `read_noise` in
// electrons from the readout electronics.
uniform float iso_gain = 1.0;        // ISO / 100
uniform float full_well = 50000.0;   // electrons in a full pixel at base ISO
uniform float read_noise = 3.0;      // electrons, RMS
uniform bool animate_noise = true;   // new noise every frame, like live view
uniform float noise_boost = 1.0;     // >1 exaggerates the noise for teaching ("Exaggerate noise")

// PCG hash: a good-quality integer hash (sin()-based hashes band and repeat on GPUs).
uint pcg(uint v)
{
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

uint hash3(uvec3 v)
{
	return pcg(v.x + pcg(v.y + pcg(v.z)));
}

// Two independent standard-normal numbers from one hash (Box-Muller).
vec2 gaussian2(uint h)
{
	float u1 = (float(pcg(h) >> 8u) + 1.0) / 16777217.0; // (0, 1]
	float u2 = float(pcg(h ^ 0x9E3779B9u) >> 8u) / 16777216.0;
	return sqrt(-2.0 * log(u1)) * vec2(cos(6.2831853 * u2), sin(6.2831853 * u2));
}

vec3 gaussian3(uint h)
{
	return vec3(gaussian2(h), gaussian2(h ^ 0x85EBCA6Bu).x);
}

// Colour noise after demosaicing and in-camera processing is blotchier than
// the brightness noise: a smooth random field with ~3 px cells, interpolated
// between cell corners. Rescaled to keep unit variance.
vec3 chroma_noise(vec2 px, uint frame)
{
	vec2 cell = px / 3.0;
	vec2 i = floor(cell);
	vec2 f = cell - i;
	f = f * f * (3.0 - 2.0 * f);
	uvec2 c = uvec2(ivec2(i) + 4096);
	vec3 a = gaussian3(hash3(uvec3(c, frame * 2u + 1u)));
	vec3 b = gaussian3(hash3(uvec3(c + uvec2(1u, 0u), frame * 2u + 1u)));
	vec3 d = gaussian3(hash3(uvec3(c + uvec2(0u, 1u), frame * 2u + 1u)));
	vec3 e = gaussian3(hash3(uvec3(c + uvec2(1u, 1u), frame * 2u + 1u)));
	vec2 w0 = 1.0 - f;
	float norm = inversesqrt(w0.x * w0.x * w0.y * w0.y + f.x * f.x * w0.y * w0.y + w0.x * w0.x * f.y * f.y + f.x * f.x * f.y * f.y);
	return mix(mix(a, b, f.x), mix(d, e, f.x), f.y) * norm;
}

vec3 srgb_to_linear(vec3 c)
{
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c)
{
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 add_sensor_noise(vec3 srgb, vec2 px)
{
	if (iso_gain <= 0.0) {
		return srgb;
	}
	vec3 s = srgb_to_linear(srgb);
	// Electrons behind a full pixel at this ISO, and the noise in units of a full pixel.
	float electrons_full = full_well / iso_gain;
	vec3 sigma = sqrt(s * electrons_full + read_noise * read_noise) / electrons_full;
	// A clipped pixel is a full well: it has no noise left to show.
	sigma *= 1.0 - step(0.999, s);
	sigma *= noise_boost;

	uint frame = animate_noise ? uint(TIME * 60.0) : 0u;
	uvec2 p = uvec2(ivec2(px) + 4096);
	float luma_n = gaussian2(hash3(uvec3(p, frame * 2u))).x;
	vec3 n = 0.6 * vec3(luma_n) + 0.8 * chroma_noise(px, frame); // 0.6² + 0.8² = 1
	return linear_to_srgb(clamp(s + sigma * n, 0.0, 1.0));
}

void fragment()
{
	vec4 source = texture(TEXTURE, UV);
	vec3 corrected = source.rgb;

	// One noise sample per pixel of the 3D view (a 100% view of the sensor).
	corrected = add_sensor_noise(corrected, UV / TEXTURE_PIXEL_SIZE);

	corrected = clamp(
		corrected,
		vec3(0.0),
		vec3(1.0)
	);


	float lum = dot(
		corrected,
		vec3(0.2126, 0.7152, 0.0722)
	);


	if (false_colour_enabled)
	{
		if (lum < 0.03)
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);      // Black

		else if (lum < 0.10)
			COLOR = vec4(0.4, 0.0, 0.6, 1.0);      // Purple

		else if (lum < 0.25)
			COLOR = vec4(0.0, 0.0, 1.0, 1.0);      // Blue

		else if (lum < 0.45)
			COLOR = vec4(0.0, 1.0, 0.0, 1.0);      // Green

		else if (lum < 0.65)
			COLOR = vec4(1.0, 0.4, 0.7, 1.0);      // Pink

		else if (lum < 0.85)
			COLOR = vec4(1.0, 1.0, 0.0, 1.0);      // Yellow

		else if (lum < 0.98)
			COLOR = vec4(1.0, 0.0, 0.0, 1.0);      // Red

		else if (lum < 0.99)
			COLOR = vec4(1.0, 0.0, 0.0, 1.0);

		else
			COLOR = vec4(1.0, 1.0, 1.0, 1.0); // white
	}
	else if (zebras_enabled && lum > zebra_threshold)
	{
		float stripe = step(
			0.5,
			fract((UV.x + UV.y) * 100.0)
		);

		if (stripe > 0.5)
			COLOR = vec4(1.0, 1.0, 0.0, 1.0);
		else
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else
	{
		// The 3D view is opaque; don't pass the render target's alpha through
		// (the WebGPU build hands it back as 0, which made the monitor invisible).
		COLOR = vec4(
			corrected,
			1.0
		);
	}
}
