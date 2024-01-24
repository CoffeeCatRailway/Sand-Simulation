shader_type canvas_item;

uniform sampler2D tex : filter_nearest, repeat_disable;
uniform vec2 size;

#define identity mat3(vec3(0., 0., 0.), vec3(0., 1., 0.), vec3(0., 0., 0.))
#define sharpen mat3(vec3(0., -1., 0.), vec3(-1., 5., -1.), vec3(0., -1., 0.))
#define boxBlur mat3(vec3(1., 1., 1.), vec3(1., 1., 1.), vec3(1., 1., 1.)) * .1111
#define gaussianBlur mat3(vec3(1., 2., 1.), vec3(2., 4., 2.), vec3(1., 2., 1.)) * .0625
#define emboss mat3(vec3(-2., -1., 0.), vec3(-1., 1., 1.), vec3(0., 1., 2.))

// https://www.shadertoy.com/view/fd3Szs
vec3 convolute(vec2 uv, mat3 kernel)
{
	vec3 color = vec3(0.);
	const float dir[3] = {-1., 0., 1.};
	for (int x = 0; x < 3; x++)
	{
		for (int y = 0; y < 3; y++)
		{
			vec2 offset = vec2(dir[x], dir[y]) / size;
			color += texture(tex, uv + offset).rgb * kernel[x][y];
		}
	}
	return color;
}

void fragment() {
	vec3 col = convolute(UV, identity);
	COLOR = vec4(col, 1.);
}
