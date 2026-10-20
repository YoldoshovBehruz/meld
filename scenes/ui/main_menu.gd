class_name MainMenu
extends Control

signal mode_selected(mode: Enums.GameMode)
signal campaign_requested
signal settings_requested
signal nickname_changed(new_name: String)

enum PickTarget { NONE, AVATAR, BANNER }

var _bg_rect: ColorRect
var _theme_mgr: Node = null
var _profile_save_manager: Node = null

var _profile_button: Button
var _profile_panel: PanelContainer
var _profile_title: Label
var _profile_nickname_label: Label
var _profile_id_label: Label
var _profile_stats_label: Label
var _profile_close_button: Button

var _profile_header: Control
var _profile_banner_rect: TextureRect
var _profile_avatar_rect: TextureRect
var _profile_avatar_button: Button
var _profile_banner_button: Button
var _profile_reset_button: Button

# Селектор изображений
var _image_selector_panel: PanelContainer = null
var _image_selector_scroll: ScrollContainer = null
var _image_selector_grid: GridContainer = null
var _image_selector_title: Label = null
var _image_selector_close_button: Button = null
var _selector_banner_item_height: float = 82.0
var _selector_item_bg: Color = Color("#0B1220")
var _selector_item_hover: Color = Color("#18243A")
var _selector_item_border: Color = Color("#3B5275")
var _selector_item_text: Color = Color.WHITE
var _pick_target: PickTarget = PickTarget.NONE

# Доступные изображения
var _available_avatars: PackedStringArray = PackedStringArray()
var _available_banners: PackedStringArray = PackedStringArray()

var _avatar_material: ShaderMaterial = null
var _banner_material: ShaderMaterial = null
var _avatar_texture: Texture2D = null
var _banner_texture: Texture2D = null
var _placeholder_texture: ImageTexture = null
var _avatar_placeholder_color: Color = Color("#18243A")
var _banner_placeholder_color: Color = Color("#3B5275")

var _avatar_base64: String = ""
var _peer_avatars: Dictionary = {}
var _current_avatar_path: String = ""
var _current_banner_path: String = ""

var name_input: LineEdit
var current_nickname: String = "Игрок"
var _device_id: String = ""

# Кампания
var _campaign_button: Button = null

@onready var main_container: VBoxContainer = %MainContainer
@onready var mode_container: VBoxContainer = %ModeContainer
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton if has_node("%SettingsButton") else null
@onready var exit_button: Button = %ExitButton
@onready var local_pvp_button: Button = %LocalPVPButton
@onready var vs_bot_button: Button = %VSBotButton
@onready var lan_pvp_button: Button = _find_lan_pvp_button()
@onready var back_button: Button = %BackButton

const SAVE_PATH: String = "user://settings.cfg"
const PROFILE_DIR: String = "user://profile"
const AVATAR_FILE_NAME: String = "avatar.png"
const BANNER_FILE_NAME: String = "banner.png"
const AVATAR_PATH: String = "user://profile/avatar.png"
const BANNER_PATH: String = "user://profile/banner.png"

const AVATARS_SOURCE_DIR: String = "res://assets/profiles"
const BANNERS_SOURCE_DIR: String = "res://assets/banners"

const AVATAR_SIZE: Vector2i = Vector2i(512, 512)
const AVATAR_NET_SIZE: int = 128
const BANNER_SIZE: Vector2i = Vector2i(1500, 270)

const BANNER_HEIGHT: float = 90.0
const BANNER_CORNER_RADIUS: float = 14.0
const AVATAR_DISPLAY_SIZE: float = 76.0
const PROFILE_HEADER_HEIGHT: float = 128.0

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

