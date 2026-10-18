class_name HUD
extends Control

@onready var p1_score_label: Label = %P1ScoreLabel if has_node("%P1ScoreLabel") else null
@onready var p2_score_label: Label = %P2ScoreLabel if has_node("%P2ScoreLabel") else null

@onready var turn_panel: PanelContainer = %TurnPanel if has_node("%TurnPanel") else null
@onready var turn_label: Label = %TurnLabel if has_node("%TurnLabel") else null

var _panel_style: StyleBoxFlat

var p1_name: String = "Игрок 1"
var p2_name: String = "Игрок 2"
var current_p1_score: int = 0
var current_p2_score: int = 0

const PLAYER_1_COLOR := Color("#1E88E5")
const PLAYER_2_COLOR := Color("#E53935")

# Аватарки игроков — TextureRect с круглым шейдером.
var _p1_avatar_rect: TextureRect = null
var _p2_avatar_rect: TextureRect = null
var _p1_avatar_material: ShaderMaterial = null
var _p2_avatar_material: ShaderMaterial = null

# Размер аватарки в HUD.
const AVATAR_HUD_SIZE: float = 48.0

# Шейдер круглой маски с рамкой — тот же что в main_menu.gd.
const AVATAR_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.23, 0.32, 0.46, 1.0);
uniform float border_width = 0.04;

