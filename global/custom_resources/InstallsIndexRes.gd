class_name InstallsIndexRes
extends Resource

class Install:
	var mod_id: String
	var version: String
	var platform: String
	var executable_path: String
	var dltmp_path: String		# folder where the temporary file that was just downloaded (ends with a "/")
	var timestamp: String

var installs: Array[Install]
