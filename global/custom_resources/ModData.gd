@icon("res://graphics/puzzle.png")

## Represents an entry in the games list.
class_name ModData
extends Resource

var icon: Texture2D
var cover_image: Texture2D

var gamefile_urls: Dictionary = {}
var timestamp: String = "0"

## Full name of this mod.
@export var name: String
## Abbreviation, short name or alternative name of this mod.
@export var abbreviation: String
## Who made this mod.
@export var author: String
## The version of the base game this mod was based on.
@export var base_version: String = "?"
## One-liner explaining what this mod has to offer.
@export_multiline var description: String
## This option should be enabled if this mod doesn't implement Discord presence status.
@export var needs_discord_activity: bool = false
## Websites of interest.
@export_group("Public links", "link_")
## URL of the main website of this mod.
@export var link_main_website: String
## URL where the repository containing the source code of this mod is hosted, if any.
@export var link_source_code: String
## List of URLs to the Discord servers, channels or threads of this mod.
@export var link_discord: PackedStringArray
