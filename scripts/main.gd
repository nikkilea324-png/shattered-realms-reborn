extends Node3D

const HEX_GRID := preload("res://scripts/hex_grid.gd")
const GAME_STATE := preload("res://scripts/game_state.gd")
const TERRAIN_STATE := preload("res://scripts/terrain_state.gd")
const ARMY_STATE := preload("res://scripts/army_state.gd")

const HEX_SIZE := 1.0
const HEX_HEIGHT := 0.22
const BOARD_WIDTH := 24
const BOARD_HEIGHT := 16

var grid := HEX_GRID.new()
var selected_hex := Vector2i(-1, -1)
var hex_nodes: Dictionary = {}
var commander_hex := Vector2i(5, 8)
var commander: Node3D
var selection_ring: MeshInstance3D
var game_state := GAME_STATE.new()
var army_state := ARMY_STATE.new()
var reachable_nodes: Dictionary = {}
var reachable_hexes: Dictionary = {}
var commander_selected := false
var movement_label: Label
var turn_label: Label
var army_label: Label
var terrain_label: Label
var loading_layer: CanvasLayer
var loading_bar: ProgressBar
var loading_status: Label
var loading_detail: Label
var ravenwood_data: Dictionary = {}
var shared_base_mesh: CylinderMesh
var shared_base_collision: CylinderShape3D
var shared_terrain_materials: Dictionary = {}
var touch_active := false
var touch_start := Vector2.ZERO
var touch_moved := false

func _ready() -> void:
    _configure_camera()
    _build_loading_screen()
    await get_tree().process_frame
    _load_ravenwood_data()
    grid.configure(BOARD_WIDTH, BOARD_HEIGHT)
    _prepare_shared_resources()
    _set_loading(0.10, "Initializing Ravenwood terrain...", "384 hexes")
    await get_tree().process_frame
    await _build_ravenwood()
    _set_loading(0.58, "Placing commander and army...", "Edrin Vale")
    await get_tree().process_frame
    _build_commander()
    _set_loading(0.70, "Placing Ravenwood locations...", "Keep • Village • Mine • Hidden Cave")
    await get_tree().process_frame
    _build_locations()
    _set_loading(0.82, "Preparing command interface...", "Touch controls online")
    await get_tree().process_frame
    _build_selection()
    _build_hud()
    game_state.initialize_hero("edrin_vale", "Edrin Vale", commander_hex, 3)
    army_state.configure("ravenwood_rangers", "Ravenwood Rangers", commander_hex, "edrin_vale")
    army_state.add_unit("rangers", 12)
    army_state.add_unit("archers", 18)
    army_state.add_unit("swordsmen", 24)
    army_state.add_unit("spearmen", 20)
    _refresh_hud()
    _set_loading(1.0, "Ravenwood ready", "3D camera locked • Tap a hex • drag to pan • pinch to zoom")
    await get_tree().process_frame
    await get_tree().create_timer(0.25).timeout
    loading_layer.queue_free()
    loading_layer = null
    print("Ravenwood gameplay slice initialized: %d hexes" % grid.hex_count())

func _configure_camera() -> void:
    var camera := get_node_or_null("CameraRig/Camera3D") as Camera3D
    if camera == null:
        push_error("Ravenwood camera missing.")
        return
    camera.position = Vector3(0, 30, 30)
    camera.near = 0.1
    camera.far = 200.0
    camera.current = true
    camera.look_at(Vector3.ZERO, Vector3.UP)
    print("RAVENWOOD CAMERA: pos=", camera.global_position, " target=", Vector3.ZERO, " rotation=", camera.global_rotation_degrees)

