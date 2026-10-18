class_name SaveManager
extends Node

signal profile_changed(profile: Dictionary)
signal sync_status_changed(status: String)

const SAVE_PATH: String = "user://meld_profile.json"
const PROFILE_SYNC_URL: String = "https://meldonlineserver.onrender.com/api/profile/sync"
const PLAYTIME_BATCH_SECONDS: float = 60.0
const SYNC_RETRY_SECONDS: float = 30.0

var _profile: Dictionary = {}
var _pending_events: Array[Dictionary] = []
var _http_request: HTTPRequest
var _has_saved_profile: bool = false
var _profile_dirty: bool = false
var _sync_in_flight: bool = false
var _nickname_debounce: float = 0.0
var _retry_timer: float = 0.0
var _save_timer: float = 0.0
var _notify_timer: float = 0.0
var _unsynced_playtime_seconds: float = 0.0
var _last_sent_event_ids: Array[String] = []
var _last_sent_nickname: String = ""
var _playtime_active: bool = false

func _ready() -> void:
	_load_local_data()
	_http_request = HTTPRequest.new()
	_http_request.timeout = 8.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_sync_request_completed)
	if not _pending_events.is_empty():
		_retry_timer = 1.0

func _process(delta: float) -> void:
	# Накопленное время считается только во время активного матча.
	if _playtime_active and delta > 0.0:
		_profile["total_play_time_seconds"] = float(_profile.get("total_play_time_seconds", 0.0)) + delta
		_unsynced_playtime_seconds += delta
		_save_timer += delta
		_notify_timer += delta

		if _unsynced_playtime_seconds >= PLAYTIME_BATCH_SECONDS:
			var seconds_to_queue := int(floor(_unsynced_playtime_seconds / PLAYTIME_BATCH_SECONDS)) * int(PLAYTIME_BATCH_SECONDS)
			_unsynced_playtime_seconds -= float(seconds_to_queue)
			_queue_playtime_event(seconds_to_queue)

		if _save_timer >= 5.0:
			_save_timer = 0.0
			_save_local_data()

		if _notify_timer >= 1.0:
			_notify_timer = 0.0
			profile_changed.emit(get_profile())

	if _nickname_debounce > 0.0:
		_nickname_debounce = maxf(0.0, _nickname_debounce - delta)

	if _retry_timer > 0.0:
		_retry_timer = maxf(0.0, _retry_timer - delta)
	elif not _sync_in_flight and (not _pending_events.is_empty() or _profile_dirty) and _nickname_debounce <= 0.0:
		_send_sync_request()

func has_saved_profile() -> bool:
	return _has_saved_profile

func get_nickname() -> String:
	return str(_profile.get("nickname", "Игрок"))

func get_device_id() -> String:
	return str(_profile.get("device_id", ""))

func get_profile() -> Dictionary:
	return _profile.duplicate(true)

func set_nickname(value: String) -> void:
	var clean_name := value.strip_edges()
	if clean_name.is_empty():
		clean_name = "Игрок"
	clean_name = clean_name.substr(0, 16)
	if clean_name == get_nickname():
		# На первом запуске нужно сохранить сгенерированный ID даже при никнейме «Игрок».
		_save_local_data()
		return

	_profile["nickname"] = clean_name
	_profile_dirty = true
	_nickname_debounce = 1.2
	_save_local_data()
	profile_changed.emit(get_profile())

func set_playtime_active(active: bool) -> void:
	_playtime_active = active

func flush_playtime() -> void:
	var seconds_to_queue := int(floor(_unsynced_playtime_seconds))
	_unsynced_playtime_seconds = 0.0
	if seconds_to_queue > 0:
		_queue_playtime_event(seconds_to_queue)
	_save_local_data()
	profile_changed.emit(get_profile())

func record_game(mode: String, won: bool) -> void:
	if mode != "bot" and mode != "online":
		return

	if mode == "bot":
		_profile["bot_games"] = int(_profile.get("bot_games", 0)) + 1
		if won:
			_profile["bot_wins"] = int(_profile.get("bot_wins", 0)) + 1
	else:
		_profile["online_games"] = int(_profile.get("online_games", 0)) + 1
		if won:
			_profile["online_wins"] = int(_profile.get("online_wins", 0)) + 1

	_queue_event({
		"type": "game_completed",
		"mode": mode,
		"won": won
	})
	_save_local_data()
	profile_changed.emit(get_profile())

func _queue_playtime_event(seconds: int) -> void:
	if seconds <= 0:
		return
	_queue_event({
		"type": "playtime",
		"seconds": seconds
	})

