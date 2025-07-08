@icon("res://audiovisual/puzzle.png")

## Represents an entry in the games list.
class_name ModData
extends Resource

var idx: String: 
	get: return id	# legacy
@export var timestamp: String = "0"

## A unique identifier for this mod.
@export var id: String
## Full name of this mod.
@export var name: String
## Abbreviation, short name or alternative name of this mod.
@export var abbreviation: String
## Who made this mod.
@export var author: String = "Anonymous"
## This mod's logo.
@export var cover_image: Texture2D
## A small image, alternative to the logo.
@export var icon: Texture2D
## The version of the base game this mod was based on.
@export var base_version: String = "?"
## One-liner explaining what this mod has to offer.
@export_multiline var description: String = "Description unavailable."
## This option should be enabled if this mod doesn't implement Discord presence status.
@export var needs_discord_activity: bool = false
## Does this mod use the same servers as vanilla does?
@export var vanilla_compatible: bool = false
## Websites of interest.
@export_group("Public links", "link_")
## URL of the main website of this mod.
@export var link_main_website: String
## URL where the repository containing the source code of this mod is hosted, if any.
@export var link_source_code: String
## List of URLs to the Discord servers, channels or threads of this mod.
@export var link_discord: PackedStringArray
## List of URLs for each version available for download.
@export var gamefile_urls: Array = []


static func new_from_json(json: Dictionary) -> ModData:
	var mod := ModData.new()
	
	mod.id = json.get("id", "")
	mod.name = json.get("name", "No Data!")
	mod.author = json.get("author", "Anonymous")
	mod.description = json.get("description", "Description unavailable.")
	mod.base_version = json.get("base_version", "")
	mod.needs_discord_activity = false if json.get("needs_discord_activity") == null else json.get("needs_discord_activity")
	mod.vanilla_compatible = false if json.get("vanilla_compatible") == null else json.get("vanilla_compatible")
	if mod.id == "vanilla": mod.vanilla_compatible = true
	mod.link_main_website = json.get("link_main_website", "")
	mod.link_source_code = json.get("link_source_code", "")
	mod.link_discord.append(json.get("link_discord_server", ""))
	mod.link_discord.append(json.get("link_discord_thread", ""))
	mod.gamefile_urls = json.get("gamefile_urls", [])
	
	var max_ts: int = 0
	for gamefile in mod.gamefile_urls:
		if gamefile.get("timestamp", 0) > max_ts: max_ts = gamefile.get("timestamp", 0)
	mod.timestamp = str(max_ts)
	
	if json.get("image_cover") not in ["", null]:
		var img_cover = Image.new()
		img_cover.load_webp_from_buffer(Marshalls.base64_to_raw(json["image_cover"]))
		mod.cover_image = ImageTexture.create_from_image(img_cover)
	if json.get("image_icon") not in ["", null]:
		var img_icon = Image.new()
		img_icon.load_webp_from_buffer(Marshalls.base64_to_raw(json["image_icon"]))
		mod.icon = ImageTexture.create_from_image(img_icon)
	
	return mod


func get_gamefiles_versions() -> Array:
	var a = []
	for g in gamefile_urls:
		if not a.has(g["version"]): a.append(g["version"])
	return a


func get_gamefiles_version(version: String) -> Array:
	var a = gamefile_urls.filter(func(g): return g["version"] == version if g.has("version") else false)
	return a


func get_gamefiles_platform(version_urls: Array, platform: String) -> Array:
	var a = version_urls.filter(func(g): return g["platform"] == platform if g.has("platform") else false)
	return a


func get_gamefiles_url(version: String, platform: String) -> Dictionary:
	var a1 = get_gamefiles_version(version)
	var a2 = get_gamefiles_platform(a1, platform)
	return a2[0]
