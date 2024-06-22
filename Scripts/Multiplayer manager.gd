extends Node

const DEFAULT_PORT = 4225
const MAX_PEERS = 6
var players = {}

var player_name: String
var peer

signal player_connected(peer_id, player_info)

func p(msg):
	if not multiplayer.multiplayer_peer or not peer:
		print(msg)
		return
	
	var colour = "red" if multiplayer.multiplayer_peer.get_unique_id() == 1 else "green"		
	if multiplayer.multiplayer_peer.get_unique_id() != peer.get_unique_id():
		colour = "blue" 
	print_rich("[color=%s]%s[color=#ffffff]" % [colour, msg])

func _ready():
	RivetHelper.start_server.connect(start_server)
	RivetHelper.setup_multiplayer()
	
	#multiplayer.peer_connected.connect(self._player_connected)
	#multiplayer.peer_disconnected.connect(self._player_disconnected)
	#multiplayer.connected_to_server.connect(self._connected_ok)
	#multiplayer.connection_failed.connect(self._connected_fail)
	#multiplayer.server_disconnected.connect(self._server_disconnected)

func start_server(username):
	p("[MultiplayerManager::start_server] Starting server on %s" % DEFAULT_PORT)
	
	peer = ENetMultiplayerPeer.new()
	peer.create_server(42250, 6)
	multiplayer.set_multiplayer_peer(peer)
	await Rivet.matchmaker.lobbies.ready({})
	
	#p("[MultiplayerManager::create_game] Setting my_player to %s" % username)
	#my_player = construct_player(username, peer)
	#players[1] = my_player
	#my_player_id = peer.get_unique_id()

func join_game(new_player_name):
	player_name = new_player_name

	RivetClient.find_lobby({
		"game_modes": ["default"]
	}, _lobby_found, _lobby_find_failed)

func _lobby_found():
	p("[MultiplayerManager::_lobby_found] Lobby found!")

func _lobby_find_failed(msg):
	p("[MultiplayerManager::_lobby_find_failed] Lobby find failed: %s" % msg)

func _on_player_connected(id):
	p("[MultiplayerManager::_on_player_connected]" % multiplayer.multiplayer_peer.get_unique_id())
	#register_player.rpc_id(id, my_player)

@rpc("any_peer", "reliable")
func register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	p("[MultiplayerManager::register_player] Registering player %s" % new_player_id)
	#players[new_player_id] = new_player_info
	#player_connected.emit(new_player_id, new_player_info)


func construct_player(name, peer):
	return { "name": name, "peer": peer }

func stop():
	multiplayer.multiplayer_peer = null

func peer_joined(player):
	pass

@rpc("any_peer", "call_local", "unreliable_ordered")
func spawn_player(playerid_in_question):
	var sender_id = multiplayer.get_remote_sender_id()
	MultiplayerManager.p("[Player::spawn] %s players: %s" % [sender_id, MultiplayerManager.players])
	#var piq = MultiplayerManager.players[playerid_in_question]
	#MultiplayerManager.p("[Player::spawn] %s Spawned %s" % [sender_id, piq])
