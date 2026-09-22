extends Control

var elapsed := 0.0
var progress_bar: ProgressBar
var status_label: Label
var detail_label: Label

func _ready() -> void:
    progress_bar = get_node_or_null("Progress") as ProgressBar
    status_label = get_node_or_null("Status") as Label
    detail_label = get_node_or_null("Detail") as Label
    print("BOOT TEST: Control scene rendered successfully.")
    set_process(true)

func _process(delta: float) -> void:
    elapsed += delta
    if progress_bar != null:
        progress_bar.value = min(100.0, elapsed / 0.8 * 100.0)
    if elapsed >= 0.25 and status_label != null:
        status_label.text = "ANDROID BOOT OK — STARTING RAVENWOOD"
    if elapsed >= 0.45 and detail_label != null:
        detail_label.text = "2D boot confirmed
Loading the optimized 3D territory next"
    if elapsed >= 0.80:
        set_process(false)
        get_tree().change_scene_to_file("res://scenes/Main.tscn")