func _load_ravenwood_data() -> void:
    const DATA_PATH := "res://data/ravenwood.json"
    if not FileAccess.file_exists(DATA_PATH):
        push_warning("Ravenwood JSON missing; using embedded runtime defaults.")
        return
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_warning("Ravenwood JSON could not be opened; using embedded runtime defaults.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        ravenwood_data = parsed
        for location in ravenwood_data.get("starting_locations", []):
            if String(location.get("type", "")) == "fort":
                commander_hex = _array_to_coord(location.get("hex", [5, 8]))
                break

func _array_to_coord(value: Variant) -> Vector2i:
    if value is Array and value.size() >= 2:
        return Vector2i(int(value[0]), int(value[1]))
    return Vector2i(5, 8)

func _prepare_shared_resources() -> void:
    shared_base_mesh = CylinderMesh.new()
    shared_base_mesh.top_radius = HEX_SIZE
    shared_base_mesh.bottom_radius = HEX_SIZE
    shared_base_mesh.height = HEX_HEIGHT
    shared_base_mesh.radial_segments = 6
    shared_base_collision = CylinderShape3D.new()
    shared_base_collision.radius = HEX_SIZE
    shared_base_collision.height = HEX_HEIGHT
func _build_ravenwood() -> void:
    # Android-safe terrain path: one MultiMesh per terrain family instead of
    # hundreds of independent MeshInstance3D/StaticBody3D nodes.
    var center := _board_center()
    var groups: Dictionary = {}
    var materials: Dictionary = {}
    for y in range(BOARD_HEIGHT):
        for x in range(BOARD_WIDTH):
            var coord := Vector2i(x, y)
            var terrain_key := _terrain_name(_terrain_type(coord)).to_lower()
            if not groups.has(terrain_key):
                groups[terrain_key] = []
                materials[terrain_key] = _terrain_material(coord)
            groups[terrain_key].append(coord)
        if y % 2 == 0:
            _set_loading(0.10 + 0.45 * float(y + 1) / float(BOARD_HEIGHT), "Building Ravenwood terrain...", "Row %d / %d" % [y + 1, BOARD_HEIGHT])
            await get_tree().process_frame

    for terrain_key in groups.keys():
        var coords: Array = groups[terrain_key]
        var multi := MultiMeshInstance3D.new()
        multi.name = "Terrain_%s" % terrain_key.capitalize()
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = false
        mm.instance_count = coords.size()
        mm.mesh = shared_base_mesh
        for i in range(coords.size()):
            var coord: Vector2i = coords[i]
            var world := grid.to_world(coord, HEX_SIZE) - center
            var transform := Transform3D(Basis.IDENTITY, Vector3(world.x, _elevation(coord), world.z))
            mm.set_instance_transform(i, transform)
        # Explicit bounds keep runtime-generated MultiMeshes from being frustum-culled on Android.
        mm.custom_aabb = AABB(Vector3(-22.0, -2.0, -22.0), Vector3(44.0, 6.0, 44.0))
        multi.multimesh = mm
        multi.material_override = materials[terrain_key]
        multi.extra_cull_margin = 64.0
        multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(multi)

    # A single simple collision volume is enough for touch-to-hex picking.
    var picker := StaticBody3D.new()
    picker.name = "RavenwoodPickSurface"
    var picker_shape := CollisionShape3D.new()
    var picker_box := BoxShape3D.new()
    picker_box.size = Vector3(40.0, 0.25, 30.0)
    picker_shape.shape = picker_box
    picker_shape.position.y = -0.10
    picker.add_child(picker_shape)
    add_child(picker)

    # Deterministic 3D render probe: a normal MeshInstance3D isolates the Android 3D pipeline from MultiMesh culling.
    var render_probe := MeshInstance3D.new()
    render_probe.name = "Ravenwood3DRenderProbe"
    var probe_mesh := BoxMesh.new()
    probe_mesh.size = Vector3(18.0, 0.24, 12.0)
    render_probe.mesh = probe_mesh
    render_probe.position = Vector3(0.0, 0.05, 0.0)
    render_probe.material_override = _material(Color(0.10, 0.72, 0.16), 0.0)
    render_probe.extra_cull_margin = 64.0
    render_probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(render_probe)

    # Keep the detailed terrain decorations off the Android startup path.
    # They will be reintroduced through instancing after the base render is proven.
func _add_terrain_visuals(tile: StaticBody3D, coord: Vector2i) -> void:
    var terrain := _terrain_type(coord)
    match terrain:
        TerrainState.TerrainType.FOREST:
            _add_forest_marker(tile, coord)
        TerrainState.TerrainType.MOUNTAIN:
            var base := _make_cylinder(0.72, 0.34, 7, Color(0.25, 0.24, 0.22))
            base.position.y = 0.18
            tile.add_child(base)
            if (coord.x + coord.y) % 3 == 0:
                var peak := _make_cone(0.62, 1.05, 6, Color(0.36, 0.35, 0.32))
                peak.position = Vector3(-0.12, 0.72, 0.02)
                tile.add_child(peak)
                var snow := _make_cone(0.24, 0.30, 6, Color(0.72, 0.72, 0.68))
                snow.position = Vector3(-0.18, 1.27, 0.02)
                tile.add_child(snow)
            if (coord.x * 3 + coord.y) % 4 == 0:
                _add_rock(tile, Vector3(0.34, 0.18, 0.24), 0.16)
        TerrainState.TerrainType.HILLS:
            var hill := _make_cylinder(0.68, 0.34, 10, Color(0.34, 0.31, 0.22))
            hill.position.y = 0.18
            tile.add_child(hill)
            var cap := _make_cylinder(0.52, 0.20, 10, Color(0.28, 0.36, 0.21))
            cap.position.y = 0.42
            tile.add_child(cap)
            _add_rock(tile, Vector3(-0.30, 0.12, 0.22), 0.12)
        TerrainState.TerrainType.MARSH:
            var pool := _make_cylinder(0.70, 0.035, 10, Color(0.10, 0.28, 0.25))
            pool.position.y = 0.14
            tile.add_child(pool)
            for pos in [Vector3(0.30, 0.28, 0.15), Vector3(-0.25, 0.26, -0.20), Vector3(0.05, 0.24, 0.32)]:
                var reed := _make_box(Vector3(0.035, 0.40, 0.035), Color(0.29, 0.42, 0.19))
                reed.position = pos
                reed.rotation_degrees.z = -8.0
                tile.add_child(reed)
        TerrainState.TerrainType.RIVER:
            var water := _make_box(Vector3(1.58, 0.045, 0.84), Color(0.10, 0.32, 0.43))
            water.position.y = 0.15
            water.rotation_degrees.y = 90
            tile.add_child(water)
            _add_rock(tile, Vector3(-0.46, 0.16, 0.34), 0.11)
            _add_rock(tile, Vector3(0.43, 0.15, -0.30), 0.09)
        TerrainState.TerrainType.ROAD:
            var road := _make_box(Vector3(1.42, 0.045, 0.38), Color(0.43, 0.32, 0.20))
            road.position.y = 0.15
            tile.add_child(road)
            var track := _make_box(Vector3(1.25, 0.012, 0.06), Color(0.28, 0.22, 0.15))
            track.position = Vector3(0, 0.18, -0.10)
            tile.add_child(track)
        TerrainState.TerrainType.PLAINS:
            if (coord.x * 11 + coord.y * 7) % 3 == 0:
                var grass := _make_cone(0.035, 0.18, 5, Color(0.38, 0.45, 0.22))
                grass.position = Vector3(-0.22, 0.18, 0.18)
                tile.add_child(grass)
            if (coord.x * 5 + coord.y * 3) % 7 == 0:
                _add_rock(tile, Vector3(0.32, 0.10, -0.22), 0.10)

func _add_forest_marker(tile: StaticBody3D, coord: Vector2i) -> void:
    # Lightweight fallback: keep Android startup reliable while preserving forest readability.
    var base := _make_cylinder(0.62, 0.10, 8, Color(0.12, 0.24, 0.12))
    base.position.y = 0.18
    tile.add_child(base)
    if (coord.x * 7 + coord.y * 11) % 3 == 0:
        var tree := _make_cone(0.24, 0.58, 7, Color(0.18, 0.34, 0.16))
        tree.position = Vector3(0, 0.52, 0)
        tile.add_child(tree)

func _build_loading_screen() -> void:
    loading_layer = CanvasLayer.new()
    loading_layer.layer = 100
    loading_layer.name = "RavenwoodLoading"
    add_child(loading_layer)

    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color(0.025, 0.055, 0.065, 1.0)
    loading_layer.add_child(background)

    var title := Label.new()
    title.position = Vector2(80, 150)
    title.size = Vector2(1120, 70)
    title.text = "SHATTERED REALMS"
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.65))
    loading_layer.add_child(title)

    loading_status = Label.new()
    loading_status.position = Vector2(82, 260)
    loading_status.size = Vector2(1116, 55)
    loading_status.add_theme_font_size_override("font_size", 28)
    loading_layer.add_child(loading_status)

    loading_detail = Label.new()
    loading_detail.position = Vector2(82, 322)
    loading_detail.size = Vector2(1116, 60)
    loading_detail.add_theme_font_size_override("font_size", 20)
    loading_detail.add_theme_color_override("font_color", Color(0.70, 0.85, 0.90))
    loading_layer.add_child(loading_detail)

    loading_bar = ProgressBar.new()
    loading_bar.position = Vector2(82, 430)
    loading_bar.size = Vector2(1116, 40)
    loading_bar.min_value = 0.0
    loading_bar.max_value = 1.0
    loading_bar.show_percentage = false
    loading_layer.add_child(loading_bar)

