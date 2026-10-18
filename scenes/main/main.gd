class_name Main
extends Node2D

# Цвета статуса хода для сетевых игроков.
const PLAYER_1_TURN_COLOR: Color = Color("#4DA3FF")
const PLAYER_2_TURN_COLOR: Color = Color("#FF5A5F")

@onready var board_view: BoardView = %BoardView
@onready var hud: HUD = %HUD
@onready var result_screen: ResultScreen = %ResultScreen
@onready var main_menu: MainMenu = %MainMenu

var bot_settings_modal: BotSettingsModal
var network_modal: NetworkModal
var settings_modal: SettingsModal
var pause_modal: PauseModal
var pause_button: Button

var board_data: BoardData
var turn_manager: TurnManager
var pattern_detector: PatternDetector
var score_manager: ScoreManager
var audio_manager: AudioManager
var theme_manager: ThemeManager
var save_manager: SaveManager

var easy_bot: EasyBot
var medium_bot: MediumBot
var hard_bot: HardBot

var current_mode: Enums.GameMode = Enums.GameMode.LOCAL_PVP
var bot_difficulty: Enums.BotDifficulty = Enums.BotDifficulty.EASY
var human_player: Enums.Player = Enums.Player.PLAYER_1
var bot_player: Enums.Player = Enums.Player.NONE

# Никнеймы участников текущего матча.
var player1_name: String = "Игрок 1"
var player2_name: String = "Игрок 2"

# Название комнаты.
var current_room_name: String = ""

# Обычный WebSocket-клиент для JSON-протокола Node.js relay.
var ws_client: WebSocketPeer
const RELAY_SERVER_URL: String = "wss://meldonlineserver.onrender.com"

var is_host: bool = false
var local_net_player: Enums.Player = Enums.Player.NONE
var local_role: Enums.LobbyRole = Enums.LobbyRole.SPECTATOR
var network_peer_id: int = -1

var _ws_join_sent: bool = false
var _ws_was_open: bool = false
var _ws_attempting_connect: bool = false
var _ws_joined: bool = false
var _ws_connection_failed: bool = false
var _network_move_pending: bool = false
var _network_move_queue: Array[Dictionary] = []
var _processing_network_moves: bool = false
var _network_first_player: Enums.Player = Enums.Player.PLAYER_1

# Лобби: peer_id -> { "name": String, "role": Enums.LobbyRole }.
var lobby_members: Dictionary = {}

var is_game_over: bool = false


func _ready() -> void:
	theme_manager = ThemeManager.new()
	add_child(theme_manager)
	theme_manager.theme_changed.connect(_on_theme_changed)

	board_data = BoardData.new()
	turn_manager = TurnManager.new()
	pattern_detector = PatternDetector.new()
	score_manager = ScoreManager.new()

	audio_manager = AudioManager.new()
	add_child(audio_manager)

	# Локальный профиль, статистика и очередь офлайн-синхронизации.
	save_manager = SaveManager.new()
	save_manager.name = "SaveManagerRuntime"
	add_child(save_manager)
	
	# Подключаем локальный профиль к главному меню.
	if main_menu.has_method("setup_profile"):
		main_menu.setup_profile(save_manager)
	else:
		push_error("MainMenu.gd не содержит setup_profile(save_manager).")

	easy_bot = EasyBot.new()
	medium_bot = MediumBot.new()
	hard_bot = HardBot.new()

	_setup_pause_ui()

	board_view.cell_clicked.connect(_on_cell_clicked)
	turn_manager.turn_changed.connect(_on_turn_changed)
	score_manager.score_changed.connect(_on_score_changed)

	result_screen.rematch_requested.connect(_restart_game)
	result_screen.menu_requested.connect(_return_to_main_menu)
	main_menu.mode_selected.connect(_on_mode_selected)
	main_menu.settings_requested.connect(_on_open_settings)

	if has_node("%BotSettingsModal"):
		bot_settings_modal = get_node("%BotSettingsModal")
		bot_settings_modal.start_game_requested.connect(_on_bot_settings_confirmed)
		bot_settings_modal.cancelled.connect(main_menu.open_menu)

	if has_node("%NetworkModal"):
		network_modal = get_node("%NetworkModal")
		_connect_network_modal_signals()

	_on_theme_changed(theme_manager.current_theme)
	_return_to_main_menu()


