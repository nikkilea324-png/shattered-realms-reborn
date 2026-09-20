extends Node3D

const HEX_GRID := preload("res://scripts/hex_grid.gd")

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

func _ready() -> void:
    grid.configure(BOARD_WIDTH, BOARD_HEIGHT)
    _build_ravenwood()
    _build_commander()
    _build_locations()
    _build_selection()
    print("Ravenwood visual slice initialized: %d hexes" % grid.hex_count())

func _build_ravenwood() -> void:
    var center := _board_center()
    for y in range(BOARD_HEIGHT):
        for x in range(BOARD_WIDTH):
            var coord := Vector2i(x, y)
            var tile := StaticBody3D.new()
            tile.name = "Hex_%d_%d" % [x, y]
            tile.position = grid.to_world(coord, HEX_SIZE) - center
            tile.position.y = _elevation(coord)

            var mesh_instance := MeshInstance3D.new()
            var mesh := CylinderMesh.new()
            mesh.top_radius = HEX_SIZE
            mesh.bottom_radius = HEX_SIZE
            mesh.height = HEX_HEIGHT
            mesh.radial_segments = 6
            mesh.rings = 1
            mesh.rotation_degrees = Vector3(0, 30, 0)
            mesh_instance.mesh = mesh
            mesh_instance.position.y = -HEX_HEIGHT * 0.5
            mesh_instance.material_override = _terrain_material(coord)
            tile.add_child(mesh_instance)

            var collision := CollisionShape3D.new()
            var shape := CylinderShape3D.new()
            shape.radius = HEX_SIZE
            shape.height = HEX_HEIGHT
            collision.shape = shape
            collision.position.y = -HEX_HEIGHT * 0.5
            tile.add_child(collision)

            add_child(tile)
            hex_nodes[coord] = tile

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

    add_child(commander)

func _build_locations() -> void:
    _build_location_marker(Vector2i(5, 8), "Ravenwood Keep", Color(0.32, 0.32, 0.28), 0.55)
    _build_location_marker(Vector2i(12, 10), "Old Road Village", Color(0.36, 0.28, 0.18), 0.38)
    _build_location_marker(Vector2i(18, 5), "Whispering Mine", Color(0.22, 0.25, 0.27), 0.34)

func _build_location_marker(coord: Vector2i, label: String, color: Color, height: float) -> void:
    var marker := MeshInstance3D.new()
    marker.name = label.replace(" ", "_")
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.22
    mesh.bottom_radius = 0.30
    mesh.height = height
    mesh.radial_segments = 6
    marker.mesh = mesh
    marker.material_override = _material(color, 0.05)
    marker.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    marker.position.y = _elevation(coord) + 0.20 + height * 0.5
    add_child(marker)

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

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _select_from_screen(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _select_from_screen(event.position)

func _select_from_screen(screen_position: Vector2) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return

    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
    query.collision_mask = 1
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return

    var body := hit.get("collider") as StaticBody3D
    if body == null:
        return

    var parts := body.name.split("_")
    if parts.size() != 3:
        return

    select_hex(Vector2i(int(parts[1]), int(parts[2])))

func select_hex(coord: Vector2i) -> void:
    if not grid.is_valid(coord):
        return
    selected_hex = coord
    selection_ring.visible = true
    selection_ring.position = grid.to_world(coord, HEX_SIZE) - _board_center()
    selection_ring.position.y = _elevation(coord) + 0.14
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
    var material := StandardMaterial3D.new()
    var elevation := _elevation(coord)
    var value := int((coord.x * 7 + coord.y * 13) % 9)

    if coord.x >= 17 and coord.y <= 6:
        material.albedo_color = Color(0.30, 0.29, 0.27)
        material.roughness = 0.96
    elif coord.x <= 7 and coord.y >= 10:
        material.albedo_color = Color(0.20, 0.28, 0.19)
        material.roughness = 0.92
    elif coord.x >= 9 and coord.x <= 12 and coord.y >= 5 and coord.y <= 13:
        material.albedo_color = Color(0.15, 0.24, 0.16)
        material.roughness = 0.9
    elif elevation > 0.9:
        material.albedo_color = Color(0.26, 0.27, 0.24)
        material.roughness = 0.96
    elif elevation > 0.45:
        material.albedo_color = Color(0.27, 0.25, 0.19)
        material.roughness = 0.94
    else:
        material.albedo_color = Color(0.24 + value * 0.008, 0.27 + value * 0.006, 0.19 + value * 0.004)
        material.roughness = 0.88
    return material

func _material(color: Color, metallic: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = 0.55
    return material
