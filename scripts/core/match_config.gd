
class_name MatchConfig
extends RefCounted

var mode: StringName = &"free"        # &"free" | &"campaign"
var level_id: StringName = &""
var board_size: int = 10
var max_moves: int = 0                # 0 = полная партия (до заполнения поля)
var bot_difficulty: int = -1          # -1 = без бота
