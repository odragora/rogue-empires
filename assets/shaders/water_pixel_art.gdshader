shader_type canvas_item;

// === Color Variation Settings ===
// Controls how much the wave colors deviate from the tile's base color
// 0.0 = no variation (flat color), 1.0 = maximum variation (full range dark to bright)
uniform float color_variation : hint_range(0.0, 1.0) = 0.4;

// === Wave Animation Settings ===
uniform float wave_speed : hint_range(0.01, 5.0) = 1.5;
uniform float wave_scale : hint_range(2.0, 32.0) = 8.0;

// === Texture Scrolling (for tiles with drawn waves) ===
uniform bool scroll_texture = false;
uniform float texture_scroll_speed : hint_range(0.01, 2.0) = 0.1;

// === Highlight Settings ===
uniform float highlight_speed : hint_range(0.5, 5.0) = 2.0;
uniform float highlight_chance : hint_range(0.0, 1.0) = 0.15;
uniform float highlight_duration : hint_range(0.1, 0.9) = 0.3;

// === Pixel Grid Settings ===
uniform float pixel_size : hint_range(1.0, 8.0) = 1.0;

// Hash functions for pseudo-random values
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Second hash with different constants for independent randomness
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void fragment() {
    // Use screen-space coordinates for consistent waves across all TileMap tiles
    vec2 screen_pos = FRAGCOORD.xy / pixel_size;
    
    // Snap to pixel grid for crisp pixel look
    vec2 pixel_coord = floor(screen_pos / wave_scale);
    
    // Get base texture color
    // Optionally scroll the texture diagonally (toward bottom-right visually)
    vec2 sample_uv = UV;
    if (scroll_texture) {
        float scroll_time = TIME * texture_scroll_speed;
        
        // Convert UV to local tile coordinates (0-1 within tile region)
        // REGION_RECT.xy = atlas origin, REGION_RECT.zw = tile size in atlas
        vec2 local_uv = (UV - REGION_RECT.xy) / REGION_RECT.zw;
        
        // Scroll diagonally and wrap within the tile
        // Negative = content moves toward bottom-right visually
        vec2 scroll_offset = vec2(-scroll_time, -scroll_time) * 0.1;
        vec2 scrolled_local_uv = fract(local_uv + scroll_offset);
        
        // Add small inset to avoid sampling at exact tile boundaries
        // This prevents edge bleeding from adjacent atlas tiles
        vec2 padding = TEXTURE_PIXEL_SIZE * 0.5;
        vec2 region_min = REGION_RECT.xy + padding;
        vec2 region_max = REGION_RECT.xy + REGION_RECT.zw - padding;
        vec2 region_size = region_max - region_min;
        
        // Convert back to atlas UV space with padding
        sample_uv = scrolled_local_uv * region_size + region_min;
    }
    vec4 tex_color = texture(TEXTURE, sample_uv);
    vec3 base_color = tex_color.rgb;
    
    // Keep original alpha from non-scrolled UV to preserve hex mask
    float original_alpha = texture(TEXTURE, UV).a;
    
    // === Generate 4-color palette from base texture color ===
    float dark_mult = 1.0 - color_variation * 0.6;
    float mid_dark_mult = 1.0 - color_variation * 0.3;
    float mid_light_mult = 1.0 + color_variation * 0.2;
    float light_mult = 1.0 + color_variation * 0.5;
    
    vec3 color_1 = base_color * dark_mult;
    vec3 color_2 = base_color * mid_dark_mult;
    vec3 color_3 = min(base_color * mid_light_mult, vec3(1.0));
    vec3 color_4 = min(base_color * light_mult, vec3(1.0));
    
    // === Wave Animation (uses wave_speed) ===
    float wave_time = TIME * wave_speed;
    
    // Diagonal wave pattern - using screen coordinates
    float wave_pos = pixel_coord.x + pixel_coord.y * 0.5;
    
    // Calculate which color band this pixel falls into
    float band = floor(mod(wave_pos - wave_time, 4.0));
    
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
    
    // === Sparkle Highlights (uses highlight_speed, independent timing) ===
    float highlight_time = TIME * highlight_speed;
    
    // Each pixel gets a random "sparkle slot" based on position
    // The slot determines WHEN in the cycle this pixel sparkles
    float sparkle_slot = hash(pixel_coord);
    
    // Calculate current phase in the sparkle cycle (0 to 1)
    float cycle_phase = fract(highlight_time + sparkle_slot);
    
    // Pixel sparkles when cycle_phase is within [0, highlight_duration]
    // and only if this pixel is "chosen" based on highlight_chance
    float is_chosen = step(hash2(pixel_coord), highlight_chance);
    float is_active = step(cycle_phase, highlight_duration);
    float sparkle = is_chosen * is_active;
    
    // Add sparkle as bright highlight
    wave_color = mix(wave_color, min(color_4 * 1.3, vec3(1.0)), sparkle);
    
    // Preserve original alpha (masks non-hexagonal parts)
    // Use original_alpha when scrolling to keep hex shape, otherwise use tex_color.a
    float final_alpha = scroll_texture ? original_alpha : tex_color.a;
    COLOR = vec4(wave_color, final_alpha);
}