func _connect_network_modal_signals() -> void:
	if not network_modal:
		return

	if not network_modal.host_requested.is_connected(_on_host_game):
		network_modal.host_requested.connect(_on_host_game)

	if not network_modal.join_requested.is_connected(_on_join_game):
		network_modal.join_requested.connect(_on_join_game)

	if not network_modal.start_game_requested.is_connected(_on_start_lan_game_from_lobby):
		network_modal.start_game_requested.connect(_on_start_lan_game_from_lobby)

	if not network_modal.cancelled.is_connected(_on_network_cancelled):
		network_modal.cancelled.connect(_on_network_cancelled)


func _process(_delta: float) -> void:
	if save_manager:
		save_manager.set_playtime_active(
			board_view.visible and not is_game_over and not get_tree().paused
		)

	_poll_network()


func _unhandled_input(event: InputEvent) -> void:
	if current_mode == Enums.GameMode.LAN_PVP:
		return

	if event.is_action_pressed("ui_cancel") or (
		event is InputEventKey
		and event.pressed
		and event.keycode == KEY_ESCAPE
	):
		if board_view.visible and not is_game_over:
			_toggle_pause()


func _setup_pause_ui() -> void:
	pause_modal = PauseModal.new()
	add_child(pause_modal)
	pause_modal.resume_requested.connect(_resume_game)
	pause_modal.quit_requested.connect(_return_to_main_menu)

	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	pause_button = Button.new()
	pause_button.text = "⏸"
	pause_button.custom_minimum_size = Vector2(44, 44)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -60
	pause_button.offset_top = 16
	pause_button.offset_right = -16
	pause_button.offset_bottom = 60
	pause_button.visible = false
	pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_button.pressed.connect(_toggle_pause)

	layer.add_child(pause_button)


func _toggle_pause() -> void:
	# Локальная пауза не должна рассинхронизировать сетевую игру.
	if current_mode == Enums.GameMode.LAN_PVP:
		return

	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	get_tree().paused = true
	if pause_modal:
		pause_modal.open()


func _resume_game() -> void:
	get_tree().paused = false
	if pause_modal:
		pause_modal.close()


func _return_to_main_menu() -> void:
	# Сохраняем игровое время, даже если матч покинули раньше окончания.
	if save_manager:
		save_manager.set_playtime_active(false)

		if board_view.visible and not is_game_over:
			save_manager.flush_playtime()

	get_tree().paused = false
	current_mode = Enums.GameMode.LOCAL_PVP

	if pause_modal:
		pause_modal.close()

	if pause_button:
		pause_button.visible = false

	_close_network()

	is_game_over = true
	board_view.visible = false
	hud.visible = false
	result_screen.hide_results()

	if bot_settings_modal:
		bot_settings_modal.close()

	if network_modal:
		network_modal.close()

	if settings_modal:
		settings_modal.close()

	main_menu.open_menu()


