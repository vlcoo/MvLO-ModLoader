class_name SelfUpdaterUpdate
extends Resource

@export var date: String
@export_multiline var changelog: String
@export var vercode: int


func _init(update_date: String, update_changelog: String, update_vercode: int) -> void:
	date = update_date
	changelog = update_changelog
	vercode = update_vercode
