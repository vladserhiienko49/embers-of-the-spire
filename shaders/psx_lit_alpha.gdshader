shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

#define PSX_ALPHA
#include "res://shaders/psx_lit_core.gdshaderinc"
