shader_type canvas_item;

uniform vec2 hole_position;
uniform vec2 hole_size;
uniform float darkness : hint_range(0.0, 1.0) = 0.7;

void fragment() {

    vec2 uv = SCREEN_UV;
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    vec2 pixel_pos = uv * screen_size;

    vec2 min_pos = hole_position;
    vec2 max_pos = hole_position + hole_size;

    bool inside =
        pixel_pos.x > min_pos.x &&
        pixel_pos.x < max_pos.x &&
        pixel_pos.y > min_pos.y &&
        pixel_pos.y < max_pos.y;

    if (inside) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
    else {
        COLOR = vec4(0.0, 0.0, 0.0, darkness);
    }
}