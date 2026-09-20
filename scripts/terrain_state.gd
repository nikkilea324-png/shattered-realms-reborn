class_name TerrainState
extends RefCounted

enum TerrainType {
    PLAINS,
    FOREST,
    HILLS,
    MOUNTAIN,
    MARSH,
    RIVER,
    ROAD,
    VILLAGE,
    FORT,
    RUINS,
    MINE,
    DUNGEON
}

var terrain_type: TerrainType = TerrainType.PLAINS
var elevation: int = 0
var movement_cost: int = 1
var defense_modifier: int = 0
var concealment: int = 0

func configure(type: TerrainType, height: int) -> void:
    terrain_type = type
    elevation = height
    _refresh_rules()

func _refresh_rules() -> void:
    match terrain_type:
        TerrainType.PLAINS:
            movement_cost = 1
            defense_modifier = 0
            concealment = 0
        TerrainType.FOREST:
            movement_cost = 2
            defense_modifier = 15
            concealment = 25
        TerrainType.HILLS:
            movement_cost = 2
            defense_modifier = 10
            concealment = 10
        TerrainType.MOUNTAIN:
            movement_cost = 3
            defense_modifier = 30
            concealment = 20
        TerrainType.MARSH:
            movement_cost = 2
            defense_modifier = 5
            concealment = 20
        TerrainType.RIVER:
            movement_cost = 3
            defense_modifier = 0
            concealment = 0
        TerrainType.ROAD:
            movement_cost = 1
            defense_modifier = 0
            concealment = 0
        TerrainType.VILLAGE, TerrainType.FORT, TerrainType.RUINS, TerrainType.MINE, TerrainType.DUNGEON:
            movement_cost = 1
        _:
            movement_cost = 1
