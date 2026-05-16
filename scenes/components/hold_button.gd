extends Button
class_name HoldButton

@export var action: Callable
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var tween: Tween
var original_text := ""


func _ready() -> void:
	original_text = text
	action = func(): print("ok1!")


func _on_button_down() -> void:
	animation_player.stop()
	text = original_text
	tween = create_tween()
	tween.tween_property(progress_bar, ^"value", 100.0, 1.0).from_current()


func _on_button_up() -> void:
	if tween and tween.is_running(): tween.stop()
	var didnt_hold = progress_bar.value < progress_bar.max_value
	progress_bar.value = 0.0
	if didnt_hold:
		animation_player.play(&"didnt_hold")
	else:
		action.call()


func restore_text():
	text = original_text
