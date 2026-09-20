class_name HexGrid
extends RefCounted

var width: int = 0
var height: int = 0

func configure(new_width: int, new_height: int) -> void:
    width = new_width
    height = new_height

func hex_count() -> int:
    return width * height

func is_valid(coord: Vector2i) -> bool:
    return coord.x >= 0 and coord.x < width and coord.y >= 0 and coord.y < height

func neighbors(coord: Vector2i) -> Array[Vector2i]:
    var odd_column := (coord.x & 1) == 1
    var offsets: Array[Vector2i]
    if odd_column:
        offsets = [
            Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
            Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)
        ]
    else:
        offsets = [
            Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
            Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
        ]
    var result: Array[Vector2i] = []
    for offset in offsets:
        var neighbor := coord + offset
        if is_valid(neighbor):
            result.append(neighbor)
    return result

func to_world(coord: Vector2i, hex_size: float = 1.0) -> Vector3:
    var x := coord.x * hex_size * 1.5
    var z := (coord.y + (0.5 if (coord.x & 1) else 0.0)) * hex_size * sqrt(3.0)
    return Vector3(x, 0.0, z)