func _on_mode_selected(mode: Enums.GameMode) -> void:
	current_mode = mode

	match mode:
		Enums.GameMode.VS_BOT:
			if bot_settings_modal:
				main_menu.hide_menu()
				bot_settings_modal.open()
			else:
				_start_new_pvp_game()

		Enums.GameMode.LAN_PVP:
			# LAN_PVP есть в Enums.GameMode. Сначала гарантируем, что окно
			# сетевой игры найдено/создано, и только потом скрываем меню.
			if network_modal == null:
				var scene_path := "res://scenes/ui/network_modal.tscn"

				if not ResourceLoader.exists(scene_path):
					push_error("Не найдена сцена сетевого меню: " + scene_path)
					main_menu.open_menu()
					main_menu.show_mode_section()
					return

				var net_resource: Resource = load(scene_path)
				if not (net_resource is PackedScene):
					push_error("Ресурс сетевого меню не является PackedScene: " + scene_path)
					main_menu.open_menu()
					main_menu.show_mode_section()
					return

				var net_instance: Node = (net_resource as PackedScene).instantiate()
				if not (net_instance is NetworkModal):
					push_error("Корневой узел network_modal.tscn должен иметь скрипт NetworkModal.")
					net_instance.queue_free()
					main_menu.open_menu()
					main_menu.show_mode_section()
					return

				network_modal = net_instance as NetworkModal
				add_child(network_modal)
				_connect_network_modal_signals()

			if network_modal != null:
				main_menu.hide_menu()
				network_modal.open()

		Enums.GameMode.LOCAL_PVP:
			_start_new_pvp_game()


func _on_open_settings() -> void:
	if settings_modal == null:
		if has_node("%SettingsModal"):
			settings_modal = get_node("%SettingsModal")
		else:
			var settings_scene: PackedScene = load(
				"res://scenes/ui/settings_modal.tscn"
			)

			if settings_scene:
				settings_modal = settings_scene.instantiate() as SettingsModal
				add_child(settings_modal)

	if settings_modal:
		settings_modal.setup(theme_manager)

		if not settings_modal.closed.is_connected(main_menu.open_menu):
			settings_modal.closed.connect(main_menu.open_menu)

		main_menu.hide_menu()
		settings_modal.open()


func _on_theme_changed(_new_theme: Enums.ThemeStyle) -> void:
	var data := theme_manager.get_theme_data()
	RenderingServer.set_default_clear_color(data["bg_color"])

	if has_node("Background"):
		var bg_node := get_node("Background")

		if bg_node is ColorRect:
			(bg_node as ColorRect).color = data["bg_color"]

	if board_view and board_view.has_method("apply_theme"):
		board_view.apply_theme(data)

	if pause_modal:
		pause_modal.apply_theme(data)


# ============================================================
# СЕТЕВАЯ ЛОГИКА
# ============================================================

func _on_network_cancelled() -> void:
	_return_to_main_menu()


func _on_host_game(room_name: String) -> void:
	_close_network()

	current_mode = Enums.GameMode.LAN_PVP
	current_room_name = room_name.strip_edges()
	is_host = true
	local_net_player = Enums.Player.PLAYER_1
	local_role = Enums.LobbyRole.PLAYER_1
	human_player = Enums.Player.PLAYER_1
	lobby_members.clear()

	_connect_to_relay()


func _on_join_game(room_name: String) -> void:
	_close_network()

	current_mode = Enums.GameMode.LAN_PVP
	current_room_name = room_name.strip_edges()
	is_host = false
	local_net_player = Enums.Player.NONE
	local_role = Enums.LobbyRole.SPECTATOR
	lobby_members.clear()

	_connect_to_relay()


func _connect_to_relay() -> void:
	if current_room_name.is_empty():
		if network_modal:
			network_modal.set_status("Введите код комнаты.", true)
		return

	ws_client = WebSocketPeer.new()
	_ws_join_sent = false
	_ws_was_open = false
	_ws_attempting_connect = true
	_ws_joined = false
	_ws_connection_failed = false
	_network_move_pending = false
	_network_move_queue.clear()
	_processing_network_moves = false

	var error := ws_client.connect_to_url(RELAY_SERVER_URL)

	if error != OK:
		ws_client = null
		_ws_attempting_connect = false
		_ws_connection_failed = true

		if network_modal:
			network_modal.set_status(
				"Не удалось начать подключение: %s" % error_string(error),
				true
			)
		return

	if network_modal:
		network_modal.set_status("Подключение к облачному серверу...")


