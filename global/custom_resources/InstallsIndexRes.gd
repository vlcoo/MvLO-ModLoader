class_name InstallsIndexRes
extends Resource

# needs to be dictionary to save to file lol
const Install: Dictionary = {
	"mod_id": "",
	"version": "",
	"platform": "",
	"executable_path": "",
	"dltmp_path": "",		# folder where the temporary file that was just downloaded (ends with a "/")
	"timestamp": "",
	"size": 0
}

@export var installs: Array[Dictionary]