func _set_loading(progress: float, status: String, detail: String = "") -> void:
    if loading_bar != null:
        loading_bar.value = clamp(progress, 0.0, 1.0)
    if loading_status != null:
        loading_status.text = status
    if loading_detail != null:
        loading_detail.text = detail

func _build_commander() -> void:
    commander = Node3D.new()
    commander.name = "Commander_Edrin_Vale"
    commander.position = grid.to_world(commander_hex, HEX_SIZE) - _board_center()
    commander.position.y = _elevation(commander_hex) + 0.65

    var base := MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.38
    base_mesh.bottom_radius = 0.46
    base_mesh.height = 0.16
    base_mesh.radial_segments = 8
    base.mesh = base_mesh
    base.material_override = _material(Color(0.12, 0.15, 0.12), 0.8)
    commander.add_child(base)

    var body := MeshInstance3D.new()
    var body_mesh := CylinderMesh.new()
    body_mesh.top_radius = 0.18
    body_mesh.bottom_radius = 0.25
    body_mesh.height = 0.62
    body_mesh.radial_segments = 8
    body.mesh = body_mesh
    body.position.y = 0.38
    body.material_override = _material(Color(0.18, 0.24, 0.19), 0.2)
    commander.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.18
    head_mesh.height = 0.36
    head.mesh = head_mesh
    head.position.y = 0.78
    head.material_override = _material(Color(0.34, 0.27, 0.20), 0.4)
    commander.add_child(head)

    var banner := _make_box(Vector3(0.05, 0.72, 0.32), Color(0.16, 0.27, 0.19))
    banner.position = Vector3(0.12, 0.72, 0)
    commander.add_child(banner)

    add_child(commander)

