extends PanelContainer

const NEWS_ELEMENT = preload("uid://ddgnmdkwq7gb4")
@onready var texture_loading: TextureRect = $TextureLoading
@onready var posts_container: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer
@onready var container_no_results: VBoxContainer = $ContainerNoResults


func _ready() -> void:
	ContentGetter.posts_gotten.connect(_populate_news_posts)


func empty_news_posts() -> void:
	texture_loading.visible = true
	
	for child in  posts_container.get_children():
		child.queue_free()


func _populate_news_posts() -> void:
	texture_loading.visible = false
	if ContentGetter.news_posts.is_empty():
		container_no_results.visible = true
		return
	
	for post in ContentGetter.news_posts:
		var element = NEWS_ELEMENT.instantiate()
		posts_container.add_child(element)
		element.init_ui(post)
