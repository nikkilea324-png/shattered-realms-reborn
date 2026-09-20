extends Node3D

const HEX_GRID := preload("res://scripts/hex_grid.gd")

var grid := HEX_GRID.new()
var selected_hex := Vector2i.ZERO

func _ready() -> void:
    grid.configure(24, 16)
    print("Shattered Realms foundation initialized: %d hexes" % grid.hex_count())

func select_hex(coord: Vector2i) -> void:
    if grid.is_valid(coord):
        selected_hex = coord
        print("Selected hex: ", coord)