func _close_network() -> void:
	if ws_client != null:
		if ws_client.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			ws_client.close(1000, "Leaving room")

		ws_client = null

	_ws_join_sent = false
	_ws_was_open = false
	_ws_attempting_connect = false
	_ws_joined = false
	_ws_connection_failed = false
	_network_move_pending = false
	_network_move_queue.clear()
	_processing_network_moves = false

	lobby_members.clear()
	current_room_name = ""
	is_host = false
	network_peer_id = -1
	local_net_player = Enums.Player.NONE
	local_role = Enums.LobbyRole.SPECTATOR


func _poll_network() -> void:
	if ws_client == null:
		return

	ws_client.poll()
	var state := ws_client.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_ws_was_open = true
		_ws_attempting_connect = false

		# Отправляем join только после открытия WebSocket.
		if not _ws_join_sent:
			var join_payload := {
				"type": "join",
				"intent": "host" if is_host else "join",
				"room": current_room_name,
				"name": main_menu.get_nickname(),
				"avatar_b64": main_menu.get_avatar_base64()
			}

			if _send_network_message(join_payload):
				_ws_join_sent = true

		while ws_client != null and ws_client.get_available_packet_count() > 0:
			var packet: PackedByteArray = ws_client.get_packet()
			var packet_text := packet.get_string_from_utf8()
			var parsed = JSON.parse_string(packet_text)

			if parsed is Dictionary:
				_handle_network_message(parsed)
			else:
				push_warning(
					"Relay прислал некорректный JSON: %s" % packet_text
				)

	elif state == WebSocketPeer.STATE_CLOSED:
		if _ws_connection_failed:
			ws_client = null
			_ws_attempting_connect = false

		elif _ws_was_open:
			_handle_network_disconnected()

		elif _ws_attempting_connect:
			_ws_attempting_connect = false
			ws_client = null

			if network_modal:
				network_modal.set_status(
					"Соединение с сервером не удалось. Проверьте URL и доступность Render.",
					true
				)


func _send_network_message(data: Dictionary) -> bool:
	if (
		ws_client == null
		or ws_client.get_ready_state() != WebSocketPeer.STATE_OPEN
	):
		return false

	var error := ws_client.send_text(JSON.stringify(data))

	if error != OK:
		push_warning(
			"Не удалось отправить WebSocket-сообщение: %s"
			% error_string(error)
		)
		return false

	return true


func _handle_network_message(data: Dictionary) -> void:
	var message_type := str(data.get("type", ""))

	match message_type:
		"joined":
			_ws_joined = true
			_ws_connection_failed = false
			network_peer_id = int(data.get("peer_id", -1))
			current_room_name = str(data.get("room", current_room_name))
			local_role = _lobby_role_from_string(
				str(data.get("role", "spectator"))
			)
			_update_local_player_from_role()

			if network_modal:
				if is_host:
					network_modal.set_status(
						"Комната создана! Ожидание игроков..."
					)
					network_modal.show_lobby_view(true, current_room_name)
				else:
					network_modal.set_status("Вы подключились к комнате.")
					network_modal.show_lobby_view(false, current_room_name)

			var initial_members = data.get("members", [])

			if initial_members is Array:
				_apply_room_state(initial_members)

		"room_state":
			var members = data.get("members", [])

			if members is Array:
				_apply_room_state(members)

		"game_start":
			current_mode = Enums.GameMode.LAN_PVP
			_network_first_player = (
				int(data.get(
					"first_player",
					int(Enums.Player.PLAYER_1)
				)) as Enums.Player
			)
			player1_name = str(data.get("player1_name", "Игрок 1"))
			player2_name = str(data.get("player2_name", "Игрок 2"))
			_start_game(_network_first_player)

		"move":
			_network_move_queue.append(data)
			_process_network_move_queue()

		"player_left":
			var left_role := str(data.get("role", "spectator"))

			if (
				left_role in ["player1", "player2"]
				and not is_game_over
				and board_view.visible
			):
				_end_game()

			if network_modal and not board_view.visible:
				network_modal.set_status(
					"Игрок отключился от комнаты.",
					true
				)

		"room_closed":
			if network_modal:
				network_modal.set_status(
					"Создатель комнаты отключился.",
					true
				)

			_return_to_main_menu()

		"error":
			var error_message := str(
				data.get("message", "Неизвестная ошибка сервера.")
			)

			if network_modal:
				network_modal.set_status(error_message, true)

			if not _ws_joined:
				_ws_connection_failed = true

		"move_rejected":
			_network_move_pending = false

			if network_modal:
				network_modal.set_status(
					str(data.get("message", "Сервер отклонил ход.")),
					true
				)

		_:
			push_warning(
				"Неизвестное сообщение relay-сервера: %s" % message_type
			)


