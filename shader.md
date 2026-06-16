// ============================================================================
//  Simple Ramp Toon Shader  -  Godot 4.x
// ----------------------------------------------------------------------------
//  - Banding (the toon look) comes from a ramp texture sampled by surface angle.
//  - Works for DirectionalLight3D and OmniLight3D / SpotLight3D.
//  - No grainy shadows: ATTENUATION is used as a SMOOTH multiply, never stepped.
//    (Stepping the dithered shadow penumbra is what produces grain, and stepping
//     an omni's distance falloff is what produces the hard "cutoff ring".)
// ============================================================================

shader_type spatial;
// Default lighting models below are unused since we override light(),
// but keeping cull_back explicit is handy. Remove render_mode entirely if you like.
render_mode cull_back;

// --- Base color -------------------------------------------------------------
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;

// --- Ramp -------------------------------------------------------------------
// Paint a 1-row gradient: LEFT = shadow/dark side, RIGHT = fully lit.
// IMPORTANT: in the texture import settings set Repeat = Disabled, or the
// ramp's left/right edges will bleed and cause artifacts at the terminator.
//   filter_nearest -> crisp hard bands (classic cel look)
//   filter_linear  -> soft gradient bands
uniform sampler2D ramp : repeat_disable, filter_nearest;

// --- Shadow / attenuation ---------------------------------------------------
// 0.0 = use attenuation raw (softest, zero grain, full omni falloff).
// Raising this lightly crisps the shadow edge. Keep it modest, especially if
// you rely on OmniLight distance falloff (a very small value crushes falloff).
uniform float shadow_crispness : hint_range(0.0, 1.0) = 0.0;

// --- Optional banded specular ----------------------------------------------
uniform bool use_specular = false;
uniform float specular_size : hint_range(1.0, 256.0) = 32.0;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec3 specular_color : source_color = vec3(1.0);

// --- Optional rim light -----------------------------------------------------
uniform bool use_rim = false;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.6;
uniform vec3 rim_color : source_color = vec3(1.0);


void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
}


void light() {
	// ----- Toon banding from SURFACE ANGLE only -----------------------------
	// This is smooth across the screen, so banding it is clean (no grain).
	float n_dot_l = dot(NORMAL, LIGHT);
	// Half-Lambert wrap: maps [-1, 1] -> [0, 1] for a softer terminator.
	// (For a harder terminator use: float t = clamp(n_dot_l, 0.0, 1.0);)
	float t = n_dot_l * 0.5 + 0.5;

	vec3 banded = texture(ramp, vec2(t, 0.5)).rgb;

	// ----- Light visibility: SMOOTH, never stepped --------------------------
	// ATTENUATION (float in Godot 4) already bundles shadow + distance falloff.
	// Keeping it continuous is the whole trick: the shadow penumbra stays soft
	// instead of turning the dither into grain, and omni lights still fade with
	// distance instead of cutting off in a hard ring.
	float visibility = ATTENUATION;
	if (shadow_crispness > 0.0) {
		// Optional, mild sharpening that is still continuous (no hard edge).
		visibility = smoothstep(0.0, 1.0 - shadow_crispness, ATTENUATION);
	}

	DIFFUSE_LIGHT += banded * visibility * ALBEDO * LIGHT_COLOR;

	// ----- Optional banded specular ----------------------------------------
	// NdotH is smooth in screen space, so stepping it is safe (no grain).
	if (use_specular) {
		vec3 half_vec = normalize(VIEW + LIGHT);
		float n_dot_h = max(dot(NORMAL, half_vec), 0.0);
		float spec = pow(n_dot_h, specular_size);
		spec = step(specular_threshold, spec);
		SPECULAR_LIGHT += spec * specular_color * LIGHT_COLOR * visibility;
	}

	// ----- Optional rim light ----------------------------------------------
	// Gated by the lit side and by visibility so it respects shadows.
	if (use_rim) {
		float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
		rim = step(rim_threshold, rim);
		DIFFUSE_LIGHT += rim * rim_color * LIGHT_COLOR * visibility * clamp(t, 0.0, 1.0);
	}
}