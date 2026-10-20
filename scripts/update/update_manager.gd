extends Node

## Проверка, загрузка и установка обновлений Android-версии Meld.
## Autoload: "UpdateManager".

signal update_offered(info: Dictionary, forced: bool)
signal check_finished(has_update: bool)
signal download_progress(percent: float)
signal download_failed(reason: String)

const UPDATE_API_URL: String = "https://github.com/YoldoshovBehruz/meld/releases/latest/download/update.json"
const BUILD_INFO_PATH: String = "res://build_info.json"
const DOWNLOAD_DIR: String = "user://updates"
const STATE_PATH: String = "user://update_state.cfg"
const CHECK_TIMEOUT_SEC: float = 8.0
const DOWNLOAD_TIMEOUT_SEC: float = 60.0
const SPACE_MARGIN: float = 1.5
const INSTALLER_SINGLETON: String = "MeldInstaller"

var _enabled: bool = false
var _current_code: int = 0
var _current_name: String = ""

var _checking: bool = false
var _downloading: bool = false
var _awaiting_install: bool = false
var _forced: bool = false
var _info: Dictionary = {}
var _apk_path: String = ""

var _check_request: HTTPRequest
var _download_request: HTTPRequest

var _overlay: Control
var _panel: PanelContainer
var _title_label: Label
var _version_label: Label
var _changelog_label: Label
var _progress: ProgressBar
var _status_label: Label
var _update_button: Button
var _later_button: Button
var _retry_button: Button


func _ready() -> void:
	set_process(false)

	# Обновления работают только в Android-сборке с build_info.json.
	if not _load_build_info():
		return
	
	_check_request = HTTPRequest.new()
	_check_request.timeout = CHECK_TIMEOUT_SEC
	_check_request.request_completed.connect(_on_check_completed)
	add_child(_check_request)

	_download_request = HTTPRequest.new()
	_download_request.timeout = DOWNLOAD_TIMEOUT_SEC
	_download_request.request_completed.connect(_on_download_completed)
	add_child(_download_request)

	_build_ui()
	_enabled = true
	check_for_updates.call_deferred()


func _notification(what: int) -> void:
	if not _enabled:
		return

	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _awaiting_install:
		_awaiting_install = false
		_show_offer("Установка не завершена. Можно повторить.")

	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _overlay.visible and not _forced:
		_hide_offer()

func _process(_delta: float) -> void:
	if not _downloading:
		return

	var total: int = _download_request.get_body_size()
	if total <= 0:
		total = int(_info.get("size_bytes", 0))
	if total <= 0:
		return

	var received: int = _download_request.get_downloaded_bytes()
	var percent: float = clampf(100.0 * float(received) / float(total), 0.0, 100.0)
	_progress.value = percent
	download_progress.emit(percent)


# =========================================================
# ПРОВЕРКА
# =========================================================

func check_for_updates() -> void:
	if not _enabled or _checking or _downloading:
		return

	_checking = true
	_show_checking_popup() # Показываем красивое окно поиска при старте

	if _check_request.request(UPDATE_API_URL, PackedStringArray(["Accept: application/json"])) != OK:
		_checking = false
		_on_check_unavailable()


func _show_checking_popup() -> void:
	_title_label.text = "Проверка обновлений"
	_version_label.text = "Подождите, идёт поиск новых версий..."
	_changelog_label.text = ""
	_progress.visible = false
	_later_button.visible = false
	_retry_button.visible = false
	_update_button.visible = false
	_set_status("")
	_overlay.visible = true


func _on_check_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray
) -> void:
	_checking = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_on_check_unavailable()
		return

	var info: Dictionary = _validate_manifest(JSON.parse_string(body.get_string_from_utf8()))
	if info.is_empty():
		_on_check_unavailable()
		return

	_save_state(info)

	var has_update: bool = int(info["version_code"]) > _current_code
	check_finished.emit(has_update)

	if not has_update:
		_set_status("У вас установлена самая актуальная версия.")
		# Если обновлений нет, показываем статус и плавно закрываем окно через 1.5 секунды
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(_hide_offer)
		return

	var is_forced: bool = bool(info["mandatory"]) or _current_code < int(info["min_supported_version_code"])
	_info = info
	_show_offer("", is_forced)