func _handle_network_disconnected() -> void:
	# После потери соединения сетевой матч продолжать нельзя.
	if ws_client == null:
		return

	ws_client = null
	_ws_joined = false
	_ws_was_open = false
	_ws_attempting_connect = false
	_network_move_pending = false

	_return_to_main_menu()


func _lobby_role_from_string(role_name: String) -> Enums.LobbyRole:
	match role_name:
		"player1":
			return Enums.LobbyRole.PLAYER_1
		"player2":
			return Enums.LobbyRole.PLAYER_2
		_:
			return Enums.LobbyRole.SPECTATOR


func _update_local_player_from_role() -> void:
	match local_role:
		Enums.LobbyRole.PLAYER_1:
			local_net_player = Enums.Player.PLAYER_1
		Enums.LobbyRole.PLAYER_2:
			local_net_player = Enums.Player.PLAYER_2
		_:
			local_net_player = Enums.Player.NONE


func _apply_room_state(members_data: Array) -> void:
	lobby_members.clear()
	var ui_members: Array = []
	main_menu.apply_peer_avatars(members_data)

	for item in members_data:
		if not (item is Dictionary):
			continue

		var member: Dictionary = item
		var peer_id := int(member.get("peer_id", -1))
		var member_name := str(member.get("name", "Игрок"))
		var role := _lobby_role_from_string(
			str(member.get("role", "spectator"))
		)

		if peer_id >= 0:
			lobby_members[peer_id] = {
				"name": member_name,
				"role": role
			}

		ui_members.append({
			"name": member_name,
			"role": role
		})

	if network_modal:
		network_modal.update_lobby_slots(ui_members)


func _on_start_lan_game_from_lobby(
	first_player: Enums.Player
) -> void:
	if not is_host:
		return

	if not _ws_joined:
		if network_modal:
			network_modal.set_status("Нет соединения с сервером.", true)
		return

	var p1_name := "Игрок 1"
	var p2_name := "Игрок 2"

	for peer_id in lobby_members:
		var info: Dictionary = lobby_members[peer_id]

		if info.get("role") == Enums.LobbyRole.PLAYER_1:
			p1_name = str(info.get("name", "Игрок 1"))
		elif info.get("role") == Enums.LobbyRole.PLAYER_2:
			p2_name = str(info.get("name", "Игрок 2"))

	_network_first_player = first_player

	var sent := _send_network_message({
		"type": "start_game",
		"first_player": int(first_player),
		"player1_value": int(Enums.Player.PLAYER_1),
		"player2_value": int(Enums.Player.PLAYER_2),
		"player1_name": p1_name,
		"player2_name": p2_name
	})

	if not sent and network_modal:
		network_modal.set_status(
			"Не удалось отправить команду запуска игры.",
			true
		)


func _process_network_move_queue() -> void:
	if _processing_network_moves:
		return

	_drain_network_move_queue()


