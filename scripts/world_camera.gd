extends Node3D

@export var pan_speed := 12.0
@export var zoom_speed := 1.5
@export var min_zoom := 12.0
@export var max_zoom := 36.0
@export var touch_pan_scale := 0.035
@export var pinch_zoom_scale := 0.012

var target_zoom := 25.0
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var last_mouse_drag := Vector2.ZERO

func _ready() -> void:
    target_zoom = clamp($Camera3D.position.y, min_zoom, max_zoom)

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
            _set_zoom(target_zoom - zoom_speed)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(target_zoom + zoom_speed)
        elif event.button_index == MOUSE_BUTTON_MIDDLE:
            last_mouse_drag = event.position
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
        _pan_screen_delta(event.position - last_mouse_drag)
        last_mouse_drag = event.position
    elif event is InputEventScreenTouch:
        if event.pressed:
            touch_points[event.index] = event.position
            if touch_points.size() == 2:
                last_pinch_distance = _touch_distance()
        else:
            touch_points.erase(event.index)
            if touch_points.size() < 2:
                last_pinch_distance = 0.0
    elif event is InputEventScreenDrag:
        touch_points[event.index] = event.position
        if touch_points.size() >= 2:
            var distance := _touch_distance()
            if last_pinch_distance > 0.0:
                _set_zoom(target_zoom - (distance - last_pinch_distance) * pinch_zoom_scale)
            last_pinch_distance = distance
        else:
            _pan_screen_delta(event.relative)

func _touch_distance() -> float:
    if touch_points.size() < 2:
        return 0.0
    var points := touch_points.values()
    return (points[0] as Vector2).distance_to(points[1] as Vector2)

func _pan_screen_delta(delta: Vector2) -> void:
    if delta.length_squared() <= 0.01:
        return
    var scale := max(target_zoom, 1.0) * touch_pan_scale
    global_position += Vector3(-delta.x * scale, 0.0, -delta.y * scale)

func _set_zoom(value: float) -> void:
    target_zoom = clamp(value, min_zoom, max_zoom)
