extends Node3D

@export var pan_speed := 12.0
@export var zoom_speed := 1.5
@export var min_zoom := 12.0
@export var max_zoom := 36.0

var target_zoom := 25.0

func _ready() -> void:
    target_zoom = $Camera3D.position.y

func _process(delta: float) -> void:
    var direction := Vector3.ZERO
    if Input.is_action_pressed("camera_pan_up"):
        direction.z -= 1.0
    if Input.is_action_pressed("camera_pan_down"):
        direction.z += 1.0
    if Input.is_action_pressed("camera_pan_left"):
        direction.x -= 1.0
    if Input.is_action_pressed("camera_pan_right"):
        direction.x += 1.0

    if direction.length_squared() > 0.0:
        global_position += direction.normalized() * pan_speed * delta

    $Camera3D.position.y = lerp($Camera3D.position.y, target_zoom, 8.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)
