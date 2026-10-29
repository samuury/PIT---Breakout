extends RefCounted
# Gráficos: céu procedural, bloom, SSAO/SSR, materiais com shader e presets de qualidade/resolução.

const QUALITY_NAMES := ["BAIXA", "MÉDIA", "ALTA", "ULTRA"]
const QUALITY_DESC := [
	"Sem sombras nem pós-processamento. Para PCs fracos.",
	"MSAA 2x, bloom e sombras suaves.",
	"MSAA 4x, bloom, SSAO, sombras em alta resolução e vinheta.",
	"MSAA 4x + FXAA, SSAO, reflexos no chão (SSR), névoa e sombras 8K.",
]
const QUALITY := [
	{"msaa": 0, "fxaa": true, "ssao": false, "ssr": false, "glow": false, "fog": false, "shadow": false, "shadow_size": 1024, "soft": 0, "post": false},
	{"msaa": 1, "fxaa": false, "ssao": false, "ssr": false, "glow": true, "fog": false, "shadow": true, "shadow_size": 2048, "soft": 2, "post": true},
	{"msaa": 2, "fxaa": false, "ssao": true, "ssr": false, "glow": true, "fog": false, "shadow": true, "shadow_size": 4096, "soft": 3, "post": true},
	{"msaa": 2, "fxaa": true, "ssao": true, "ssr": true, "glow": true, "fog": true, "shadow": true, "shadow_size": 8192, "soft": 4, "post": true},
]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const SCALES := [0.5, 0.75, 1.0, 1.5, 2.0]

var quality := 2
var res_idx := 2
var scale_idx := 2
var fullscreen := false
var post := true

var env: Environment
var sun: DirectionalLight3D
var post_rect: ColorRect
var floor_mat: ShaderMaterial
var brick_mat: ShaderMaterial
var neon_mat: ShaderMaterial
var paddle_shader: Shader
var halo_tex: GradientTexture2D
var ring_tex: GradientTexture2D


func shader_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func make_materials() -> void:
	floor_mat = shader_mat("res://shaders/floor.gdshader")
	brick_mat = shader_mat("res://shaders/brick.gdshader")
	neon_mat = shader_mat("res://shaders/neon.gdshader")
	paddle_shader = load("res://shaders/paddle.gdshader")
	halo_tex = radial_texture(false)
	ring_tex = radial_texture(true)


func radial_texture(ring: bool) -> GradientTexture2D:
	var g := Gradient.new()
	if ring:
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 0.9, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func halo_material(col: Color, ring := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = ring_tex if ring else halo_tex
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	return m


func new_paddle_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = paddle_shader
	return m


func build_environment(parent: Node) -> void:
	make_materials()
	var sky_mat := shader_mat("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.18
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.25
	env.fog_light_color = Color(0.08, 0.06, 0.20)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 18, 0)
	sun.light_energy = 0.9
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	parent.add_child(sun)

	var side := [[Vector3(-26, 4, 14), Color(1.0, 0.25, 0.8)], [Vector3(26, 4, 14), Color(0.2, 0.7, 1.0)]]
	for s in side:
		var l := OmniLight3D.new()
		l.position = s[0]
		l.light_color = s[1]
		l.light_energy = 0.7
		l.omni_range = 55.0
		parent.add_child(l)


func build_post(parent: Node) -> void:
	post_rect = ColorRect.new()
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.material = shader_mat("res://shaders/post.gdshader")
	parent.add_child(post_rect)
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func apply(vp: Viewport, win: Window) -> void:
	var q: Dictionary = QUALITY[quality]
	vp.msaa_3d = int(q.msaa) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	var sc: float = SCALES[scale_idx]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = sc
	env.glow_enabled = q.glow
	env.ssao_enabled = q.ssao
	env.ssr_enabled = q.ssr
	env.fog_enabled = q.fog
	sun.shadow_enabled = q.shadow
	RenderingServer.directional_shadow_atlas_set_size(int(q.shadow_size), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(q.soft) as RenderingServer.ShadowQuality)
	if post_rect != null:
		post_rect.visible = post and bool(q.post)
	if win != null and DisplayServer.get_name() != "headless":
		if fullscreen:
			win.mode = Window.MODE_FULLSCREEN
		else:
			win.mode = Window.MODE_WINDOWED
			var r: Vector2i = RESOLUTIONS[res_idx]
			var scr := DisplayServer.screen_get_usable_rect().size
			win.size = Vector2i(mini(r.x, scr.x), mini(r.y, scr.y))
			win.move_to_center()


func render_info(win: Window) -> String:
	var s: float = SCALES[scale_idx]
	var sz := win.size
	return "Renderização 3D: %dx%d  (%d%% de %dx%d)" % [int(sz.x * s), int(sz.y * s), int(s * 100.0), sz.x, sz.y]