func _build_locations() -> void:
    var locations: Array = ravenwood_data.get("starting_locations", [])
    if locations.is_empty():
        _build_keep(Vector2i(5, 8))
        _build_village(Vector2i(12, 10))
        _build_mine(Vector2i(18, 5))
    else:
        for location in locations:
            var coord := _array_to_coord(location.get("hex", [0, 0]))
            match String(location.get("type", "")):
                "fort":
                    _build_keep(coord)
                "village":
                    _build_village(coord)
                "mine":
                    _build_mine(coord)

    for location in ravenwood_data.get("hidden_locations", []):
        if bool(location.get("hidden", false)):
            _build_hidden_location(_array_to_coord(location.get("hex", [0, 0])), String(location.get("id", "Hidden Location")))

func _build_hidden_location(coord: Vector2i, location_id: String) -> void:
    var root := Node3D.new()
    root.name = location_id
    root.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    root.position.y = _elevation(coord) + 0.12
    root.visible = false
    add_child(root)

func _build_keep(coord: Vector2i) -> void:
    var root := Node3D.new()
    root.name = "Ravenwood_Keep"
    root.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    root.position.y = _elevation(coord) + 0.18
    for pos in [Vector3(-0.42, 0.28, -0.42), Vector3(0.42, 0.28, -0.42), Vector3(-0.42, 0.28, 0.42), Vector3(0.42, 0.28, 0.42)]:
        var tower := _make_cylinder(0.16, 0.55, 6, Color(0.30, 0.31, 0.29))
        tower.position = pos
        root.add_child(tower)
    var walls := _make_box(Vector3(0.82, 0.22, 0.10), Color(0.26, 0.27, 0.25))
    walls.position.y = 0.24
    root.add_child(walls)
    add_child(root)

func _build_village(coord: Vector2i) -> void:
    var root := Node3D.new()
    root.name = "Old_Road_Village"
    root.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    root.position.y = _elevation(coord) + 0.16
    for pos in [Vector3(-0.34, 0.20, -0.25), Vector3(0.28, 0.18, 0.18)]:
        var house := _make_box(Vector3(0.42, 0.32, 0.36), Color(0.42, 0.34, 0.24))
        house.position = pos
        root.add_child(house)
        var roof := _make_cone(0.30, 0.28, 4, Color(0.24, 0.16, 0.12))
        roof.position = pos + Vector3(0, 0.35, 0)
        root.add_child(roof)
    add_child(root)