func _drain_network_move_queue() -> void:
	if _processing_network_moves:
		return

	_processing_network_moves = true

	while not _network_move_queue.is_empty():
		var move_data: Dictionary = _network_move_queue.pop_front()

		if current_mode != Enums.GameMode.LAN_PVP or is_game_over:
			continue

		var player_value := int(
			move_data.get("player", int(turn_manager.current_player))
		)

		if player_value != int(turn_manager.current_player):
			push_warning(
				"Получен сетевой ход не для текущего игрока; пакет пропущен."
			)
			continue

		var coord := Vector2i(
			int(move_data.get("x", -1)),
			int(move_data.get("y", -1))
		)

		if (
			coord.x < 0
			or coord.y < 0
			or coord.x >= BoardData.GRID_SIZE
			or coord.y >= BoardData.GRID_SIZE
		):
			push_warning(
				"Relay прислал координаты вне поля: %s" % coord
			)
			continue

		await _execute_move(coord)

		if player_value == int(local_net_player):
			_network_move_pending = false

	_processing_network_moves = false


func _on_network_restart_requested() -> void:
	_send_network_message({"type": "restart"})


# ============================================================
# ИГРОВОЙ ПРОЦЕСС
# ============================================================

func _start_new_pvp_game() -> void:
	current_mode = Enums.GameMode.LOCAL_PVP
	human_player = Enums.Player.PLAYER_1
	bot_player = Enums.Player.NONE
	player1_name = main_menu.get_nickname()
	player2_name = "Игрок 2"

	_start_game(Enums.Player.PLAYER_1)


func _start_game(starting_player: Enums.Player) -> void:
	get_tree().paused = false
	is_game_over = false

	main_menu.hide_menu()

	if network_modal:
		network_modal.close()

	if bot_settings_modal:
		bot_settings_modal.close()

	if settings_modal:
		settings_modal.close()

	if pause_modal:
		pause_modal.close()

	if pause_button:
		# В LAN пауза отключена во избежание рассинхронизации.
		pause_button.visible = current_mode != Enums.GameMode.LAN_PVP

	result_screen.hide_results()
	board_view.visible = true
	hud.visible = true

	if save_manager:
		save_manager.set_playtime_active(true)

	if hud and hud.has_method("set_player_names"):
		hud.set_player_names(player1_name, player2_name)
	
		# Аватарки в HUD.
	if hud and hud.has_method("set_player_avatars"):
		var my_role := "player1" if local_net_player == Enums.Player.PLAYER_1 else "player2"
		var opp_role := "player2" if my_role == "player1" else "player1"

		var my_tex: Texture2D = null
		var my_avatar_b64 := main_menu.get_avatar_base64()
		if not my_avatar_b64.is_empty():
			my_tex = main_menu._texture_from_base64(my_avatar_b64)

		var opp_tex: Texture2D = main_menu.get_peer_avatar(opp_role)

		if current_mode == Enums.GameMode.LAN_PVP:
			if local_net_player == Enums.Player.PLAYER_1:
				hud.set_player_avatars(my_tex, opp_tex)
			else:
				hud.set_player_avatars(opp_tex, my_tex)
		else:
			# Локальный и бот — только своя аватарка слева.
			hud.set_player_avatars(my_tex, null)
	
	board_data.reset()
	turn_manager.reset()
	score_manager.reset()
	board_view.create_board()
	_on_theme_changed(theme_manager.current_theme)

	if starting_player == Enums.Player.PLAYER_2:
		turn_manager.next_turn()
	else:
		_on_turn_changed(Enums.Player.PLAYER_1)


func _on_cell_clicked(coord: Vector2i) -> void:
	if is_game_over or get_tree().paused:
		return

	if (
		current_mode == Enums.GameMode.VS_BOT
		and turn_manager.current_player == bot_player
	):
		return

	if current_mode == Enums.GameMode.LAN_PVP:
		if not _ws_joined or ws_client == null or _network_move_pending:
			return

		if local_role == Enums.LobbyRole.SPECTATOR:
			return

		if turn_manager.current_player != local_net_player:
			return

		_network_move_pending = _send_network_message({
			"type": "move",
			"x": coord.x,
			"y": coord.y,
			"player": int(local_net_player)
		})
	else:
		_execute_move(coord)