func _on_check_unavailable() -> void:
	_checking = false
	check_finished.emit(false)

	var state := ConfigFile.new()
	if state.load(STATE_PATH) == OK:
		var cached: Variant = state.get_value("update", "manifest", {})
		if cached is Dictionary and not cached.is_empty():
			var min_supported: int = int(cached.get("min_supported_version_code", 0))
			if _current_code < min_supported:
				_info = cached
				_show_offer("Сервер недоступен. Требуется обновление.", true)
				return

	# Если интернет пропал или таймаут — сообщаем об этом и закрываем окно через 1.5 секунды
	_set_status("Не удалось проверить обновления.")
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(_hide_offer)


func _validate_manifest(parsed: Variant) -> Dictionary:
	if not (parsed is Dictionary):
		return {}

	var version_code: int = int(parsed.get("version_code", 0))
	var apk_url: String = str(parsed.get("apk_url", ""))
	var sha256: String = str(parsed.get("sha256", "")).to_lower()
	var version_name: String = str(parsed.get("version_name", ""))

	var valid: bool = (
		version_code > 0
		and apk_url.begins_with("https://")
		and sha256.length() == 64
		and not version_name.is_empty()
	)
	if not valid:
		return {}

	return {
		"version_name": version_name,
		"version_code": version_code,
		"min_supported_version_code": int(parsed.get("min_supported_version_code", 0)),
		"mandatory": bool(parsed.get("mandatory", false)),
		"apk_url": apk_url,
		"sha256": sha256,
		"changelog": str(parsed.get("changelog", "")),
		"size_bytes": int(parsed.get("size_bytes", 0))
	}


# =========================================================
# ЗАГРУЗКА
# =========================================================

func _start_download() -> void:
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)

	var file_name: String = "Meld-%d.apk" % int(_info["version_code"])
	_apk_path = "%s/%s" % [DOWNLOAD_DIR, file_name]

	if FileAccess.file_exists(_apk_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_apk_path))

	_download_request.download_file = _apk_path

	if _download_request.request(String(_info["apk_url"])) != OK:
		_download_request.download_file = ""
		_fail("Не удалось начать загрузку.")
		return

	_downloading = true
	_set_busy(true)
	_progress.value = 0.0
	_progress.visible = true
	_set_status("Загрузка обновления…")
	set_process(true)


func _on_download_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		_body: PackedByteArray
) -> void:
	_downloading = false
	set_process(false)
	_download_request.download_file = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(_describe_request_error(result))
		return

	if response_code != 200:
		_fail("Сервер вернул ошибку %d. Попробуйте позже." % response_code)
		return

	var actual_sha: String = FileAccess.get_sha256(_apk_path)
	if actual_sha != String(_info["sha256"]):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_apk_path))
		_fail("Файл повреждён (контрольная сумма не совпала). Попробуйте ещё раз.")
		return

	_install(ProjectSettings.globalize_path(_apk_path))


