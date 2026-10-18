class_name NetworkModal
extends Control

signal host_requested(room_name: String)
signal join_requested(room_name: String)
signal start_game_requested(first_player: Enums.Player)
signal cancelled

const ROOMS_URL: String = "https://meldonlineserver.onrender.com/api/rooms"
const ROOMS_REFRESH_SECONDS: float = 5.0
const ROOMS_REQUEST_TIMEOUT: float = 10.0

const MAX_PLAYERS: int = 5

var center_container: CenterContainer
var panel_container: PanelContainer
var title_label: Label
var status_label: Label
var cancel_button: Button

var connection_view: VBoxContainer
var host_room_input: LineEdit
var host_button: Button
var join_room_input: LineEdit
var join_button: Button

var rooms_column: HBoxContainer
var rooms_view: VBoxContainer
var rooms_title_label: Label
var refresh_button: Button
var rooms_scroll: ScrollContainer
var rooms_list: VBoxContainer

var lobby_view: VBoxContainer
var room_title_label: Label
var slots_container: VBoxContainer
var first_turn_option: OptionButton
var start_game_button: Button

var _bg_overlay: ColorRect
var _main_box: VBoxContainer
var _content_row: HBoxContainer
var _current_theme: Dictionary

var _rooms_http: HTTPRequest
var _rooms_timer: Timer
var _rooms_request_in_flight: bool = false
var _rooms_loaded: bool = false
var _rooms_data: Array = []


func _ready() -> void:
	_build_ui_layout()
	_connect_signals()
	_apply_default_styles()
	close()