func _execute_move(coord: Vector2i) -> void:
	# Проверяем координаты, включая полученные из сети.
	if (
		coord.x < 0
		or coord.y < 0
		or coord.x >= BoardData.GRID_SIZE
		or coord.y >= BoardData.GRID_SIZE
	):
		return

	if not board_data.is_empty(coord):
		return

	var active_player := turn_manager.current_player
	audio_manager.play_cell_click()

	board_data.set_cell(coord, active_player)
	board_view.update_cell(coord, active_player)

	var detected_patterns := pattern_detector.check_patterns(
		board_data,
		coord
	)
	var result := score_manager.process_patterns(
		detected_patterns,
		active_player
	)

	var scored_pattern: PatternInstance = result.get("pattern", null)
	var new_highlights: Array[Vector2i] = result.get("new_cells", [])

	if scored_pattern != null:
		audio_manager.play_pattern_scored()
		board_view.animate_pattern(
			scored_pattern.occupied_cells,
			0.5
		)

		for cell_coord in new_highlights:
			board_view.update_cell(
				cell_coord,
				board_data.get_cell(cell_coord),
				true
			)

		await get_tree().create_timer(0.5).timeout

	if (
		board_data.get_occupied_count()
		>= BoardData.GRID_SIZE * BoardData.GRID_SIZE
	):
		_end_game()
	else:
		turn_manager.next_turn()


func _on_turn_changed(new_player: Enums.Player) -> void:
	var active_local_player := human_player

	if current_mode == Enums.GameMode.LAN_PVP:
		active_local_player = local_net_player

	if hud:
		if hud.has_method("update_turn_status_with_names"):
			hud.update_turn_status_with_names(
				new_player,
				current_mode,
				active_local_player,
				player1_name,
				player2_name
			)
		else:
			hud.update_turn_status(
				new_player,
				current_mode,
				active_local_player
			)

	# Для наблюдателя показываем имя реального игрока, чей сейчас ход.
	if (
		current_mode == Enums.GameMode.LAN_PVP
		and local_role == Enums.LobbyRole.SPECTATOR
	):
		_update_spectator_turn_status(new_player)

	if (
		current_mode == Enums.GameMode.VS_BOT
		and new_player == bot_player
		and not is_game_over
	):
		_make_bot_move()


func _update_spectator_turn_status(
	current_player: Enums.Player
) -> void:
	if hud == null:
		return

	var active_name := player1_name
	var active_color: Color = PLAYER_1_TURN_COLOR

	if current_player == Enums.Player.PLAYER_2:
		active_name = player2_name
		active_color = PLAYER_2_TURN_COLOR

	var status_text := "Ход %s" % active_name
	var status_control := _find_turn_status_control_by_text(hud)

	if status_control == null:
		status_control = _find_turn_status_control_by_name(hud)

	if status_control == null:
		push_warning(
			"Не найден Label/RichTextLabel статуса хода в HUD."
		)
		return

	if status_control is Label:
		var status_label := status_control as Label
		status_label.text = status_text
		status_label.add_theme_color_override(
			"font_color",
			active_color
		)

	elif status_control is RichTextLabel:
		var rich_status_label := status_control as RichTextLabel
		rich_status_label.text = status_text
		rich_status_label.add_theme_color_override(
			"default_color",
			active_color
		)


func _find_turn_status_control_by_text(node: Node) -> Control:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			var label_text := label.text.to_lower()

			if label_text.contains("ход") or label_text.contains("turn"):
				return label

		elif child is RichTextLabel:
			var rich_label := child as RichTextLabel
			var rich_text := rich_label.text.to_lower()

			if rich_text.contains("ход") or rich_text.contains("turn"):
				return rich_label

		var nested_result := _find_turn_status_control_by_text(child)

		if nested_result != null:
			return nested_result

	return null


func _find_turn_status_control_by_name(node: Node) -> Control:
	for child in node.get_children():
		if child is Label or child is RichTextLabel:
			var node_name := str(child.name).to_lower()

			if (
				node_name.contains("turn")
				or node_name.contains("status")
				or node_name.contains("ход")
			):
				return child as Control

		var nested_result := _find_turn_status_control_by_name(child)

		if nested_result != null:
			return nested_result

	return null