void fragment() {
	vec2 offset = UV - vec2(0.5);
	float dist = length(offset);
	float edge = 0.005;
	float mask = 1.0 - smoothstep(0.5 - edge, 0.5, dist);
	float ring = smoothstep(0.5 - border_width - edge, 0.5 - border_width, dist);
	vec4 image = texture(TEXTURE, UV) * COLOR;
	COLOR = mix(image, border_color, ring);
	COLOR.a *= mask;
}
"""

func _ready() -> void:
	position.y += 30.0
	_apply_styles()
	_setup_avatar_overlays()


# =========================================================
# АВАТАРКИ
# =========================================================

func _setup_avatar_overlays() -> void:
	# Аватарки живут в CanvasLayer поверх HUD, чтобы не зависеть от
	# layout сцены. Позиционируются вручную над score-лейблами.
	var shader := Shader.new()
	shader.code = AVATAR_SHADER_CODE

	_p1_avatar_rect = _make_avatar_rect(shader)
	_p1_avatar_material = _p1_avatar_rect.material as ShaderMaterial
	_p1_avatar_material.set_shader_parameter("border_color", PLAYER_1_COLOR)
	add_child(_p1_avatar_rect)

	_p2_avatar_rect = _make_avatar_rect(shader)
	_p2_avatar_material = _p2_avatar_rect.material as ShaderMaterial
	_p2_avatar_material.set_shader_parameter("border_color", PLAYER_2_COLOR)
	add_child(_p2_avatar_rect)

	# Позиции выставляем после первого кадра, когда лейблы уже знают свой размер.
	await get_tree().process_frame
	_reposition_avatars()


func _make_avatar_rect(shader: Shader) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(AVATAR_HUD_SIZE, AVATAR_HUD_SIZE)
	rect.size = Vector2(AVATAR_HUD_SIZE, AVATAR_HUD_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat

	# Плейсхолдер — однотонный цвет.
	var img := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.15))
	rect.texture = ImageTexture.create_from_image(img)

	return rect


func _reposition_avatars() -> void:
	if p1_score_label and is_instance_valid(_p1_avatar_rect):
		var label_pos := p1_score_label.get_global_position()
		var label_size := p1_score_label.size

		_p1_avatar_rect.set_global_position(Vector2(
			label_pos.x + (label_size.x - AVATAR_HUD_SIZE) / 2.0,
			label_pos.y - AVATAR_HUD_SIZE - 8.0
		))

	if p2_score_label and is_instance_valid(_p2_avatar_rect):
		var label_pos := p2_score_label.get_global_position()
		var label_size := p2_score_label.size

		_p2_avatar_rect.set_global_position(Vector2(
			label_pos.x + (label_size.x - AVATAR_HUD_SIZE) / 2.0,
			label_pos.y - AVATAR_HUD_SIZE - 8.0
		))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_TRANSFORM_CHANGED:
		_reposition_avatars()


# Устанавливает текстуру аватарки из текстуры (Texture2D).
func set_player_avatars(p1_texture: Texture2D, p2_texture: Texture2D) -> void:
	if is_instance_valid(_p1_avatar_rect) and p1_texture != null:
		_p1_avatar_rect.texture = p1_texture

	if is_instance_valid(_p2_avatar_rect) and p2_texture != null:
		_p2_avatar_rect.texture = p2_texture


# =========================================================
# СТИЛИ
# =========================================================

func _apply_styles() -> void:
	if turn_panel:
		_panel_style = StyleBoxFlat.new()
		_panel_style.bg_color = PLAYER_1_COLOR
		_panel_style.set_corner_radius_all(12)
		_panel_style.set_content_margin_all(10)
		_panel_style.shadow_color = Color(0, 0, 0, 0.4)
		_panel_style.shadow_size = 8
		turn_panel.add_theme_stylebox_override("panel", _panel_style)

	if turn_label:
		turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		turn_label.add_theme_font_size_override("font_size", 20)
		turn_label.add_theme_color_override("font_color", Color.WHITE)
		turn_label.add_theme_color_override("font_outline_color", Color.BLACK)
		turn_label.add_theme_constant_override("outline_size", 4)

	if p1_score_label:
		p1_score_label.add_theme_font_size_override("font_size", 22)
		p1_score_label.add_theme_color_override("font_color", Color("#4C8BF5"))

	if p2_score_label:
		p2_score_label.add_theme_font_size_override("font_size", 22)
		p2_score_label.add_theme_color_override("font_color", Color("#FF5252"))


# =========================================================
# ИМЕНА И СЧЁТ
# =========================================================

func set_player_names(name1: String, name2: String) -> void:
	p1_name = name1 if not name1.is_empty() else "Игрок 1"
	p2_name = name2 if not name2.is_empty() else "Игрок 2"
	update_score(current_p1_score, current_p2_score)


func update_score(p1_score: int, p2_score: int) -> void:
	current_p1_score = p1_score
	current_p2_score = p2_score

	if p1_score_label:
		p1_score_label.text = "%s: %d" % [p1_name, p1_score]

	if p2_score_label:
		p2_score_label.text = "%s: %d" % [p2_name, p2_score]

	# После обновления текста лейбл меняет размер — перепозиционируем аватарки.
	await get_tree().process_frame
	_reposition_avatars()


# =========================================================
# ХОД
# =========================================================

func update_turn_status_with_names(
	current_player: Enums.Player,
	game_mode: Enums.GameMode,
	local_player: Enums.Player,
	name1: String,
	name2: String
) -> void:
	set_player_names(name1, name2)
	update_turn_status(current_player, game_mode, local_player)


func update_turn_status(
	current_player: Enums.Player,
	game_mode: Enums.GameMode,
	local_player: Enums.Player
) -> void:
	if not turn_label or not turn_panel:
		return

	var text := ""
	var target_color := PLAYER_1_COLOR

	match game_mode:
		Enums.GameMode.VS_BOT:
			if current_player == local_player:
				text = "ТВОЙ ХОД"
				target_color = PLAYER_1_COLOR
			else:
				text = "ХОД БОТА..."
				target_color = PLAYER_2_COLOR

		Enums.GameMode.LAN_PVP:
			if local_player == Enums.Player.NONE:
				if current_player == Enums.Player.PLAYER_1:
					text = "ХОД: %s" % p1_name.to_upper()
					target_color = PLAYER_1_COLOR
				elif current_player == Enums.Player.PLAYER_2:
					text = "ХОД: %s" % p2_name.to_upper()
					target_color = PLAYER_2_COLOR
				else:
					text = "ОЖИДАНИЕ ХОДА..."
					target_color = PLAYER_1_COLOR
			else:
				if current_player == local_player:
					text = "ТВОЙ ХОД"
					target_color = PLAYER_1_COLOR
				else:
					text = "ХОД СОПЕРНИКА..."
					target_color = PLAYER_2_COLOR

		Enums.GameMode.LOCAL_PVP:
			if current_player == Enums.Player.PLAYER_1:
				text = "ХОД: %s" % p1_name.to_upper()
				target_color = PLAYER_1_COLOR
			else:
				text = "ХОД: %s" % p2_name.to_upper()
				target_color = PLAYER_2_COLOR

	turn_label.text = text
	_animate_banner(target_color)


func _animate_banner(new_color: Color) -> void:
	if _panel_style:
		_panel_style.bg_color = new_color

	turn_panel.pivot_offset = turn_panel.size / 2.0

	var tween := create_tween()
	tween.tween_property(turn_panel, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(turn_panel, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
