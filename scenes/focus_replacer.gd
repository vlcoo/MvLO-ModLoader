extends Container

## The node that will try to grab focus if this container is focused.
@export_node_path("Control") var desired_node: NodePath
## List of nodes that will try to replace the desired node's focus if it's
## hidden.
@export var replacements: Array[NodePath]
## Not only replace the desired node's focus when it's hidden, but also
## when it's disabled (only applies to buttons).
@export var also_replace_if_disabled := false

var desired_control: Control


func _ready() -> void:
	assert(focus_mode != FOCUS_NONE, "This container must be focuseable for the Focus Replacer script to work.")
	focus_entered.connect(_on_focus_entered)
	
	desired_control = get_node(desired_node)


func _on_focus_entered() -> void:
	if desired_control.visible and (not also_replace_if_disabled or (also_replace_if_disabled and desired_control is BaseButton and not desired_control.disabled)):
		desired_control.grab_focus.call_deferred()
	else:
		for path in replacements:
			var n = get_node(path)
			assert(n is Control, "The replacements must be Control nodes.")
			if n.visible and (n is BaseButton and not n.disabled):
				n.grab_focus.call_deferred()
				return
