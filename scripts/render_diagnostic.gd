extends Node3D

func _ready() -> void:
    print("3D DIAGNOSTIC: RenderDiagnostic reached.")
    var camera := $Camera3D as Camera3D
    camera.current = true
    camera.look_at(Vector3.ZERO, Vector3.UP)