func _build_ui_layout() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	for child in get_children():
		child.queue_free()

	_bg_overlay = ColorRect.new()
	_bg_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_bg_overlay.color = Color(0.05, 0.07, 0.1, 0.75)
	add_child(_bg_overlay)

	center_container = CenterContainer.new()
	center_container.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center_container)

	panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(460, 0)
	center_container.add_child(panel_container)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
	panel_container.add_child(margin_container)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 14)
	margin_container.add_child(_main_box)

	title_label = Label.new()
	title_label.text = "СЕТЕВАЯ ИГРА (ОНЛАЙН)"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	_main_box.add_child(title_label)

	# Основной ряд: слева форма / лобби, справа список открытых комнат.
	_content_row = HBoxContainer.new()
	_content_row.add_theme_constant_override("separation", 20)
	_main_box.add_child(_content_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(400, 0)
	left_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_content_row.add_child(left_column)

	# --- 1. ЭКРАН СОЗДАНИЯ И ПОИСКА ---
	connection_view = VBoxContainer.new()
	connection_view.add_theme_constant_override("separation", 12)
	left_column.add_child(connection_view)

	# Секция создания
	var host_label := Label.new()
	host_label.text = "Создать новую комнату:"
	host_label.add_theme_font_size_override("font_size", 14)
	host_label.add_theme_color_override("font_color", Color("#A0A5B5"))
	connection_view.add_child(host_label)

	host_room_input = LineEdit.new()
	host_room_input.placeholder_text = "Название вашей комнаты..."
	host_room_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	host_room_input.custom_minimum_size = Vector2(0, 44)
	host_room_input.max_length = 20
	connection_view.add_child(host_room_input)

	host_button = Button.new()
	host_button.text = "Создать комнату"
	connection_view.add_child(host_button)

	var separator := HSeparator.new()
	connection_view.add_child(separator)

	# Секция подключения
	var join_label := Label.new()
	join_label.text = "Войти по названию:"
	join_label.add_theme_font_size_override("font_size", 14)
	join_label.add_theme_color_override("font_color", Color("#A0A5B5"))
	connection_view.add_child(join_label)

	join_room_input = LineEdit.new()
	join_room_input.placeholder_text = "Введите название комнаты..."
	join_room_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_room_input.custom_minimum_size = Vector2(0, 44)
	join_room_input.max_length = 20
	connection_view.add_child(join_room_input)

	join_button = Button.new()
	join_button.text = "Найти и войти"
	connection_view.add_child(join_button)

	# --- 2. ЭКРАН ЛОББИ ---
	lobby_view = VBoxContainer.new()
	lobby_view.add_theme_constant_override("separation", 12)
	lobby_view.visible = false
	left_column.add_child(lobby_view)

	room_title_label = Label.new()
	room_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_title_label.add_theme_font_size_override("font_size", 18)
	room_title_label.add_theme_color_override("font_color", Color("#FFCA28"))
	lobby_view.add_child(room_title_label)

	var lobby_subtitle := Label.new()
	lobby_subtitle.text = "Участники комнаты (до 5 чел):"
	lobby_subtitle.add_theme_font_size_override("font_size", 14)
	lobby_view.add_child(lobby_subtitle)

	slots_container = VBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 8)
	lobby_view.add_child(slots_container)

	var turn_box := HBoxContainer.new()
	turn_box.name = "TurnBox"
	var turn_lbl := Label.new()
	turn_lbl.text = "Первый ход:"
	turn_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	turn_box.add_child(turn_lbl)

	first_turn_option = OptionButton.new()
	first_turn_option.add_item("Хост (Игрок 1)", 0)
	first_turn_option.add_item("Гость (Игрок 2)", 1)
	first_turn_option.custom_minimum_size = Vector2(160, 38)
	turn_box.add_child(first_turn_option)
	lobby_view.add_child(turn_box)

	start_game_button = Button.new()
	start_game_button.text = "НАЧАТЬ ИГРУ"
	lobby_view.add_child(start_game_button)

	# --- 3. СПИСОК ОТКРЫТЫХ КОМНАТ ---
	rooms_column = HBoxContainer.new()
	rooms_column.add_theme_constant_override("separation", 20)
	_content_row.add_child(rooms_column)

	var rooms_separator := VSeparator.new()
	rooms_column.add_child(rooms_separator)

	rooms_view = VBoxContainer.new()
	rooms_view.custom_minimum_size = Vector2(380, 0)
	rooms_view.size_flags_horizontal = SIZE_EXPAND_FILL
	rooms_view.add_theme_constant_override("separation", 12)
	rooms_column.add_child(rooms_view)

	var rooms_header := HBoxContainer.new()
	rooms_header.add_theme_constant_override("separation", 8)
	rooms_view.add_child(rooms_header)

	rooms_title_label = Label.new()
	rooms_title_label.text = "Открытые комнаты:"
	rooms_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	rooms_title_label.add_theme_font_size_override("font_size", 14)
	rooms_title_label.add_theme_color_override("font_color", Color("#A0A5B5"))
	rooms_header.add_child(rooms_title_label)

	refresh_button = Button.new()
	refresh_button.text = "Обновить"
	rooms_header.add_child(refresh_button)

	rooms_scroll = ScrollContainer.new()
	rooms_scroll.custom_minimum_size = Vector2(0, 280)
	rooms_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	rooms_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rooms_view.add_child(rooms_scroll)

	rooms_list = VBoxContainer.new()
	rooms_list.size_flags_horizontal = SIZE_EXPAND_FILL
	rooms_list.add_theme_constant_override("separation", 8)
	rooms_scroll.add_child(rooms_list)

	# --- ОБЩИЕ ЭЛЕМЕНТЫ ---
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_box.add_child(status_label)

	cancel_button = Button.new()
	cancel_button.text = "Отмена"
	_main_box.add_child(cancel_button)

	# --- СЕТЬ ДЛЯ СПИСКА КОМНАТ ---
	_rooms_http = HTTPRequest.new()
	_rooms_http.timeout = ROOMS_REQUEST_TIMEOUT
	add_child(_rooms_http)

	_rooms_timer = Timer.new()
	_rooms_timer.wait_time = ROOMS_REFRESH_SECONDS
	_rooms_timer.one_shot = false
	_rooms_timer.autostart = false
	add_child(_rooms_timer)


func _connect_signals() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	_rooms_http.request_completed.connect(_on_rooms_request_completed)
	_rooms_timer.timeout.connect(_on_rooms_timer_timeout)


func open() -> void:
	visible = true
	connection_view.visible = true
	lobby_view.visible = false
	rooms_column.visible = true
	set_status("")
	_start_rooms_polling()

func close() -> void:
	visible = false
	_stop_rooms_polling()

func show_lobby_view(is_host: bool, room_name: String) -> void:
	connection_view.visible = false
	lobby_view.visible = true
	rooms_column.visible = false
	_stop_rooms_polling()
	room_title_label.text = "Комната: \"%s\"" % room_name
	start_game_button.visible = is_host
	if lobby_view.has_node("TurnBox"):
		lobby_view.get_node("TurnBox").visible = is_host