func _build_mine(coord: Vector2i) -> void:
    var root := Node3D.new()
    root.name = "Whispering_Mine"
    root.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    root.position.y = _elevation(coord) + 0.18
    var mound := _make_cone(0.55, 0.55, 6, Color(0.25, 0.24, 0.22))
    mound.position.y = 0.24
    root.add_child(mound)
    var entrance := _make_cylinder(0.24, 0.08, 8, Color(0.05, 0.05, 0.045))
    entrance.position.y = 0.52
    root.add_child(entrance)
    add_child(root)

func _build_selection() -> void:
    selection_ring = MeshInstance3D.new()
    selection_ring.name = "SelectedHex"
    var ring := CylinderMesh.new()
    ring.top_radius = 0.92
    ring.bottom_radius = 0.92
    ring.height = 0.035
    ring.radial_segments = 6
    selection_ring.mesh = ring
    selection_ring.material_override = _material(Color(0.78, 0.66, 0.28), 0.15)
    selection_ring.visible = false
    add_child(selection_ring)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "GameplayHUD"
    add_child(layer)

    var panel := ColorRect.new()
    panel.position = Vector2(18, 18)
    panel.size = Vector2(350, 142)
    panel.color = Color(0.035, 0.03, 0.025, 0.90)
    layer.add_child(panel)

    turn_label = Label.new()
    turn_label.position = Vector2(16, 10)
    turn_label.add_theme_font_size_override("font_size", 22)
    panel.add_child(turn_label)

    movement_label = Label.new()
    movement_label.position = Vector2(16, 44)
    movement_label.add_theme_font_size_override("font_size", 18)
    panel.add_child(movement_label)

    army_label = Label.new()
    army_label.position = Vector2(16, 75)
    army_label.add_theme_font_size_override("font_size", 16)
    panel.add_child(army_label)

    terrain_label = Label.new()
    terrain_label.position = Vector2(16, 106)
    terrain_label.size = Vector2(318, 34)
    terrain_label.clip_text = true
    terrain_label.add_theme_font_size_override("font_size", 14)
    terrain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    terrain_label.text = "SELECT A HEX"
    panel.add_child(terrain_label)

    panel.size.y = 158

    var end_turn := Button.new()
    end_turn.text = "END TURN"
    end_turn.position = Vector2(18, 174)
    end_turn.size = Vector2(160, 52)
    end_turn.add_theme_font_size_override("font_size", 18)
    end_turn.pressed.connect(_end_turn)
    layer.add_child(end_turn)

func _refresh_hud() -> void:
    if turn_label == null or movement_label == null or army_label == null:
        return
    turn_label.text = "RAVENWOOD  •  TURN %d" % game_state.turn
    movement_label.text = "EDRIN VALE  •  MOVE %d / %d" % [game_state.hero.movement_remaining, game_state.hero.max_movement]
    army_label.text = "RANGERS  •  %d TROOPS  •  POWER %d" % [army_state.total_units(), army_state.combat_power()]
    if selected_hex.x >= 0:
        var terrain_name := _terrain_name(_terrain_type(selected_hex))
        var elev := _elevation(selected_hex)
        var cost := _movement_cost(selected_hex)
        terrain_label.text = "%s  •  ELEV %.1f  •  MOVE %d" % [terrain_name, elev, cost]
    else:
        terrain_label.text = "SELECT A HEX"

func _end_turn() -> void:
    game_state.begin_campaign_turn()
    commander_selected = false
    _clear_reachable()
    _refresh_hud()

func _clear_reachable() -> void:
    for marker in reachable_nodes.values():
        if is_instance_valid(marker):
            marker.queue_free()
    reachable_nodes.clear()
    reachable_hexes.clear()

func _movement_cost(coord: Vector2i) -> int:
    var state := TERRAIN_STATE.new()
    state.configure(_terrain_type(coord), int(round(_elevation(coord) * 10.0)))
    return state.movement_cost

