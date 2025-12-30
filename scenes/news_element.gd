class_name NewsElement
extends PanelContainer

@onready var label_title: Label = $VBoxContainer/LabelTitle
@onready var label_subtitle: Label = $VBoxContainer/LabelSubtitle
@onready var label_contents: Label = $VBoxContainer/LabelContents


func init_ui(post: NewsPost) -> void:
	label_title.text = post.title
	var datetime = Time.get_datetime_dict_from_unix_time(post.timestamp)
	label_subtitle.text = "%04d-%02d-%02d by %s" % [datetime["year"], datetime["month"], datetime["day"], post.author]
	label_contents.text = post.message