func update_lobby_slots(members: Array) -> void:
	for child in slots_container.get_children():
		child.queue_free()

	for i in range(MAX_PLAYERS):
		var p_card := PanelContainer.new()
		p_card.custom_minimum_size = Vector2(0, 42)

		var card_style := StyleBoxFlat.new()
		card_style.set_corner_radius_all(8)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12

		var hbox := HBoxContainer.new()

		var role_label := Label.new()
		role_label.add_theme_font_size_override("font_size", 14)

		var name_label := Label.new()
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.add_theme_font_size_override("font_size", 14)

		if i < members.size():
			var info: Dictionary = members[i]
			card_style.bg_color = Color("#232838")
			card_style.border_color = Color("#454D66")
			card_style.set_border_width_all(1)

			match info.get("role", Enums.LobbyRole.SPECTATOR):
				Enums.LobbyRole.PLAYER_1:
					role_label.text = "🔵 Игрок 1 (Хост)"
				Enums.LobbyRole.PLAYER_2:
					role_label.text = "🔴 Игрок 2"
				Enums.LobbyRole.SPECTATOR:
					role_label.text = "👁 Наблюдатель"

			name_label.text = info.get("name", "Игрок")
		else:
			card_style.bg_color = Color("#14161F")
			role_label.text = "Свободный слот"
			role_label.add_theme_color_override("font_color", Color("#555A6E"))
			name_label.text = "—"
			name_label.add_theme_color_override("font_color", Color("#555A6E"))

		p_card.add_theme_stylebox_override("panel", card_style)
		hbox.add_child(role_label)
		hbox.add_child(name_label)
		p_card.add_child(hbox)
		slots_container.add_child(p_card)


func set_status(text: String, is_error: bool = false) -> void:
	if status_label:
		status_label.text = text
		status_label.add_theme_color_override("font_color", Color("#FF5252") if is_error else Color("#FFCA28"))

	if is_error and visible and connection_view and connection_view.visible:
		refresh_rooms()

func _start_rooms_polling() -> void:
	if _rooms_timer == null:
		return

	refresh_rooms(true)
	_rooms_timer.start()


func _stop_rooms_polling() -> void:
	if _rooms_timer:
		_rooms_timer.stop()

	if _rooms_http:
		_rooms_http.cancel_request()

	_rooms_request_in_flight = false


func refresh_rooms(show_loading: bool = false) -> void:
	if _rooms_http == null or _rooms_request_in_flight:
		return

	if connection_view == null or not connection_view.visible:
		return

	var error := _rooms_http.request(
		ROOMS_URL,
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_rooms_loaded = false
		_show_rooms_message("Не удалось запросить список комнат.", true)
		return

	_rooms_request_in_flight = true

	if show_loading and not _rooms_loaded:
		_show_rooms_message("Загрузка списка комнат...")


func _on_refresh_pressed() -> void:
	refresh_rooms(true)


func _on_rooms_timer_timeout() -> void:
	refresh_rooms()


func _on_rooms_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_rooms_request_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_rooms_loaded = false
		_rooms_data.clear()
		_show_rooms_message("Сервер недоступен. Попробуйте обновить список чуть позже.", true)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if (
		not (parsed is Dictionary)
		or not bool(parsed.get("ok", false))
		or not (parsed.get("rooms") is Array)
	):
		_rooms_loaded = false
		_rooms_data.clear()
		_show_rooms_message("Сервер вернул некорректный список комнат.", true)
		return

	_rooms_data = parsed["rooms"]
	_rooms_loaded = true
	_rebuild_rooms_list()


func _clear_rooms_list() -> void:
	for child in rooms_list.get_children():
		rooms_list.remove_child(child)
		child.queue_free()


func _show_rooms_message(text: String, is_error: bool = false) -> void:
	_clear_rooms_list()

	var message := Label.new()
	message.text = text
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = SIZE_EXPAND_FILL
	message.custom_minimum_size = Vector2(0, 80)
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override(
		"font_color",
		Color("#FF5252") if is_error else Color("#A0A5B5")
	)
	rooms_list.add_child(message)


func _rebuild_rooms_list() -> void:
	if rooms_list == null:
		return

	if _rooms_data.is_empty():
		_show_rooms_message("Открытых комнат пока нет.\nСоздайте свою — она появится здесь.")
		return

	_clear_rooms_list()

	for item in _rooms_data:
		if not (item is Dictionary):
			continue

		var room_info: Dictionary = item
		var code := str(room_info.get("code", ""))

		if code.is_empty():
			continue

		var host_name := str(room_info.get("host_name", "Игрок"))
		var players := int(room_info.get("players", 1))
		var max_players := int(room_info.get("max_players", 2))

		rooms_list.add_child(_create_room_button(code, host_name, players, max_players))

	if rooms_list.get_child_count() == 0:
		_show_rooms_message("Открытых комнат пока нет.\nСоздайте свою — она появится здесь.")


func _create_room_button(code: String, host_name: String, players: int, max_players: int) -> Button:
	var btn := Button.new()
	btn.text = "%s   (%d/%d)\nХост: %s" % [code, players, max_players, host_name]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.custom_minimum_size = Vector2(0, 58)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.tooltip_text = "Нажмите, чтобы войти в комнату «%s»" % code
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 15)
	_style_room_button(btn)
	btn.pressed.connect(_on_room_button_pressed.bind(code))
	return btn


