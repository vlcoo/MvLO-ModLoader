@icon("res://graphics/puzzle.png")

## Represents an entry in the games list.
class_name ModData
extends Resource

## Where the game files are hosted, and which API to use.
enum DownloadMethods {
	ITCH, ## itch.io game.
	GITHUB, ## GitHub releases page.
	CUSTOM_DIRECT, ## Direct download from a custom URL.
	CUSTOM_REDIRECT ## Open custom URL in browser.
}

var icon: Texture2D
var cover_image: Texture2D

var gamefile_urls: Dictionary = {
	"Dummy": {
		"N/A": ""
	}
}

## Information about this mod.
@export_category("Mod Data")
## Full name of this mod.
@export var name: String
## Abbreviation, short name or alternative name of this mod.
@export var abbreviation: String
## Who made this mod.
@export var author: String
## Blurb explaining what this mod has to offer.
@export_multiline var description: String
## API or download method to use for getting the mod.
@export var download_method: DownloadMethods
## URL where the game files are hosted.
@export var download_url: String
## Websites of interest.
@export_group("Public links", "link_")
## URL of the main website of this mod.
@export var link_main_website: String
## URL where the repository containing the source code of this mod is hosted, if any.
@export var link_source_code: String
## List of URLs to the Discord servers, channels or threads of this mod.
@export var link_discord: PackedStringArray