func _make_bot_move() -> void:
	await get_tree().create_timer(0.4).timeout

	if (
		is_game_over
		or turn_manager.current_player != bot_player
		or get_tree().paused
	):
		return

	var bot_coord := Vector2i(-1, -1)

	match bot_difficulty:
		Enums.BotDifficulty.EASY:
			bot_coord = easy_bot.make_move(board_data)

		Enums.BotDifficulty.MEDIUM:
			bot_coord = medium_bot.make_move(
				board_data,
				pattern_detector,
				bot_player
			)

		Enums.BotDifficulty.HARD:
			bot_coord = hard_bot.make_move(
				board_data,
				pattern_detector,
				bot_player
			)

	if bot_coord != Vector2i(-1, -1):
		_execute_move(bot_coord)


func _end_game() -> void:
	if is_game_over:
		return

	var match_completed := (
		board_data.get_occupied_count()
		>= BoardData.GRID_SIZE * BoardData.GRID_SIZE
	)

	is_game_over = true

	if pause_button:
		pause_button.visible = false

	if save_manager:
		save_manager.set_playtime_active(false)
		save_manager.flush_playtime()

	var result_player := human_player

	if current_mode == Enums.GameMode.LAN_PVP:
		result_player = local_net_player

	var my_score := (
		score_manager.p1_score
		if result_player == Enums.Player.PLAYER_1
		else score_manager.p2_score
	)

	var opponent_score := (
		score_manager.p2_score
		if result_player == Enums.Player.PLAYER_1
		else score_manager.p1_score
	)

	# Засчитываем только завершённые матчи.
	if save_manager and match_completed:
		if current_mode == Enums.GameMode.VS_BOT:
			save_manager.record_game("bot", my_score > opponent_score)

		elif (
			current_mode == Enums.GameMode.LAN_PVP
			and local_role != Enums.LobbyRole.SPECTATOR
		):
			save_manager.record_game("online", my_score > opponent_score)

	if (
		current_mode == Enums.GameMode.VS_BOT
		or current_mode == Enums.GameMode.LAN_PVP
	):
		if my_score > opponent_score:
			audio_manager.play_win()
		else:
			audio_manager.play_lose()
	else:
		audio_manager.play_win()

	result_screen.show_results(
		score_manager.p1_score,
		score_manager.p2_score,
		score_manager.total_figures_created,
		score_manager.max_combo,
		(
			current_mode == Enums.GameMode.VS_BOT
			or current_mode == Enums.GameMode.LAN_PVP
		),
		result_player
	)


func _restart_game() -> void:
	get_tree().paused = false

	if current_mode == Enums.GameMode.LAN_PVP:
		if _ws_joined:
			_on_network_restart_requested()
	else:
		_start_game(turn_manager.current_player)


func _on_score_changed(p1_score: int, p2_score: int) -> void:
	hud.update_score(p1_score, p2_score)


func _on_bot_settings_confirmed(
	diff: Enums.BotDifficulty,
	first_turn: Enums.FirstTurn,
	color: Enums.PlayerColor
) -> void:
	bot_difficulty = diff
	current_mode = Enums.GameMode.VS_BOT

	var my_nick := main_menu.get_nickname()

	if color == Enums.PlayerColor.BLUE:
		human_player = Enums.Player.PLAYER_1
		bot_player = Enums.Player.PLAYER_2
		player1_name = my_nick
		player2_name = "Бот"
	else:
		human_player = Enums.Player.PLAYER_2
		bot_player = Enums.Player.PLAYER_1
		player1_name = "Бот"
		player2_name = my_nick

	var starting_player: Enums.Player = human_player

	match first_turn:
		Enums.FirstTurn.PLAYER:
			starting_player = human_player

		Enums.FirstTurn.BOT:
			starting_player = bot_player

		Enums.FirstTurn.RANDOM:
			starting_player = (
				human_player if randf() > 0.5 else bot_player
			)

	_start_game(starting_player)
