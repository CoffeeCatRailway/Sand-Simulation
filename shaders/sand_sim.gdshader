shader_type canvas_item;

uniform sampler2D tex : filter_nearest, repeat_disable;

void fragment() {
	COLOR = texture(tex, UV);
}
