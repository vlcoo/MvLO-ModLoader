shader_type canvas_item;

const float level = 3.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_enable, filter_nearest_mipmap;

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, level).rgb;

    //c.rgb = mix(vec3(0.0), c.rgb, 0.3);
    //c.rgb = mix(vec3(0.5), c.rgb, 0.7);
    //c.rgb = mix(vec3(dot(vec3(0.7), c.rgb) * 0.33333), c.rgb, 0.0);

    COLOR.rgb = c;
}
