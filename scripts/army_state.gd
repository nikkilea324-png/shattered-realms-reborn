class_name ArmyState
extends RefCounted

const UNIT_STATS := {
    "militia": {"name": "Militia", "attack": 35, "defense": 30, "health": 60, "speed": 5, "range": 1, "morale": 40},
    "spearmen": {"name": "Spearmen", "attack": 50, "defense": 60, "health": 90, "speed": 4, "range": 1, "morale": 60},
    "swordsmen": {"name": "Swordsmen", "attack": 70, "defense": 65, "health": 110, "speed": 5, "range": 1, "morale": 70},
    "shieldguard": {"name": "Shieldguard", "attack": 45, "defense": 95, "health": 150, "speed": 3, "range": 1, "morale": 90},
    "axemen": {"name": "Axemen", "attack": 90, "defense": 55, "health": 115, "speed": 5, "range": 1, "morale": 80},
    "knights": {"name": "Knights", "attack": 100, "defense": 85, "health": 160, "speed": 9, "range": 1, "morale": 95},
    "riders": {"name": "Riders", "attack": 65, "defense": 45, "health": 90, "speed": 11, "range": 1, "morale": 65},
    "archers": {"name": "Archers", "attack": 55, "defense": 25, "health": 65, "speed": 5, "range": 8, "morale": 55},
    "crossbowmen": {"name": "Crossbowmen", "attack": 80, "defense": 35, "health": 70, "speed": 4, "range": 7, "morale": 60},
    "rangers": {"name": "Rangers", "attack": 75, "defense": 45, "health": 80, "speed": 8, "range": 8, "morale": 75},
    "siege_engineers": {"name": "Siege Engineers", "attack": 15, "defense": 25, "health": 70, "speed": 3, "range": 1, "morale": 40},
    "mages": {"name": "Mages", "attack": 85, "defense": 20, "health": 60, "speed": 5, "range": 9, "morale": 65}
}

var id: String = ""
var display_name: String = ""
var commander_id: String = ""
var hex: Vector2i = Vector2i(-1, -1)
var units: Dictionary = {}
var supply: int = 100
var morale: int = 70

func configure(new_id: String, new_name: String, start_hex: Vector2i, new_commander_id: String) -> void:
    id = new_id
    display_name = new_name
    hex = start_hex
    commander_id = new_commander_id

func add_unit(unit_id: String, count: int) -> bool:
    if not UNIT_STATS.has(unit_id) or count <= 0:
        return false
    units[unit_id] = int(units.get(unit_id, 0)) + count
    return true

func total_units() -> int:
    var total := 0
    for count in units.values():
        total += int(count)
    return total

func unit_types() -> int:
    return units.size()

func combat_power() -> int:
    var power := 0
    for unit_id in units:
        var count := int(units[unit_id])
        var stats: Dictionary = UNIT_STATS[unit_id]
        power += count * (int(stats.attack) + int(stats.defense) + int(stats.health) / 10)
    return power

func summary() -> String:
    return "%s • %d troops • %d power" % [display_name, total_units(), combat_power()]
