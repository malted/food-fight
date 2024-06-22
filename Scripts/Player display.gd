extends RichTextLabel

func _ready():
	if multiplayer.is_server():
		set_playerlist()
		MultiplayerManager.player_connected.connect(player_joined)

func player_joined(peer_id, player_info):
	set_playerlist()
	
func set_playerlist():
	var names = MultiplayerManager.players.values().map(assemble_player_display_line)
	var text = "[b]Players[/b]\n" + "\n".join(names)
	set_text(text)

func assemble_player_display_line(player):
	#return "%s (%s)" % [player["name"], player["peer"].get_unique_id()]
	return player["name"]