const BANNER_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(500.0, 90.0);
uniform float corner_radius = 14.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(p - half_size) - (half_size - vec2(corner_radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float alpha = 1.0 - smoothstep(-0.5, 0.5, d);
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= alpha;
}
"""


func _find_lan_pvp_button() -> Button:
	for unique_path in ["%LanPVPButton", "%LanPvpButton", "%LANPVPButton", "%NetworkButton"]:
		var candidate: Node = get_node_or_null(unique_path)
		if candidate is Button:
			return candidate as Button
	var mode_root: Node = get_node_or_null("%ModeContainer")
	if mode_root != null:
		var found := _find_lan_button_recursive(mode_root)
		if found != null:
			return found
	return _find_lan_button_recursive(self)


func _find_lan_button_recursive(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			var button := child as Button
			var node_name := str(button.name).to_lower().replace("_", "").replace(" ", "")
			var button_text := button.text.to_lower()
			if (
				node_name.contains("lan") or node_name.contains("network")
				or node_name.contains("online") or button_text.contains("lan")
				or button_text.contains("сетев") or button_text.contains("network")
			):
				return button
		var nested: Button = _find_lan_button_recursive(child)
		if nested != null:
			return nested
	return null


func _ready() -> void:
	_ensure_background_exists()
	_load_nickname()
	_load_device_id()
	_setup_nickname_input()
	_setup_profile_ui()
	_setup_image_selector()
	_load_available_images()
	_init_theme_manager()
	_connect_signals()
	show_main_section()
	_refresh_profile()


# =========================================================
# ПРОФИЛЬ
# =========================================================

func setup_profile(manager: Node) -> void:
	_profile_save_manager = manager
	if not is_instance_valid(_profile_save_manager):
		_refresh_profile()
		return

	var profile_changed_callable := Callable(self, "_on_save_manager_profile_changed")
	if (
		_profile_save_manager.has_signal("profile_changed")
		and not _profile_save_manager.is_connected("profile_changed", profile_changed_callable)
	):
		_profile_save_manager.connect("profile_changed", profile_changed_callable)

	if _profile_save_manager.has_method("set_nickname"):
		_profile_save_manager.call("set_nickname", get_nickname())

	var saved_profile: Dictionary = _get_stats_dictionary()
	var saved_device_id := str(saved_profile.get("device_id", "")).strip_edges()
	if not saved_device_id.is_empty():
		_device_id = saved_device_id

	_refresh_profile()


func _on_save_manager_profile_changed(profile: Dictionary) -> void:
	var profile_device_id := str(profile.get("device_id", "")).strip_edges()
	if not profile_device_id.is_empty():
		_device_id = profile_device_id
	_refresh_profile()


func _setup_profile_ui() -> void:
	_profile_button = Button.new()
	_profile_button.name = "ProfileButton"
	_profile_button.text = "ПРОФИЛЬ"
	_profile_button.anchor_left = 1.0
	_profile_button.anchor_right = 1.0
	_profile_button.anchor_top = 0.0
	_profile_button.anchor_bottom = 0.0
	_profile_button.offset_left = -210.0
	_profile_button.offset_right = -24.0
	_profile_button.offset_top = 20.0
	_profile_button.offset_bottom = 72.0
	add_child(_profile_button)
	_profile_button.pressed.connect(_on_profile_pressed)

	_profile_panel = PanelContainer.new()
	_profile_panel.name = "ProfilePanel"
	_profile_panel.anchor_left = 0.5
	_profile_panel.anchor_right = 0.5
	_profile_panel.anchor_top = 0.5
	_profile_panel.anchor_bottom = 0.5
	_profile_panel.offset_left = -270.0
	_profile_panel.offset_right = 270.0
	_profile_panel.offset_top = -310.0
	_profile_panel.offset_bottom = 310.0
	_profile_panel.custom_minimum_size = Vector2(540, 620)
	_profile_panel.visible = false
	_profile_panel.z_index = 100
	add_child(_profile_panel)

	var content := VBoxContainer.new()
	content.name = "ProfileContent"
	content.add_theme_constant_override("separation", 8)
	_profile_panel.add_child(content)

	_profile_title = Label.new()
	_profile_title.text = "ПРОФИЛЬ ИГРОКА"
	_profile_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_title.add_theme_font_size_override("font_size", 24)
	content.add_child(_profile_title)

	_setup_profile_header(content)

	_profile_nickname_label = Label.new()
	_profile_nickname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_nickname_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_profile_nickname_label)

	_profile_id_label = Label.new()
	_profile_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_id_label.add_theme_font_size_override("font_size", 13)
	content.add_child(_profile_id_label)

	_profile_stats_label = Label.new()
	_profile_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_profile_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_stats_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_profile_stats_label)

	_setup_action_row(content)

	_profile_close_button = Button.new()
	_profile_close_button.name = "ProfileCloseButton"
	_profile_close_button.text = "ЗАКРЫТЬ"
	_profile_close_button.custom_minimum_size = Vector2(0, 46)
	_profile_close_button.pressed.connect(_on_profile_close_pressed)
	content.add_child(_profile_close_button)

	_load_profile_images()


# =========================================================
# ШАПКА ПРОФИЛЯ
# =========================================================

func _setup_profile_header(parent: VBoxContainer) -> void:
	var placeholder_image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	placeholder_image.fill(Color.WHITE)
	_placeholder_texture = ImageTexture.create_from_image(placeholder_image)

	_profile_header = Control.new()
	_profile_header.name = "ProfileHeader"
	_profile_header.custom_minimum_size = Vector2(0, PROFILE_HEADER_HEIGHT)
	_profile_header.size_flags_horizontal = Control.SIZE_FILL
	parent.add_child(_profile_header)

	_profile_banner_rect = TextureRect.new()
	_profile_banner_rect.name = "ProfileBanner"
	_profile_banner_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_profile_banner_rect.offset_bottom = BANNER_HEIGHT
	_profile_banner_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_profile_banner_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var banner_shader := Shader.new()
	banner_shader.code = BANNER_SHADER_CODE
	_banner_material = ShaderMaterial.new()
	_banner_material.shader = banner_shader
	_banner_material.set_shader_parameter("corner_radius", BANNER_CORNER_RADIUS)
	_profile_banner_rect.material = _banner_material
	_profile_banner_rect.resized.connect(_update_banner_shader_size)
	_profile_header.add_child(_profile_banner_rect)

	_profile_avatar_rect = TextureRect.new()
	_profile_avatar_rect.name = "ProfileAvatar"
	_profile_avatar_rect.anchor_left = 0.5
	_profile_avatar_rect.anchor_right = 0.5
	_profile_avatar_rect.anchor_top = 0.0
	_profile_avatar_rect.anchor_bottom = 0.0
	_profile_avatar_rect.offset_left = -AVATAR_DISPLAY_SIZE / 2.0
	_profile_avatar_rect.offset_right = AVATAR_DISPLAY_SIZE / 2.0
	_profile_avatar_rect.offset_top = BANNER_HEIGHT - AVATAR_DISPLAY_SIZE / 2.0
	_profile_avatar_rect.offset_bottom = BANNER_HEIGHT + AVATAR_DISPLAY_SIZE / 2.0
	_profile_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_profile_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var avatar_shader := Shader.new()
	avatar_shader.code = AVATAR_SHADER_CODE
	_avatar_material = ShaderMaterial.new()
	_avatar_material.shader = avatar_shader
	_profile_avatar_rect.material = _avatar_material
	_profile_header.add_child(_profile_avatar_rect)


func _update_banner_shader_size() -> void:
	if _banner_material == null or not is_instance_valid(_profile_banner_rect):
		return
	_banner_material.set_shader_parameter("rect_size", _profile_banner_rect.size)


func _setup_action_row(parent: VBoxContainer) -> void:
	var action_row := HBoxContainer.new()
	action_row.name = "ProfileActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	parent.add_child(action_row)

	_profile_avatar_button = Button.new()
	_profile_avatar_button.name = "ProfileAvatarButton"
	_profile_avatar_button.text = "СМЕНИТЬ АВАТАР"
	_profile_avatar_button.custom_minimum_size = Vector2(170, 46)
	_profile_avatar_button.pressed.connect(_on_avatar_button_pressed)
	action_row.add_child(_profile_avatar_button)

	_profile_banner_button = Button.new()
	_profile_banner_button.name = "ProfileBannerButton"
	_profile_banner_button.text = "СМЕНИТЬ БАННЕР"
	_profile_banner_button.custom_minimum_size = Vector2(170, 46)
	_profile_banner_button.pressed.connect(_on_banner_button_pressed)
	action_row.add_child(_profile_banner_button)

	_profile_reset_button = Button.new()
	_profile_reset_button.name = "ProfileResetButton"
	_profile_reset_button.text = "СБРОС"
	_profile_reset_button.tooltip_text = "Удалить аватар и баннер"
	_profile_reset_button.custom_minimum_size = Vector2(110, 46)
	_profile_reset_button.pressed.connect(_on_reset_pressed)
	action_row.add_child(_profile_reset_button)


# =========================================================
# СЕЛЕКТОР ИЗОБРАЖЕНИЙ
# =========================================================

func _setup_image_selector() -> void:
	_image_selector_panel = PanelContainer.new()
	_image_selector_panel.name = "ImageSelectorPanel"
	_image_selector_panel.anchor_left = 0.5
	_image_selector_panel.anchor_right = 0.5
	_image_selector_panel.anchor_top = 0.5
	_image_selector_panel.anchor_bottom = 0.5
	_image_selector_panel.offset_left = -250.0
	_image_selector_panel.offset_right = 250.0
	_image_selector_panel.offset_top = -290.0
	_image_selector_panel.offset_bottom = 290.0
	_image_selector_panel.custom_minimum_size = Vector2.ZERO
	_image_selector_panel.visible = false
	_image_selector_panel.z_index = 110
	add_child(_image_selector_panel)

	var content := VBoxContainer.new()
	content.name = "SelectorContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	_image_selector_panel.add_child(content)

	_image_selector_title = Label.new()
	_image_selector_title.name = "SelectorTitle"
	_image_selector_title.text = "ВЫБЕРИТЕ ИЗОБРАЖЕНИЕ"
	_image_selector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_image_selector_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_image_selector_title.custom_minimum_size = Vector2(0.0, 24.0)
	_image_selector_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_selector_title.add_theme_font_size_override("font_size", 14)
	content.add_child(_image_selector_title)

	# Прокрутка остаётся между заголовком и кнопкой, поэтому закрытие
	# доступно даже при большом количестве аватаров или низком разрешении.
	_image_selector_scroll = ScrollContainer.new()
	_image_selector_scroll.name = "SelectorScroll"
	_image_selector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_selector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image_selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_image_selector_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(_image_selector_scroll)

	_image_selector_grid = GridContainer.new()
	_image_selector_grid.name = "SelectorGrid"
	_image_selector_grid.columns = 1
	_image_selector_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_selector_grid.add_theme_constant_override("h_separation", 6)
	_image_selector_grid.add_theme_constant_override("v_separation", 6)
	_image_selector_scroll.add_child(_image_selector_grid)

	_image_selector_close_button = Button.new()
	_image_selector_close_button.name = "SelectorCloseButton"
	_image_selector_close_button.text = "ЗАКРЫТЬ"
	_image_selector_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_image_selector_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_selector_close_button.pressed.connect(_on_selector_close)
	content.add_child(_image_selector_close_button)

	get_viewport().size_changed.connect(_update_image_selector_layout)
	_update_image_selector_layout()


func _update_image_selector_layout() -> void:
	if not is_instance_valid(_image_selector_panel):
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var is_avatar_selector := _pick_target == PickTarget.AVATAR
	var wanted_width: float = 680.0 if is_avatar_selector else 500.0
	var wanted_height: float = 540.0 if is_avatar_selector else 580.0
	var panel_width := minf(wanted_width, maxf(160.0, viewport_size.x - 32.0))
	var panel_height := minf(wanted_height, maxf(180.0, viewport_size.y - 32.0))

	_image_selector_panel.offset_left = -panel_width * 0.5
	_image_selector_panel.offset_right = panel_width * 0.5
	_image_selector_panel.offset_top = -panel_height * 0.5
	_image_selector_panel.offset_bottom = panel_height * 0.5

	# При обычном разрешении 1152x648 все пять баннеров видны одновременно.
	# На меньшей высоте миниатюры автоматически уменьшаются, а ScrollContainer
	# служит запасным вариантом для совсем маленьких окон.
	var available_for_rows := panel_height - 32.0 - 24.0 - 44.0 - 14.0 - 24.0
	_selector_banner_item_height = clampf(available_for_rows / 5.0, 18.0, 86.0)

	if is_instance_valid(_image_selector_grid) and _pick_target == PickTarget.BANNER:
		for child in _image_selector_grid.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(0.0, _selector_banner_item_height)


func _load_available_images() -> void:
	_available_avatars = _scan_directory(AVATARS_SOURCE_DIR)
	_available_banners = _scan_directory(BANNERS_SOURCE_DIR)

	if _available_avatars.is_empty():
		push_warning("Не найдено аватарок в " + AVATARS_SOURCE_DIR)
	if _available_banners.is_empty():
		push_warning("Не найдено баннеров в " + BANNERS_SOURCE_DIR)


func _scan_directory(dir_path: String) -> PackedStringArray:
	# В экспортированной Android-версии нельзя полагаться на DirAccess для res://:
	# после импорта исходные PNG/JPG могут отсутствовать как обычные файлы в PCK.
	# ResourceLoader.list_directory() возвращает ресурсы с исходными именами.
	var result := PackedStringArray()
	var entries: PackedStringArray = ResourceLoader.list_directory(dir_path)

	if entries.is_empty():
		push_warning(
			"В папке ресурсов нет доступных файлов или путь указан неверно: " + dir_path
		)
		return result

	for entry in entries:
		# Каталоги ResourceLoader помечает завершающим слешем.
		if entry.ends_with("/") or entry.begins_with("."):
			continue
		if not _is_image_file(entry):
			continue

		var full_path := dir_path.path_join(entry)
		# Проверяем, что ресурс действительно попал в экспорт и доступен движку.
		if ResourceLoader.exists(full_path):
			result.append(full_path)
		else:
			push_warning("Изображение найдено в списке, но недоступно для загрузки: " + full_path)

	result.sort()
	return result


func _is_image_file(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	return (
		lower_name.ends_with(".png")
		or lower_name.ends_with(".jpg")
		or lower_name.ends_with(".jpeg")
		or lower_name.ends_with(".webp")
	)


func _on_avatar_button_pressed() -> void:
	_pick_target = PickTarget.AVATAR
	_show_image_selector(PickTarget.AVATAR)


func _on_banner_button_pressed() -> void:
	_pick_target = PickTarget.BANNER
	_show_image_selector(PickTarget.BANNER)


func _show_image_selector(target: PickTarget) -> void:
	if not is_instance_valid(_image_selector_grid):
		return

	_pick_target = target
	_update_image_selector_layout()

	# Удаляем старые миниатюры перед заполнением списка.
	for child in _image_selector_grid.get_children():
		child.queue_free()

	var images_to_show := (
		_available_avatars if target == PickTarget.AVATAR
		else _available_banners
	)

	_image_selector_title.text = (
		"ВЫБЕРИТЕ АВАТАР"
		if target == PickTarget.AVATAR
		else "ВЫБЕРИТЕ БАННЕР"
	)

	# Баннеры идут одной компактной колонкой, аватары — сеткой квадратных карточек.
	_image_selector_grid.columns = 1 if target == PickTarget.BANNER else 5

	for image_path in images_to_show:
		var btn := _create_image_selector_button(image_path, target)
		_image_selector_grid.add_child(btn)

	_image_selector_scroll.scroll_vertical = 0
	_image_selector_panel.visible = true


func _create_image_selector_button(image_path: String, target: PickTarget) -> Button:
	var btn := Button.new()
	btn.name = "ImageOption_" + image_path.get_file().get_basename()
	btn.tooltip_text = image_path.get_file()
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true

	if target == PickTarget.BANNER:
		btn.custom_minimum_size = Vector2(0.0, _selector_banner_item_height)
	else:
		btn.custom_minimum_size = Vector2(96.0, 96.0)

	var texture := _load_texture_from_file(image_path)
	if texture != null:
		# Не используем Button.icon: Godot учитывает исходный размер большой
		# текстуры как минимум кнопки, из-за чего окно разъезжается за экран.
		var preview := TextureRect.new()
		preview.name = "ImagePreview"
		preview.set_anchors_preset(Control.PRESET_FULL_RECT)
		preview.offset_left = 4.0
		preview.offset_top = 4.0
		preview.offset_right = -4.0
		preview.offset_bottom = -4.0
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.texture = texture
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(preview)
	else:
		btn.text = "Изображение не найдено"

	_style_image_selector_button(btn)
	btn.pressed.connect(func(): _on_image_selected(image_path, target))
	return btn


func _style_image_selector_button(btn: Button) -> void:
	if not is_instance_valid(btn):
		return

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = _selector_item_bg
	normal_style.border_color = _selector_item_border
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(9)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = _selector_item_hover
	hover_style.border_color = _selector_item_text

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = _selector_item_border

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.add_theme_color_override("font_color", _selector_item_text)
	btn.add_theme_font_size_override("font_size", 13)


func _on_image_selected(image_path: String, target: PickTarget) -> void:
	var texture := _load_texture_from_file(image_path)
	if texture == null:
		push_warning("Не удалось загрузить изображение: " + image_path)
		return

	match target:
		PickTarget.AVATAR:
			_current_avatar_path = image_path
			_set_avatar_texture(texture)
			_save_avatar_choice(image_path)
			_encode_avatar_for_network_from_path(image_path)

		PickTarget.BANNER:
			_current_banner_path = image_path
			_set_banner_texture(texture)
			_save_banner_choice(image_path)

		_:
			push_warning("Неизвестное назначение для выбранного изображения.")

	_image_selector_panel.visible = false
	_pick_target = PickTarget.NONE


func _on_selector_close() -> void:
	_image_selector_panel.visible = false
	_pick_target = PickTarget.NONE


func _on_reset_pressed() -> void:
	_pick_target = PickTarget.NONE
	_current_avatar_path = ""
	_current_banner_path = ""
	_avatar_base64 = ""
	_set_avatar_texture(null)
	_set_banner_texture(null)
	_clear_profile_choices()


# =========================================================
# СОХРАНЕНИЕ ВЫБОРА
# =========================================================

func _save_avatar_choice(image_path: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("profile", "avatar_choice", image_path)
	config.save(SAVE_PATH)


func _save_banner_choice(image_path: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("profile", "banner_choice", image_path)
	config.save(SAVE_PATH)


func _clear_profile_choices() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("profile", "avatar_choice", "")
	config.set_value("profile", "banner_choice", "")
	config.save(SAVE_PATH)


func _load_profile_images() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)

	var saved_avatar := str(config.get_value("profile", "avatar_choice", "")).strip_edges()
	if not saved_avatar.is_empty() and ResourceLoader.exists(saved_avatar):
		_current_avatar_path = saved_avatar
		var texture := _load_texture_from_file(saved_avatar)
		if texture != null:
			_set_avatar_texture(texture)
			_encode_avatar_for_network_from_path(saved_avatar)

	var saved_banner := str(config.get_value("profile", "banner_choice", "")).strip_edges()
	if not saved_banner.is_empty() and ResourceLoader.exists(saved_banner):
		_current_banner_path = saved_banner
		var texture := _load_texture_from_file(saved_banner)
		if texture != null:
			_set_banner_texture(texture)


# =========================================================
# ЗАГРУЗКА ТЕКСТУР
# =========================================================

func _load_texture_from_file(path: String) -> Texture2D:
	if path.is_empty():
		return null

	# Для res:// используем ResourceLoader
	if path.begins_with("res://"):
		var texture := ResourceLoader.load(path) as Texture2D
		if texture != null:
			return texture

	# Для user:// используем Image
	if path.begins_with("user://"):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	return null


# =========================================================
# BASE64 ДЛЯ СЕТИ
# =========================================================

func _encode_avatar_for_network_from_path(image_path: String) -> void:
	var source_image := Image.load_from_file(image_path) if image_path.begins_with("user://") else null

	# Если это res://, загружаем через ResourceLoader
	if source_image == null and image_path.begins_with("res://"):
		var texture := ResourceLoader.load(image_path) as Texture2D
		if texture != null:
			source_image = texture.get_image()

	if source_image == null or source_image.is_empty():
		push_warning("Не удалось загрузить аватар для кодирования: " + image_path)
		_avatar_base64 = ""
		return

	var net_image := _fit_cover(source_image, Vector2i(AVATAR_NET_SIZE, AVATAR_NET_SIZE))
	if net_image.get_format() != Image.FORMAT_RGBA8:
		net_image.convert(Image.FORMAT_RGBA8)

	var jpeg_bytes := net_image.save_jpg_to_buffer(0.75)
	if jpeg_bytes.is_empty():
		push_warning("Не удалось закодировать аватар в JPEG.")
		_avatar_base64 = ""
		return

	_avatar_base64 = Marshalls.raw_to_base64(jpeg_bytes)


func get_avatar_base64() -> String:
	return _avatar_base64


func apply_peer_avatars(members: Array) -> void:
	_peer_avatars.clear()
	for member in members:
		if not (member is Dictionary):
			continue
		var role := str(member.get("role", ""))
		var b64 := str(member.get("avatar_b64", ""))
		if b64.is_empty() or role.is_empty():
			continue
		var texture := _texture_from_base64(b64)
		if texture != null:
			_peer_avatars[role] = texture


func get_peer_avatar(role: String) -> Texture2D:
	return _peer_avatars.get(role, null)


func _texture_from_base64(b64: String) -> ImageTexture:
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes.is_empty():
		return null
	var image := _image_from_bytes(bytes)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _image_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.is_empty():
		return null

	var image := Image.new()
	if image.load_png_from_buffer(bytes) == OK:
		return image
	if image.load_jpg_from_buffer(bytes) == OK:
		return image
	if image.load_webp_from_buffer(bytes) == OK:
		return image

	return null


# =========================================================
# ОБРАБОТКА ТЕКСТУР
# =========================================================

func _fit_cover(source: Image, target: Vector2i) -> Image:
	var image := source.duplicate() as Image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var scale_factor := maxf(
		float(target.x) / float(image.get_width()),
		float(target.y) / float(image.get_height())
	)

	var new_size := Vector2i(
		maxi(target.x, ceili(image.get_width() * scale_factor)),
		maxi(target.y, ceili(image.get_height() * scale_factor))
	)
	image.resize(new_size.x, new_size.y, Image.INTERPOLATE_LANCZOS)

	var crop_offset := (new_size - target) / 2
	return image.get_region(Rect2i(crop_offset, target))


# =========================================================
# ПОКАЗ АВАТАРА И БАННЕРА
# =========================================================

func _set_avatar_texture(texture: Texture2D) -> void:
	_avatar_texture = texture
	_show_texture(_profile_avatar_rect, _avatar_texture, _avatar_placeholder_color)


func _set_banner_texture(texture: Texture2D) -> void:
	_banner_texture = texture
	_show_texture(_profile_banner_rect, _banner_texture, _banner_placeholder_color)


func _show_texture(rect: TextureRect, texture: Texture2D, placeholder_color: Color) -> void:
	if not is_instance_valid(rect):
		return
	if texture != null:
		rect.texture = texture
		rect.self_modulate = Color.WHITE
	else:
		rect.texture = _placeholder_texture
		rect.self_modulate = placeholder_color


func _refresh_profile_images() -> void:
	_show_texture(_profile_avatar_rect, _avatar_texture, _avatar_placeholder_color)
	_show_texture(_profile_banner_rect, _banner_texture, _banner_placeholder_color)


# =========================================================
# ПРОФИЛЬ — ДАННЫЕ
# =========================================================

func _on_profile_pressed() -> void:
	_refresh_profile()
	_profile_panel.visible = true


func _on_profile_close_pressed() -> void:
	_profile_panel.visible = false


func _refresh_profile() -> void:
	if not is_instance_valid(_profile_panel):
		return

	if is_instance_valid(_profile_nickname_label):
		_profile_nickname_label.text = "Никнейм: " + get_nickname()

	var active_profile: Dictionary = _get_stats_dictionary()
	var manager_device_id := str(active_profile.get("device_id", "")).strip_edges()
	if not manager_device_id.is_empty():
		_device_id = manager_device_id

	if is_instance_valid(_profile_id_label):
		_profile_id_label.text = "ID устройства:\n" + _device_id

	var playtime_value: Variant = _get_profile_stat(
		["total_playtime_seconds","total_play_time_seconds","playtime_seconds",
		"time_played_seconds","total_seconds_played","total_playtime","total_play_time","playtime"],
		["get_total_playtime_seconds","get_total_play_time_seconds",
		"get_playtime_seconds","get_total_playtime"], 0
	)
	var bot_games: int = int(_get_profile_stat(
		["games_vs_bot","bot_games","games_bot","total_bot_games","games_against_bot"],
		["get_games_vs_bot","get_bot_games","get_bot_games_count"], 0
	))
	var bot_wins: int = int(_get_profile_stat(
		["wins_vs_bot","bot_wins","wins_bot","wins_against_bot"],
		["get_wins_vs_bot","get_bot_wins","get_bot_wins_count"], 0
	))
	var online_games: int = int(_get_profile_stat(
		["games_online","online_games","lan_games","total_online_games","games_lan","network_games"],
		["get_games_online","get_online_games","get_online_games_count"], 0
	))
	var online_wins: int = int(_get_profile_stat(
		["wins_online","online_wins","lan_wins","wins_lan"],
		["get_wins_online","get_online_wins","get_online_wins_count"], 0
	))

	if is_instance_valid(_profile_stats_label):
		_profile_stats_label.text = (
			"ОБЩАЯ СТАТИСТИКА\n"
			+ "Время в игре: " + _format_playtime(playtime_value) + "\n\n"
			+ "ИГРА ПРОТИВ БОТА\n"
			+ "Матчей: " + str(bot_games) + "\n"
			+ "Побед: " + str(bot_wins) + "\n\n"
			+ "СЕТЕВАЯ ИГРА\n"
			+ "Матчей: " + str(online_games) + "\n"
			+ "Побед: " + str(online_wins)
		)


func _get_profile_stat(property_names: Array, method_names: Array, default_value: Variant = 0) -> Variant:
	if not is_instance_valid(_profile_save_manager):
		return default_value

	for property_info in _profile_save_manager.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name in property_names:
			var value: Variant = _profile_save_manager.get(property_name)
			if value != null:
				return value

	var stats_dictionary: Dictionary = _get_stats_dictionary()
	for key in property_names:
		if stats_dictionary.has(key):
			return stats_dictionary[key]

	for method_name in method_names:
		if _profile_save_manager.has_method(method_name):
			var result: Variant = _profile_save_manager.call(method_name)
			if result != null:
				return result

	return default_value


func _get_stats_dictionary() -> Dictionary:
	if not is_instance_valid(_profile_save_manager):
		return {}

	if _profile_save_manager.has_method("get_profile"):
		var profile_result: Variant = _profile_save_manager.call("get_profile")
		if profile_result is Dictionary:
			return profile_result

	for property_info in _profile_save_manager.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name in ["profile_stats","game_stats","statistics","stats","_stats","_profile"]:
			var value: Variant = _profile_save_manager.get(property_name)
			if value is Dictionary:
				return value

	for method_name in ["get_profile_stats","get_statistics","get_stats"]:
		if _profile_save_manager.has_method(method_name):
			var result: Variant = _profile_save_manager.call(method_name)
			if result is Dictionary:
				return result

	return {}


func _format_playtime(value: Variant) -> String:
	var total_seconds: float = 0.0

	if value is String:
		var string_value: String = value.strip_edges()
		if string_value.is_empty():
			return "0 мин"
		if string_value.is_valid_int() or string_value.is_valid_float():
			total_seconds = float(string_value)
		else:
			return string_value
	else:
		total_seconds = float(value)

	total_seconds = maxf(total_seconds, 0.0)
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int(fmod(total_seconds, 3600.0) / 60.0)
	var seconds: int = int(fmod(total_seconds, 60.0))

	if hours > 0:
		return "%d ч %d мин" % [hours, minutes]
	if minutes > 0:
		return "%d мин" % minutes
	return "%d сек" % seconds


# =========================================================
# НИКНЕЙМ
# =========================================================

func _setup_nickname_input() -> void:
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = "ВАШ НИКНЕЙМ:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#A0A5B5"))
	name_box.add_child(label)

	name_input = LineEdit.new()
	name_input.text = current_nickname
	name_input.placeholder_text = "Введите ваш ник..."
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.custom_minimum_size = Vector2(0, 44)
	name_input.max_length = 16
	name_input.add_theme_font_size_override("font_size", 16)
	name_input.text_changed.connect(_on_nickname_changed)
	name_box.add_child(name_input)

	main_container.add_child(name_box)
	main_container.move_child(name_box, 0)


func _on_nickname_changed(new_text: String) -> void:
	current_nickname = new_text.strip_edges()
	if current_nickname.is_empty():
		current_nickname = "Игрок"
	_save_nickname()
	if (
		is_instance_valid(_profile_save_manager)
		and _profile_save_manager.has_method("set_nickname")
	):
		_profile_save_manager.call("set_nickname", current_nickname)
	nickname_changed.emit(current_nickname)
	_refresh_profile()


func _save_nickname() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("player", "nickname", current_nickname)
	config.save(SAVE_PATH)


func _load_nickname() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		current_nickname = config.get_value("player", "nickname", "Игрок")
	if current_nickname.strip_edges().is_empty():
		current_nickname = "Игрок"


func get_nickname() -> String:
	return current_nickname if not current_nickname.is_empty() else "Игрок"


# =========================================================
# ID УСТРОЙСТВА
# =========================================================

func _load_device_id() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_device_id = str(config.get_value("player", "device_id", ""))
	if _device_id.is_empty():
		_device_id = _generate_device_id()
		_save_device_id()


func _generate_device_id() -> String:
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	if bytes.size() == 16:
		var hex_parts: PackedStringArray = PackedStringArray()
		for byte_value in bytes:
			hex_parts.append("%02x" % int(byte_value))
		return "-".join(hex_parts)
	return "%s-%s-%s" % [str(Time.get_unix_time_from_system()), str(randi()), str(randi())]


func _save_device_id() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("player", "device_id", _device_id)
	config.save(SAVE_PATH)


# =========================================================
# ФОН
# =========================================================

func _ensure_background_exists() -> void:
	if has_node("%ColorRect"):
		_bg_rect = get_node("%ColorRect") as ColorRect
	elif has_node("%Background"):
		_bg_rect = get_node("%Background") as ColorRect
	else:
		for child in get_children():
			if child is ColorRect:
				_bg_rect = child as ColorRect
				break

	if not _bg_rect:
		_bg_rect = ColorRect.new()
		_bg_rect.name = "Background"
		add_child(_bg_rect)

	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	move_child(_bg_rect, 0)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


# =========================================================
# ТЕМЫ
# =========================================================

func _init_theme_manager() -> void:
	_theme_mgr = get_node_or_null("/root/ThemeManager")
	if not _theme_mgr:
		_theme_mgr = get_tree().get_first_node_in_group("theme_manager")

	if _theme_mgr:
		if _theme_mgr.has_signal("theme_changed"):
			if not _theme_mgr.is_connected("theme_changed", _on_theme_changed):
				_theme_mgr.connect("theme_changed", _on_theme_changed)
		_refresh_theme()
	else:
		_apply_default_styles()


func _on_theme_changed(_new_theme) -> void:
	_refresh_theme()


func _refresh_theme() -> void:
	if not _theme_mgr or not _theme_mgr.has_method("get_theme_data"):
		return
	var current_theme = _theme_mgr.get("current_theme")
	if current_theme == null:
		return
	apply_theme(_theme_mgr.call("get_theme_data", current_theme))


# =========================================================
# ГЛАВНОЕ МЕНЮ
# =========================================================

func open_menu() -> void:
	visible = true
	show_main_section()
	_refresh_theme()


func hide_menu() -> void:
	visible = false


func show_main_section() -> void:
	main_container.visible = true
	mode_container.visible = false


func show_mode_section() -> void:
	main_container.visible = false
	mode_container.visible = true


func _setup_campaign_button() -> void:
	if _campaign_button != null or mode_container == null or vs_bot_button == null:
		return
	_campaign_button = Button.new()
	_campaign_button.name = "CampaignButton"
	mode_container.add_child(_campaign_button)
	mode_container.move_child(_campaign_button, vs_bot_button.get_index())
	_campaign_button.pressed.connect(_on_campaign_pressed)
	_style_button(_campaign_button, "КАМПАНИЯ", Color("#F4C542"), Color("#FFD966"), Color("#C9A227"), Color("#2b2b2b"))


func _on_campaign_pressed() -> void:
	campaign_requested.emit()


func _connect_signals() -> void:
	_setup_campaign_button()
	_bind_button(play_button, _on_play_pressed)
	if settings_button:
		_bind_button(settings_button, _on_settings_pressed)
	_bind_button(exit_button, _on_exit_pressed)
	_bind_button(local_pvp_button, _on_local_pvp_pressed)
	_bind_button(vs_bot_button, _on_vs_bot_pressed)
	if lan_pvp_button:
		_bind_button(lan_pvp_button, _on_lan_pvp_pressed)
	else:
		push_warning("Кнопка сетевой игры не найдена.")
	_bind_button(back_button, _on_back_pressed)


func _bind_button(btn: Button, method: Callable) -> void:
	if not btn:
		return
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
	btn.pressed.connect(method)


func _on_play_pressed() -> void:
	show_mode_section()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_local_pvp_pressed() -> void:
	mode_selected.emit(Enums.GameMode.LOCAL_PVP)


func _on_vs_bot_pressed() -> void:
	mode_selected.emit(Enums.GameMode.VS_BOT)


func _on_lan_pvp_pressed() -> void:
	mode_selected.emit(Enums.GameMode.LAN_PVP)


func _on_back_pressed() -> void:
	show_main_section()


# =========================================================
# ПРИМЕНЕНИЕ ТЕМЫ
# =========================================================

func apply_theme(theme_data: Dictionary) -> void:
	if _bg_rect:
		_bg_rect.color = theme_data.get("bg_color", Color("#0B1220"))

	var text_col: Color = theme_data.get("text_color", Color.WHITE)
	var btn_bg: Color = theme_data.get("cell_bg", Color("#18243A"))
	var btn_hover: Color = theme_data.get("panel_bg", Color("#121C2F"))
	var btn_pressed: Color = theme_data.get("panel_border", Color("#3B5275"))

	_selector_item_bg = theme_data.get("bg_color", Color("#0B1220"))
	_selector_item_hover = btn_bg
	_selector_item_border = btn_pressed
	_selector_item_text = text_col

	_style_button(play_button, "ИГРАТЬ", Color("#1E88E5"), Color("#2196F3"), Color("#1565C0"), Color.WHITE)
	if settings_button:
		_style_button(settings_button, "НАСТРОЙКИ", btn_bg, btn_hover, btn_pressed, text_col)
	_style_button(exit_button, "ВЫХОД", btn_bg, btn_hover, btn_pressed, text_col)
	_style_button(local_pvp_button, "ДВА ИГРОКА (НА ОДНОМ ЭКРАНЕ)", Color("#1E88E5"), Color("#2196F3"), Color("#1565C0"), Color.WHITE)
	_style_button(vs_bot_button, "ИГРА С БОТОМ", Color("#2E7D32"), Color("#388E3C"), Color("#1B5E20"), Color.WHITE)
	if lan_pvp_button:
		_style_button(lan_pvp_button, "СЕТЕВАЯ ИГРА (LAN)", Color("#8E24AA"), Color("#AB47BC"), Color("#6A1B9A"), Color.WHITE)
	_style_button(back_button, "НАЗАД", btn_bg, btn_hover, btn_pressed, text_col)

	if name_input:
		var input_style := StyleBoxFlat.new()
		input_style.bg_color = btn_bg
		input_style.border_color = btn_pressed
		input_style.set_border_width_all(2)
		input_style.set_corner_radius_all(10)
		name_input.add_theme_stylebox_override("normal", input_style)
		name_input.add_theme_stylebox_override("focus", input_style)
		name_input.add_theme_color_override("font_color", text_col)

	if is_instance_valid(_profile_button):
		_style_button(_profile_button, "ПРОФИЛЬ", btn_bg, btn_hover, btn_pressed, text_col)

	if is_instance_valid(_profile_panel):
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = theme_data.get("panel_bg", Color("#121C2F"))
		panel_style.border_color = btn_pressed
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(14)
		panel_style.set_content_margin_all(20)
		_profile_panel.add_theme_stylebox_override("panel", panel_style)

	if is_instance_valid(_image_selector_panel):
		var selector_style := StyleBoxFlat.new()
		selector_style.bg_color = theme_data.get("panel_bg", Color("#121C2F"))
		selector_style.border_color = btn_pressed
		selector_style.set_border_width_all(2)
		selector_style.set_corner_radius_all(14)
		selector_style.set_content_margin_all(16)
		_image_selector_panel.add_theme_stylebox_override("panel", selector_style)

	for lbl in [_profile_title, _profile_nickname_label, _profile_id_label, _profile_stats_label, _image_selector_title]:
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", text_col)

	if _avatar_material != null:
		_avatar_material.set_shader_parameter("border_color", btn_pressed)

	_avatar_placeholder_color = btn_bg
	_banner_placeholder_color = Color(btn_pressed, 0.35)
	_refresh_profile_images()

	if is_instance_valid(_profile_avatar_button):
		_style_button(_profile_avatar_button, "СМЕНИТЬ АВАТАР", btn_bg, btn_hover, btn_pressed, text_col)
	if is_instance_valid(_profile_banner_button):
		_style_button(_profile_banner_button, "СМЕНИТЬ БАННЕР", btn_bg, btn_hover, btn_pressed, text_col)
	if is_instance_valid(_profile_reset_button):
		_style_button(_profile_reset_button, "СБРОС", btn_bg, btn_hover, btn_pressed, text_col)
	if is_instance_valid(_profile_close_button):
		_style_button(_profile_close_button, "ЗАКРЫТЬ", btn_bg, btn_hover, btn_pressed, text_col)

	if is_instance_valid(_image_selector_close_button):
		_style_button(_image_selector_close_button, "ЗАКРЫТЬ", btn_bg, btn_hover, btn_pressed, text_col)
		_image_selector_close_button.custom_minimum_size = Vector2(0.0, 44.0)
		_image_selector_close_button.add_theme_font_size_override("font_size", 14)

	if is_instance_valid(_image_selector_grid):
		for child in _image_selector_grid.get_children():
			if child is Button:
				_style_image_selector_button(child as Button)


func _apply_default_styles() -> void:
	apply_theme({
		"bg_color": Color("#0B1220"),
		"text_color": Color("#FFFFFF"),
		"cell_bg": Color("#18243A"),
		"panel_bg": Color("#121C2F"),
		"panel_border": Color("#3B5275")
	})


func _style_button(
	btn: Button, text_val: String,
	base_color: Color, hover_color: Color, pressed_color: Color, font_color: Color
) -> void:
	if not btn:
		return
	btn.text = text_val
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_color_override("font_color", font_color)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.set_corner_radius_all(10)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = hover_color

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = pressed_color

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