func _terrain_name(terrain: TerrainState.TerrainType) -> String:
    match terrain:
        TerrainState.TerrainType.PLAINS: return "PLAINS"
        TerrainState.TerrainType.FOREST: return "FOREST"
        TerrainState.TerrainType.HILLS: return "HILLS"
        TerrainState.TerrainType.MOUNTAIN: return "MOUNTAIN"
        TerrainState.TerrainType.MARSH: return "MARSH"
        TerrainState.TerrainType.RIVER: return "RIVER"
        TerrainState.TerrainType.ROAD: return "ROAD"
        TerrainState.TerrainType.VILLAGE: return "VILLAGE"
        TerrainState.TerrainType.FORT: return "FORT"
        TerrainState.TerrainType.RUINS: return "RUINS"
        TerrainState.TerrainType.MINE: return "MINE"
        TerrainState.TerrainType.DUNGEON: return "DUNGEON"
    return "UNKNOWN"

func _terrain_type(coord: Vector2i) -> TerrainState.TerrainType:
    for location in ravenwood_data.get("starting_locations", []):
        if _array_to_coord(location.get("hex", [-1, -1])) == coord:
            match String(location.get("type", "")):
                "fort": return TerrainState.TerrainType.FORT
                "village": return TerrainState.TerrainType.VILLAGE
                "mine": return TerrainState.TerrainType.MINE
    for location in ravenwood_data.get("hidden_locations", []):
        if _array_to_coord(location.get("hex", [-1, -1])) == coord:
            return TerrainState.TerrainType.DUNGEON
    if _is_river(coord):
        return TerrainState.TerrainType.RIVER
    if _is_road(coord):
        return TerrainState.TerrainType.ROAD
    if coord.x >= 17 and coord.y <= 6:
        return TerrainState.TerrainType.MOUNTAIN
    if coord.x <= 7 and coord.y >= 10:
        return TerrainState.TerrainType.MARSH
    if coord.x >= 9 and coord.x <= 12 and coord.y >= 5 and coord.y <= 13:
        return TerrainState.TerrainType.FOREST
    if _elevation(coord) > 0.9:
        return TerrainState.TerrainType.HILLS
    return TerrainState.TerrainType.PLAINS

func _is_river(coord: Vector2i) -> bool:
    return coord.x == 14 and coord.y >= 1 and coord.y <= 14

func _is_road(coord: Vector2i) -> bool:
    return (coord.y == 9 and coord.x >= 5 and coord.x <= 18) or (coord.y == 10 and coord.x >= 12 and coord.x <= 17)

func _show_reachable() -> void:
    _clear_reachable()
    var budget := game_state.hero.movement_remaining
    if budget <= 0:
        return
    var frontier: Array[Vector2i] = [game_state.hero.hex]
    var costs: Dictionary = {game_state.hero.hex: 0}
    var head := 0
    while head < frontier.size():
        var current_coord: Vector2i = frontier[head]
        head += 1
        var current_cost: int = costs[current_coord]
        for neighbor in grid.neighbors(current_coord):
            var next_cost := current_cost + _movement_cost(neighbor)
            if next_cost > budget:
                continue
            if not costs.has(neighbor) or next_cost < int(costs[neighbor]):
                costs[neighbor] = next_cost
                frontier.append(neighbor)
    costs.erase(game_state.hero.hex)
    for coord in costs.keys():
        reachable_hexes[coord] = int(costs[coord])
        var marker := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.78
        mesh.bottom_radius = 0.78
        mesh.height = 0.035
        mesh.radial_segments = 6
        marker.mesh = mesh
        marker.position = grid.to_world(coord, HEX_SIZE) - _board_center()
        marker.position.y = _elevation(coord) + 0.12
        marker.material_override = _material(Color(0.30, 0.50, 0.32), 0.0)
        add_child(marker)
        reachable_nodes[coord] = marker

func _move_commander(destination: Vector2i, cost: int) -> void:
    if not game_state.hero.spend(cost):
        return
    commander_hex = destination
    game_state.hero.hex = destination
    army_state.hex = destination
    commander.position = grid.to_world(destination, HEX_SIZE) - _board_center()
    commander.position.y = _elevation(destination) + 0.65
    selection_ring.position = grid.to_world(destination, HEX_SIZE) - _board_center()
    selection_ring.position.y = _elevation(destination) + 0.14
    _show_reachable()
    _refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_active = true
            touch_start = event.position
            touch_moved = false
        elif touch_active:
            if event.position.distance_to(touch_start) < 14.0 and not touch_moved:
                _select_from_screen(event.position)
            touch_active = false
    elif event is InputEventScreenDrag:
        if touch_active and event.position.distance_to(touch_start) > 14.0:
            touch_moved = true
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _select_from_screen(event.position)

