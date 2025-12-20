shader_type canvas_item;

// Water animation parameters
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_strength : hint_range(0.0, 0.05) = 0.015;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;

// Color parameters
uniform vec4 shallow_color : source_color = vec4(0.2, 0.5, 0.7, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.2, 0.4, 1.0);
uniform float color_blend_speed : hint_range(0.1, 2.0) = 0.5;

// Shimmer/reflection parameters
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float shimmer_speed : hint_range(0.5, 5.0) = 2.0;
uniform float shimmer_scale : hint_range(5.0, 50.0) = 15.0;

// Foam/highlights
uniform float foam_threshold : hint_range(0.5, 1.0) = 0.85;
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.6);

// Simple noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for more natural waves
float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    
    // === Wave Distortion ===
    // Create multi-layered wave movement
    float wave1 = sin(uv.x * wave_frequency + time * wave_speed) * wave_strength;
    float wave2 = sin(uv.y * wave_frequency * 0.7 + time * wave_speed * 1.3) * wave_strength * 0.7;
    float wave3 = cos((uv.x + uv.y) * wave_frequency * 0.5 + time * wave_speed * 0.8) * wave_strength * 0.5;
    
    vec2 distorted_uv = uv + vec2(wave1 + wave2, wave2 + wave3);
    
    // === Base Texture ===
    vec4 tex_color = texture(TEXTURE, distorted_uv);
    
    // === Dynamic Color Blending ===
    // Create depth variation using noise
    float depth_noise = fbm(uv * 3.0 + vec2(time * color_blend_speed * 0.1), 3);
    float depth_factor = smoothstep(0.3, 0.7, depth_noise);
    
    // Blend between shallow and deep water colors
    vec4 water_tint = mix(deep_color, shallow_color, depth_factor);
    
    // Apply tint to texture while preserving some original detail
    vec4 tinted_water = mix(tex_color, tex_color * water_tint, 0.6);
    
    // === Shimmer/Reflection Effect ===
    float shimmer_noise = noise(uv * shimmer_scale + vec2(time * shimmer_speed, time * shimmer_speed * 0.7));
    float shimmer = smoothstep(0.6, 0.9, shimmer_noise) * shimmer_intensity;
    
    // Add directional shimmer variation (simulates sun reflection)
    float directional = sin(time * 0.5) * 0.5 + 0.5;
    shimmer *= 0.7 + 0.3 * directional;
    
    // === Foam Highlights ===
    float foam_noise = fbm(uv * 8.0 + vec2(time * 0.3, -time * 0.2), 2);
    float foam = smoothstep(foam_threshold, 1.0, foam_noise);
    
    // === Final Composition ===
    vec4 final_color = tinted_water;
    
    // Add shimmer highlights
    final_color.rgb += vec3(shimmer);
    
    // Add foam on top
    final_color = mix(final_color, foam_color, foam * foam_color.a * 0.5);
    
    // Preserve original alpha
    final_color.a = tex_color.a;
    
    COLOR = final_color;
}