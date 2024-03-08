extends Node

enum MapOption {
	FOREST,
	PATH,
	DUNGEON,
}

@onready var main_menu: Node = $CanvasLayer/MainMenu
@onready var address_entry: Node = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud: Node = $CanvasLayer/HUD

const PLAYER: PackedScene = preload("res://player/player.tscn")
const PORT: int = 9999

var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var current_map: MapOption

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_forest_button_pressed():
	start_server(MapOption.FOREST)

func _on_host_path_button_pressed():
	start_server(MapOption.PATH)

func _on_host_dungeon_button_pressed():
	start_server(MapOption.DUNGEON)

func load_map(map_option):
	current_map = map_option
	match map_option:
		MapOption.FOREST:
			var forest_scene: PackedScene = load("res://maps/forest.tscn")
			add_child(forest_scene.instantiate())
		MapOption.PATH:
			var path_scene: PackedScene = load("res://maps/path.tscn")
			add_child(path_scene.instantiate())
		MapOption.DUNGEON:
			var path_scene: PackedScene = load("res://maps/dungeon.tscn")
			add_child(path_scene.instantiate())

func start_server(map_option):
	main_menu.hide()
	hud.show()

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	load_map(map_option)
	add_player(multiplayer.get_unique_id())

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()

	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player: Node = PLAYER.instantiate()
	player.name = str(peer_id)
	rpc("sync_load_map", current_map)
	add_child(player)

@rpc("any_peer")
func sync_load_map(map_option):
	load_map(map_option)

func remove_player(peer_id):
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


