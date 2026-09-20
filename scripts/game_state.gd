class_name GameState
extends RefCounted

enum CampaignLayer {
    WORLD,
    TERRITORY,
    DUNGEON
}

var turn: int = 1
var active_layer: CampaignLayer = CampaignLayer.WORLD
var active_territory_id: String = ""
var selected_hex := Vector2i(-1, -1)
var hero: HeroState

func initialize_hero(hero_id: String, hero_name: String, start_hex: Vector2i, movement: int = 2) -> void:
    hero = HeroState.new()
    hero.configure(hero_id, hero_name, start_hex, movement)

func begin_campaign_turn() -> void:
    turn += 1
    if hero != null:
        hero.begin_turn()

func begin_turn() -> void:
    turn += 1

func enter_territory(territory_id: String) -> void:
    active_territory_id = territory_id
    active_layer = CampaignLayer.TERRITORY
    selected_hex = Vector2i(-1, -1)

func enter_dungeon() -> void:
    active_layer = CampaignLayer.DUNGEON
    selected_hex = Vector2i(-1, -1)

func return_to_world() -> void:
    active_layer = CampaignLayer.WORLD
    active_territory_id = ""
    selected_hex = Vector2i(-1, -1)
