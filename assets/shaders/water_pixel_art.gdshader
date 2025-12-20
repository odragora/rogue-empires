shader_type canvas_item;

// === Color Variation Settings ===
// Controls how much the wave colors deviate from the tile's base color
// 0.0 = no variation (flat color), 1.0 = maximum variation (full range dark to bright)
uniform float color_variation : hint_range(0.0, 1.0) = 0.4;

// === Animation Settings ===
uniform float cycle_speed : hint_range(0.5, 5.0) = 1.5;
uniform float wave_scale : hint_range(2.0, 32.0) = 8.0;
uniform float highlight_chance : hint_range(0.0, 0.3) = 0.08;

// === Pixel Grid Settings ===
uniform float pixel_size : hint_range(1.0, 8.0) = 1.0;

// Simple hash for pseudo-random values
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    // Use screen-space coordinates for consistent waves across all TileMap tiles
    vec2 screen_pos = FRAGCOORD.xy / pixel_size;
    
    // Snap to pixel grid for crisp pixel look
    vec2 pixel_coord = floor(screen_pos / wave_scale);
    
    // Get base texture color
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 base_color = tex_color.rgb;
    
    // === Generate 4-color palette from base texture color ===
    // Create variations: darkest, dark, light, lightest
    // The variation amount is controlled by the color_variation uniform
    float dark_mult = 1.0 - color_variation * 0.6;    // Darkest: reduce brightness
    float mid_dark_mult = 1.0 - color_variation * 0.3; // Dark: slightly reduced
    float mid_light_mult = 1.0 + color_variation * 0.2; // Light: slightly increased
    float light_mult = 1.0 + color_variation * 0.5;    // Lightest: increased brightness
    
    vec3 color_1 = base_color * dark_mult;
    vec3 color_2 = base_color * mid_dark_mult;
    vec3 color_3 = min(base_color * mid_light_mult, vec3(1.0));
    vec3 color_4 = min(base_color * light_mult, vec3(1.0));
    
    // Create wave pattern using stepped/quantized values
    float time = TIME * cycle_speed;
    
    // Diagonal wave pattern (classic look) - using screen coordinates
    float wave_pos = pixel_coord.x + pixel_coord.y * 0.5;
    
    // Calculate which color band this pixel falls into
    float band = floor(mod(wave_pos - time, 4.0));
    
    // Add some noise variation so it's not perfectly uniform
    float noise_offset = floor(hash(pixel_coord) * 2.0);
    band = mod(band + noise_offset, 4.0);
    
    // Select color from dynamically generated palette
    vec3 wave_color;
    if (band < 1.0) {
        wave_color = color_1;
    } else if (band < 2.0) {
        wave_color = color_2;
    } else if (band < 3.0) {
        wave_color = color_3;
    } else {
        wave_color = color_4;
    }
    
    // === Sparkle Highlights ===
    float sparkle_seed = hash(pixel_coord + floor(time * 2.0));
    float sparkle = step(1.0 - highlight_chance, sparkle_seed);
    
    // Make sparkle flicker
    float sparkle_phase = mod(time * 3.0 + hash(pixel_coord) * 6.28, 1.0);
    sparkle *= step(0.7, sparkle_phase);
    
    // Add sparkle as bright highlight
    wave_color = mix(wave_color, min(color_4 * 1.3, vec3(1.0)), sparkle);
    
    // Preserve original alpha (masks non-hexagonal parts)
    COLOR = vec4(wave_color, tex_color.a);
}
