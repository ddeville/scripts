#version 330

in vec2 texcoord;
uniform sampler2D tex;
vec4 default_post_processing(vec4 color);

#ifndef FALLBACK_COLOR
#define FALLBACK_COLOR vec3(38.0 / 255.0)
#endif

vec4 window_shader() {
    vec2 size = textureSize(tex, 0);
    vec4 color = texture(tex, texcoord / size);
    // Fill GTK's transparent X11 buffer before Ghostty's first repaint.
    color.rgb += (1.0 - color.a) * FALLBACK_COLOR;
    color.a = 1.0;
    return default_post_processing(color);
}
