class_name TurnManager
extends RefCounted

signal turn_changed(current_player: Enums.Player)

var current_player: Enums.Player = Enums.Player.PLAYER_1

func reset() -> void:
	current_player = Enums.Player.PLAYER_1
	turn_changed.emit(current_player)

func next_turn() -> void:
	if current_player == Enums.Player.PLAYER_1:
		current_player = Enums.Player.PLAYER_2
	else:
		current_player = Enums.Player.PLAYER_1
	turn_changed.emit(current_player)
