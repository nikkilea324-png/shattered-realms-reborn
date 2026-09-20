# Shattered Realms — Technical Architecture

## Direction

Shattered Realms is a dark fantasy turn-based strategy game combining:
- D&D-style heroes, abilities, equipment, leveling, encounters and dungeons.
- Risk-style strategic territory control, armies, supply, morale and conquest.
- A 3D/2.5D presentation with a painted fantasy-atlas visual layer.

## Core technical rules

1. Godot 4.x is the game engine.
2. Android is a first-class target.
3. The strategic map uses a hex grid as the underlying gameplay coordinate system.
4. Elevation is part of terrain data from the beginning.
5. World map, territory map and dungeon map are separate gameplay layers sharing core systems.
6. Touch input is handled directly; fragile transparent full-screen button overlays are avoided.
7. Game rules live in data/state systems rather than being embedded in presentation code.
8. The first playable territory is Ravenwood.
9. Automated validation must run before release builds.

## First vertical slice

World map → select Ravenwood → zoom into Ravenwood → display a 24×16 hex terrain board → move a commander/army → discover a hidden cave → enter a small dungeon.

## Strategic layers

### World layer
Kingdoms, territories, borders, cities, armies, routes, monsters and campaign events.

### Territory layer
A detailed hex board containing terrain elevation, forests, rivers, roads, villages, forts, ruins, mines, dungeons and monster lairs.

### Dungeon layer
A smaller tactical/exploration grid using the same underlying coordinate and encounter concepts.

## Ravenwood

Initial board size: 24×16 = 384 hexes.

Movement is intentionally terrain-aware. Good terrain supports normal movement; difficult terrain consumes the movement cycle. Commander abilities can modify movement.

## Planned state domains

- GameState
- TerritoryState
- Hex/TerrainState
- HeroState
- ArmyState
- EncounterState
- DungeonState
- CampaignEventState

Presentation should read state and render it. Rules should not depend on scene-node layout.
