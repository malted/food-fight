extends Node3D

#region Inputs
@export var username_input: LineEdit
@export var join_server_button: Button
#endregion

func _ready():
	join_server_button.pressed.connect(join)
	
	if OS.get_environment("USERNAME"):
		username_input.set_text(OS.get_environment("USERNAME"))
	elif OS.get_environment("USER"):
		username_input.set_text(OS.get_environment("USER"))
	else:
		var desktop_path = OS.get_system_dir(0).replace("\\", "/").split("/")
		username_input.set_text(desktop_path[desktop_path.size() - 2])

func join():
	var username = username_input.get_text()
	if username == "":
		print("Username can not be emtpy")
		return
		
	MultiplayerManager.join_game(username)

func load_game():
	get_tree().change_scene_to_file("res://Level.tscn")
