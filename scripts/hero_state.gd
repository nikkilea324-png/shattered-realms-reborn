class_name HeroState
extends RefCounted

var id: String = ""
var display_name: String = ""
var hex: Vector2i = Vector2i(-1, -1)
var max_movement: int = 2
var movement_remaining: int = 2

func configure(new_id: String, new_name: String, start_hex: Vector2i, movement: int = 2) -> void:
    id = new_id
    display_name = new_name
    hex = start_hex
    max_movement = movement
    movement_remaining = movement

func begin_turn() -> void:
    movement_remaining = max_movement

func spend(cost: int) -> bool:
    if cost < 0 or movement_remaining < cost:
        return false
    movement_remaining -= cost
    return true
