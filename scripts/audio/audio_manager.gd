class_name AudioManager
extends Node

var _click_player: AudioStreamPlayer
var _score_player: AudioStreamPlayer
var _win_player: AudioStreamPlayer
var _lose_player: AudioStreamPlayer

func _ready() -> void:
	_click_player = _create_player()
	_score_player = _create_player()
	_win_player = _create_player()
	_lose_player = _create_player()

func _create_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	return player

# Звук клика / хода по клетке
func play_cell_click() -> void:
	_play_tone(_click_player, 520.0, 0.04, -12.0)

# Звук сборки фигуры
func play_pattern_scored() -> void:
	_play_tone(_score_player, 880.0, 0.15, -6.0)

# Звук победы
func play_win() -> void:
	_play_tone(_win_player, 650.0, 0.35, -4.0)

# Звук поражения / ничьей
func play_lose() -> void:
	_play_tone(_lose_player, 220.0, 0.45, -4.0)

func _play_tone(player: AudioStreamPlayer, freq: float, duration: float, volume_db: float) -> void:
	var sample_rate := 44100
	var sample_count := int(sample_rate * duration)
	
	# Подготавливаем буфер байтов (2 байта на один 16-битный сэмпл)
	var pcm_data := PackedByteArray()
	pcm_data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / sample_rate
		var sample := sin(2.0 * PI * freq * t)
		var env := 1.0 - (float(i) / sample_count) # Fade out
		var val := int(sample * env * 32767.0)
		pcm_data.encode_s16(i * 2, val)

	var sample_wav := AudioStreamWAV.new()
	sample_wav.format = AudioStreamWAV.FORMAT_16_BITS # Исправлено: FORMAT_16_BITS
	sample_wav.mix_rate = sample_rate
	sample_wav.data = pcm_data

	player.stream = sample_wav
	player.volume_db = volume_db
	player.play()