func _queue_event(event_data: Dictionary) -> void:
	var event := event_data.duplicate(true)
	event["event_id"] = _make_event_id()
	_pending_events.append(event)
	_save_local_data()
	_retry_timer = 0.0
	if not _sync_in_flight:
		_send_sync_request()

func _make_event_id() -> String:
	return "%s-%d-%08x" % [get_device_id(), int(Time.get_unix_time_from_system()), randi()]

func _send_sync_request() -> void:
	if _sync_in_flight or _http_request == null:
		return
	if _pending_events.is_empty() and not _profile_dirty:
		return

	var events_to_send: Array[Dictionary] = []
	_last_sent_event_ids.clear()
	for event in _pending_events:
		if events_to_send.size() >= 200:
			break
		events_to_send.append(event.duplicate(true))
		_last_sent_event_ids.append(str(event.get("event_id", "")))
	_last_sent_nickname = get_nickname()

	var payload := {
		"device_id": get_device_id(),
		"nickname": _last_sent_nickname,
		"events": events_to_send
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var request_error := _http_request.request(
		PROFILE_SYNC_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if request_error != OK:
		_retry_timer = SYNC_RETRY_SECONDS
		sync_status_changed.emit("Нет соединения; изменения сохранены на устройстве")
		return

	_sync_in_flight = true
	sync_status_changed.emit("Синхронизация с сервером…")

func _on_sync_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_sync_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_retry_timer = SYNC_RETRY_SECONDS
		sync_status_changed.emit("Офлайн: статистика сохранена и будет отправлена позже")
		_save_local_data()
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		_retry_timer = SYNC_RETRY_SECONDS
		sync_status_changed.emit("Сервер не подтвердил синхронизацию; данные сохранены локально")
		_save_local_data()
		return

	var sent_ids: Dictionary = {}
	for event_id in _last_sent_event_ids:
		sent_ids[event_id] = true
	var remaining: Array[Dictionary] = []
	for event in _pending_events:
		if not sent_ids.has(str(event.get("event_id", ""))):
			remaining.append(event)
	_pending_events = remaining

	var server_profile = parsed.get("profile", {})
	if server_profile is Dictionary:
		# Не затираем локальные данные меньшими значениями из ответа сервера.
		for key in ["total_play_time_seconds", "bot_games", "online_games", "bot_wins", "online_wins"]:
			var local_value = _profile.get(key, 0)
			var server_value = server_profile.get(key, local_value)
			_profile[key] = maxf(float(local_value), float(server_value)) if key == "total_play_time_seconds" else maxi(int(local_value), int(server_value))

	if get_nickname() == _last_sent_nickname:
		_profile_dirty = false
	_retry_timer = 0.0
	_save_local_data()
	profile_changed.emit(get_profile())
	sync_status_changed.emit("Синхронизировано с сервером")

	if not _pending_events.is_empty() or _profile_dirty:
		call_deferred("_send_sync_request")

func _load_local_data() -> void:
	_profile = {
		"device_id": _generate_device_id(),
		"nickname": "Игрок",
		"total_play_time_seconds": 0.0,
		"bot_games": 0,
		"online_games": 0,
		"bot_wins": 0,
		"online_wins": 0
	}
	_pending_events.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		_profile_dirty = true # Создаём профиль на сервере при первой возможности.
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return

	var saved_profile = parsed.get("profile", {})
	if saved_profile is Dictionary:
		for key in _profile.keys():
			if saved_profile.has(key):
				_profile[key] = saved_profile[key]

	_profile_dirty = bool(parsed.get("profile_dirty", false))
	var saved_events = parsed.get("pending_events", [])
	if saved_events is Array:
		for event in saved_events:
			if event is Dictionary:
				_pending_events.append(event.duplicate(true))

	if str(_profile.get("device_id", "")).is_empty():
		_profile["device_id"] = _generate_device_id()
	_has_saved_profile = true

func _save_local_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить профиль Meld локально.")
		return
	file.store_string(JSON.stringify({
		"profile": _profile,
		"pending_events": _pending_events,
		"profile_dirty": _profile_dirty
	}, "\t"))
	file.close()
	_has_saved_profile = true

func _generate_device_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var device_id := "meld-"
	for i in range(4):
		if i > 0:
			device_id += "-"
		device_id += "%08x" % rng.randi()
	return device_id

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_playtime()
	elif what == NOTIFICATION_PREDELETE:
		_save_local_data()


func _exit_tree() -> void:
	# Не полагаемся только на закрытие окна: сохраняем профиль и при выходе
	# из дерева сцены/завершении приложения. flush_playtime() также записывает JSON.
	flush_playtime()
