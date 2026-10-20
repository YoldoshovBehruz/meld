# scenes/campaign/level_map.gd
class_name LevelMap
extends Control

signal level_chosen(level: LevelDefinition)

const TOP := 80.0
const SPACING := 150.0
const AMPLITUDE := 180.0
const NODE_SIZE := Vector2(96, 96)
const BOTTOM_PAD := 120.0
const INK := Color("#2b2b2b")
const PATH_LOCKED := Color(0.45, 0.42, 0.37, 0.5)
const COLOR_DONE := Color("#F4C542")
const COLOR_OPEN := Color("#fbf7ec")
const COLOR_LOCKED := Color("#d8d2c4")

var _levels: Array[LevelDefinition] = []
var _nodes: Array[Button] = []
var _unlocked: Array[bool] = []
var _current: int = -1
var _pulse: Tween = null

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_layout)
	rebuild()

# Пересоздаёт узлы по актуальному прогрессу из CampaignManager.
func rebuild() -> void:
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	_unlocked.clear()
	_levels = CampaignManager.get_levels()
	_current = -1

	custom_minimum_size = Vector2(0, TOP + _levels.size() * SPACING + BOTTOM_PAD)

	for i in _levels.size():
		var unlocked := CampaignManager.is_unlocked(i)
		var stars := CampaignManager.get_stars(_levels[i].id)
		_unlocked.append(unlocked)
		if unlocked and stars == 0 and _current == -1:
			_current = i
		var node := _make_node(i, stars, unlocked)
		add_child(node)
		_nodes.append(node)

	_layout()

func _make_node(index: int, stars: int, unlocked: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = NODE_SIZE
	b.size = NODE_SIZE
	b.pivot_offset = NODE_SIZE * 0.5
	b.disabled = not unlocked
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", INK)

	if unlocked:
		b.text = "%d\n%s" % [index + 1, "★".repeat(stars) + "☆".repeat(3 - stars)]
	else:
		b.text = "🔒"

	var color := COLOR_LOCKED
	if unlocked:
		color = COLOR_DONE if stars > 0 else COLOR_OPEN
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, _circle(color))

	if unlocked:
		b.pressed.connect(_on_node_pressed.bind(index))
	return b

func _circle(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(48)
	return sb

func _on_node_pressed(index: int) -> void:
	level_chosen.emit(_levels[index])

func _layout() -> void:
	for i in _nodes.size():
		_nodes[i].position = _pos(i) - NODE_SIZE * 0.5
	_start_pulse()
	queue_redraw()

func _pos(i: int) -> Vector2:
	return Vector2(size.x * 0.5 + sin(i * 0.9) * AMPLITUDE, TOP + i * SPACING)

func _start_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	if _current < 0 or _current >= _nodes.size():
		return
	var node := _nodes[_current]
	_pulse = create_tween().set_loops()
	_pulse.tween_property(node, "scale", Vector2(1.08, 1.08), 0.6)
	_pulse.tween_property(node, "scale", Vector2.ONE, 0.6)

func _draw() -> void:
	for i in range(1, _nodes.size()):
		var a := _pos(i - 1)
		var b := _pos(i)
		if _unlocked[i]:
			draw_line(a, b, INK, 4.0, true)
		else:
			_draw_dashed(a, b, PATH_LOCKED)

func _draw_dashed(a: Vector2, b: Vector2, color: Color) -> void:
	var length := a.distance_to(b)
	var steps := int(length / 14.0)
	if steps <= 0:
		return
	for k in range(0, steps, 2):
		var p := a.lerp(b, float(k) / steps)
		var q := a.lerp(b, float(k + 1) / steps)
		draw_line(p, q, color, 4.0, true)