func _select_from_screen(screen_position: Vector2) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    if abs(direction.y) < 0.0001:
        return
    var world_y := 0.55
    var distance := (world_y - origin.y) / direction.y
    if distance <= 0.0:
        return
    var hit := origin + direction * distance
    var board_point := hit + _board_center()
    var approx_x := int(round(board_point.x / (HEX_SIZE * 1.5)))
    var approx_y := int(round(board_point.z / (HEX_SIZE * sqrt(3.0)) - (0.5 if (approx_x & 1) else 0.0)))
    var best := Vector2i(-1, -1)
    var best_dist := 999999.0
    for x in range(max(0, approx_x - 1), min(BOARD_WIDTH, approx_x + 2)):
        for y in range(max(0, approx_y - 1), min(BOARD_HEIGHT, approx_y + 2)):
            var coord := Vector2i(x, y)
            var center := grid.to_world(coord, HEX_SIZE) - _board_center()
            var d := Vector2(center.x - hit.x, center.z - hit.z).length_squared()
            if d < best_dist:
                best_dist = d
                best = coord
    if not grid.is_valid(best):
        return
    if commander_selected and reachable_hexes.has(best):
        _move_commander(best, int(reachable_hexes[best]))
    else:
        select_hex(best)

func select_hex(coord: Vector2i) -> void:
    if not grid.is_valid(coord):
        return
    selected_hex = coord
    selection_ring.visible = true
    selection_ring.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    selection_ring.position.y = _elevation(coord) + 0.14
    commander_selected = coord == game_state.hero.hex
    if commander_selected:
        _show_reachable()
    else:
        _clear_reachable()
    _refresh_hud()
    print("Selected Ravenwood hex: ", coord)

func _board_center() -> Vector3:
    var a := grid.to_world(Vector2i(0, 0), HEX_SIZE)
    var b := grid.to_world(Vector2i(BOARD_WIDTH - 1, BOARD_HEIGHT - 1), HEX_SIZE)
    return (a + b) * 0.5

func _elevation(coord: Vector2i) -> float:
    var ridge := sin(float(coord.x) * 0.55) * 0.55
    var north := float(coord.y) * 0.045
    var hills := sin(float(coord.x + coord.y) * 0.31) * 0.28
    var value := ridge + hills + north
    if coord.x >= 17 and coord.y <= 6:
        value += 0.75
    if coord.x <= 7 and coord.y >= 10:
        value -= 0.12
    return clamp(value, 0.0, 1.7)

func _terrain_material(coord: Vector2i) -> StandardMaterial3D:
    var key := "plains"
    if _is_river(coord):
        key = "river"
    elif _is_road(coord):
        key = "road"
    elif coord.x >= 17 and coord.y <= 6:
        key = "mountain"
    elif coord.x <= 7 and coord.y >= 10:
        key = "marsh"
    elif coord.x >= 9 and coord.x <= 12 and coord.y >= 5 and coord.y <= 13:
        key = "forest"
    elif _elevation(coord) > 0.9:
        key = "hills"
    if shared_terrain_materials.has(key):
        return shared_terrain_materials[key]
    var colors := {
        "plains": Color(0.28, 0.34, 0.20),
        "forest": Color(0.13, 0.30, 0.17),
        "hills": Color(0.27, 0.25, 0.19),
        "mountain": Color(0.30, 0.29, 0.27),
        "marsh": Color(0.20, 0.28, 0.19),
        "river": Color(0.10, 0.34, 0.46),
        "road": Color(0.32, 0.27, 0.19)
    }
    var material := _material(colors[key], 0.0)
    shared_terrain_materials[key] = material
    return material

func _make_cylinder(radius: float, height: float, segments: int, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    node.mesh = mesh
    node.material_override = _material(color, 0.0)
    return node

func _make_cone(radius: float, height: float, segments: int, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.02
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    node.mesh = mesh
    node.material_override = _material(color, 0.0)
    return node

func _make_box(size: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _material(color, 0.0)
    return node

func _material(color: Color, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = 0.55
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material