func _describe_request_error(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Нет связи с сервером. Проверьте интернет."
		HTTPRequest.RESULT_TIMEOUT:
			return "Превышено время ожидания. Попробуйте ещё раз."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Ошибка защищённого соединения."
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Не удалось сохранить файл. Проверьте свободное место."
		_:
			return "Загрузка прервана (код %d)." % result


func _has_enough_space() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return true

	var needed: int = int(_info.get("size_bytes", 0))
	var left: int = dir.get_space_left()

	if needed <= 0 or left < 0:
		return true

	return float(left) >= float(needed) * SPACE_MARGIN


# =========================================================
# УСТАНОВКА
# =========================================================

func _get_installer() -> Object:
	if Engine.has_singleton(INSTALLER_SINGLETON):
		return Engine.get_singleton(INSTALLER_SINGLETON)
	return null


func _install(global_apk_path: String) -> void:
	var installer := _get_installer()
	if installer == null:
		_fail("Установка доступна только в Android-версии.")
		return

	if not bool(installer.call("canRequestPackageInstalls")):
		installer.call("openUnknownSourcesSettings")
		_fail("Разрешите установку из этого источника и вернитесь в игру.")
		return

	_awaiting_install = true
	_set_status("Открывается установщик Android…")
	installer.call("installApk", global_apk_path)


# =========================================================
# UI
# =========================================================

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	layer.add_child(_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	_panel.custom_minimum_size = Vector2(minf(460.0, viewport_width - 48.0), 0.0)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_title_label = _make_label(22)
	box.add_child(_title_label)

	_version_label = _make_label(16)
	box.add_child(_version_label)

	_changelog_label = _make_label(15)
	box.add_child(_changelog_label)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.visible = false
	box.add_child(_progress)

	_status_label = _make_label(14)
	box.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	_later_button = Button.new()
	_later_button.text = "Позже"
	_later_button.pressed.connect(_hide_offer)
	buttons.add_child(_later_button)

	_retry_button = Button.new()
	_retry_button.text = "Проверить снова"
	_retry_button.pressed.connect(check_for_updates)
	buttons.add_child(_retry_button)

	_update_button = Button.new()
	_update_button.text = "Обновить"
	_update_button.pressed.connect(_on_update_pressed)
	buttons.add_child(_update_button)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _show_offer(status: String, forced: bool = false) -> void:
	_forced = forced
	_title_label.text = "Требуется обновление" if forced else "Доступно обновление"
	_version_label.text = "Новая версия %s (код %d). У вас: %s (код %d)." % [
		String(_info.get("version_name", "")),
		int(_info.get("version_code", 0)),
		_current_name,
		_current_code
	]
	var notes: String = String(_info.get("changelog", ""))
	_changelog_label.text = notes if not notes.is_empty() else "Описание изменений не указано."
	_later_button.visible = not forced
	_retry_button.visible = forced
	_update_button.visible = true # Возвращаем кнопку обновить
	_progress.visible = false
	_set_busy(false)
	_set_status(status)
	_overlay.visible = true


func _hide_offer() -> void:
	if _downloading:
		return
	_overlay.visible = false


func _on_update_pressed() -> void:
	if _downloading or _info.is_empty():
		return

	var installer := _get_installer()
	if installer != null and not bool(installer.call("canRequestPackageInstalls")):
		installer.call("openUnknownSourcesSettings")
		_set_status("Разрешите установку приложений из Meld и вернитесь в игру.")
		_awaiting_install = true
		return

	if not _has_enough_space():
		_set_status("Недостаточно места для загрузки обновления.")
		return

	_start_download()


func _fail(message: String) -> void:
	_set_busy(false)
	_progress.visible = false
	_set_status(message)
	download_failed.emit(message)


func _set_busy(busy: bool) -> void:
	_update_button.disabled = busy
	_later_button.disabled = busy
	_retry_button.disabled = busy


func _set_status(text: String) -> void:
	_status_label.text = text


# =========================================================
# ВСПОМОГАТЕЛЬНОЕ
# =========================================================

func _load_build_info() -> bool:
	if not FileAccess.file_exists(BUILD_INFO_PATH):
		return false

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO_PATH))
	if not (parsed is Dictionary):
		return false

	_current_code = int(parsed.get("version_code", 0))
	_current_name = str(parsed.get("version_name", ""))
	return _current_code > 0


func _save_state(info: Dictionary) -> void:
	var state := ConfigFile.new()
	state.set_value("update", "manifest", info)
	state.save(STATE_PATH)