func _style_room_button(btn: Button) -> void:
	var bg: Color = _current_theme.get("cell_bg", Color("#222531"))
	var border: Color = _current_theme.get("panel_border", Color("#333846"))
	var text_col: Color = _current_theme.get("text_color", Color.WHITE)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg
	style_normal.border_color = border
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(10)
	style_normal.content_margin_left = 14
	style_normal.content_margin_right = 14
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = bg.lightened(0.12)
	style_hover.border_color = Color("#388E3C")
	style_hover.set_border_width_all(2)

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = bg.darkened(0.15)
	style_pressed.border_color = Color("#2E7D32")
	style_pressed.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)


func _on_room_button_pressed(code: String) -> void:
	set_status("Подключение к комнате «%s»..." % code)
	join_requested.emit(code)

func _on_host_pressed() -> void:
	var room_name := host_room_input.text.strip_edges() if host_room_input else ""
	if room_name.is_empty():
		set_status("Введите название комнаты!", true)
		return
	host_requested.emit(room_name)


func _on_join_pressed() -> void:
	var room_name := join_room_input.text.strip_edges() if join_room_input else ""
	if room_name.is_empty():
		set_status("Введите название комнаты для поиска!", true)
		return
	join_requested.emit(room_name)


func _on_start_game_pressed() -> void:
	var chosen_first := Enums.Player.PLAYER_1 if first_turn_option.selected == 0 else Enums.Player.PLAYER_2
	start_game_requested.emit(chosen_first)


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()

func _apply_default_styles() -> void:
	apply_theme({
		"panel_bg": Color("#1A1C23"),
		"panel_border": Color("#333846"),
		"cell_bg": Color("#222531"),
		"cell_border": Color("#333846"),
		"bg_color": Color("#12131C"),
		"text_color": Color.WHITE,
		"overlay_color": Color(0.05, 0.07, 0.1, 0.75)
	})


func apply_theme(theme_data: Dictionary) -> void:
	_current_theme = theme_data
	if _bg_overlay: _bg_overlay.color = theme_data.get("overlay_color", Color(0.05, 0.07, 0.1, 0.75))

	if panel_container:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = theme_data.get("panel_bg", Color("#1A1C23"))
		panel_style.border_color = theme_data.get("panel_border", Color("#333846"))
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(16)
		panel_container.add_theme_stylebox_override("panel", panel_style)

	var text_col: Color = theme_data.get("text_color", Color.WHITE)
	if title_label: title_label.add_theme_color_override("font_color", text_col)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = theme_data.get("cell_bg", Color("#222531"))
	input_style.border_color = theme_data.get("cell_border", Color("#333846"))
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(10)
	input_style.content_margin_left = 16

	if host_room_input:
		host_room_input.add_theme_stylebox_override("normal", input_style)
		host_room_input.add_theme_stylebox_override("focus", input_style)
		host_room_input.add_theme_color_override("font_color", text_col)

	if join_room_input:
		join_room_input.add_theme_stylebox_override("normal", input_style)
		join_room_input.add_theme_stylebox_override("focus", input_style)
		join_room_input.add_theme_color_override("font_color", text_col)

	_style_button(host_button, Color("#1E88E5"), Color("#2196F3"), Color("#1565C0"), "Создать комнату", Color.WHITE, 46)
	_style_button(join_button, Color("#2E7D32"), Color("#388E3C"), Color("#1B5E20"), "Найти и войти", Color.WHITE, 46)
	_style_button(start_game_button, Color("#8E24AA"), Color("#AB47BC"), Color("#6A1B9A"), "НАЧАТЬ ИГРУ", Color.WHITE, 50)

	var cancel_bg: Color = theme_data.get("cell_bg", Color("#2C303E"))
	_style_button(cancel_button, cancel_bg, theme_data.get("panel_border", Color("#3A3F52")), theme_data.get("bg_color", Color("#1F222C")), "Отмена", text_col, 44)

	_style_button(refresh_button, cancel_bg, theme_data.get("panel_border", Color("#3A3F52")), theme_data.get("bg_color", Color("#1F222C")), "Обновить", text_col, 36)
	if refresh_button:
		refresh_button.size_flags_horizontal = SIZE_SHRINK_END
		refresh_button.custom_minimum_size = Vector2(110, 36)
		refresh_button.add_theme_font_size_override("font_size", 14)

	if _rooms_loaded:
		_rebuild_rooms_list()


func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color, text: String, font_color: Color, min_height: int = 46) -> void:
	if not btn: return
	btn.text = text
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
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
