// Simple glow shader for Love2D
extern float strength;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    float glow = strength * (pixel.r + pixel.g + pixel.b) / 3.0;
    return vec4(pixel.rgb + glow, pixel.a) * color;
}
