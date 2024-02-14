shader_type canvas_item;

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform int paletteIdx = 0;

// ignore alpha when compareing
// Based on https://github.com/KoBeWi/Godot-Palette-Swap-Shader/blob/master/PaletteSwap.gdshader

void fragment()
{
	vec4 spriteColor = texture(TEXTURE, UV);
	ivec3 spriteColori = ivec3(round(spriteColor.rgb * 255.));
	ivec2 colorCount = textureSize(palette, 0);
	
	float idx = -1.;
	for (int i = 0; i < colorCount.x; i++)
	{
		vec3 palColor = texture(palette, vec2(float(i) / float(colorCount.x - 1), 0)).rgb;
		ivec3 palColori = ivec3(round(palColor * 255.));
		if (spriteColori == palColori)
		{
			idx = float(i);
			break;
		}
	}
	
	if (idx >= 0.)
	{
		vec2 uv = vec2(idx / float(colorCount.x - 1), float(paletteIdx) / float(colorCount.y - 1));
		vec4 color = texture(palette, uv);
		color.a = spriteColor.a;
		COLOR = color;
	}
}
