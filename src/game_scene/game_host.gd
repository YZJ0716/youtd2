class_name GameHost extends Node


# Host receives actions from peers, combines them into
# "timeslots" and sends timeslots back to the peers. A
# "timeslot" is a group of actions for a given tick. A host
# has it's own tick, independent of the GameClient on the
# host's client. Host sends timeslots periodically with an
# interval equal to current "turn length" value.
# 
# Note that server peer acts as a host and a peer at the
# same time.

# NOTE: GameHost node needs to be positioned before
# GameClient node in the tree, so that it is processed
# first.


enum HostState {
	RUNNING,
	WAITING_FOR_LAGGING_PLAYERS,
}

# NOTE: these values determine the "catch up" window. When
# the client falls behind latest timeslot by "start" value,
# it will start to catch up by fast forwarding (multiple
# game ticks per physics tick). Client will keep fast
# forwarding until reaching the "stop" value. Start and stop
# values are multiples of current turn length.
# NOTE: 3 ticks at 30ticks/second = 100ms
const MULTIPLAYER_TURN_LENGTH: int = 3
const SINGLEPLAYER_TURN_LENGTH: int = 1
const TICK_DELTA: float = 1000 / 30.0
# LAG_TIME_MSEC is the max time since last contact from
# player. If host hasn't received any responses from player
# for this long, host will start considering that player to
# be lagging and will pause game turns.
const LAG_TIME_MSEC: float = 2000.0

@export var _game_client: GameClient
@export var _hud: HUD


var _current_tick: int = 0
var _turn_length: int
var _in_progress_timeslot: Array = []
var _last_timeslot_tick: int = 0
var _player_ping_time_map: Dictionary = {}
var _player_last_contact_time: Dictionary = {}
var _player_checksum_map: Dictionary = {}
var _showed_desync_message: bool = false
# NOTE: initial state is WAITING_FOR_LAGGING_PLAYERS until
# host confirms that all players have connected successfully
# and finished loading game scene.
var _state: HostState = HostState.WAITING_FOR_LAGGING_PLAYERS
var _player_ready_map: Dictionary = {}


#########################
###     Built-in      ###
#########################

func _ready():
	if !multiplayer.is_server():
		return

	PlayerManager.players_created.connect(_on_players_created)
	
	_turn_length = Utils.get_turn_length()

#	TODO: move this timer to scene (need to create game host
#	scene first)
	var alive_check_timer: Timer = Timer.new()
	alive_check_timer.wait_time = 1.0
	alive_check_timer.autostart = true
	alive_check_timer.one_shot = false
	alive_check_timer.timeout.connect(_on_alive_check_timer_timeout)
	add_child(alive_check_timer)


func _physics_process(_delta: float):
	if !multiplayer.is_server():
		return

	match _state:
		HostState.RUNNING: _update_state_running()
		HostState.WAITING_FOR_LAGGING_PLAYERS: pass


#########################
###       Public      ###
#########################

@rpc("any_peer", "call_local", "reliable")
func receive_alive_check_response():
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player: Player = PlayerManager.get_player_by_peer_id(peer_id)
	var player_id: int = player.get_id()

	_update_last_contact_time_for_player(player_id)


# Receive action sent from client to host. Actions are
# compiled into timeslots - a group of actions from all
# clients.
@rpc("any_peer", "call_local", "reliable")
func receive_action(action: Dictionary):
	if _state != HostState.RUNNING:
		return

#	NOTE: need to attach player id to action in this host
#	function to ensure safety. If we were to let clients
#	attach player_id to actions, then clients could attach
#	any value.
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player: Player = PlayerManager.get_player_by_peer_id(peer_id)
	var player_id: int = player.get_id()
	action[Action.Field.PLAYER_ID] = player_id

	_in_progress_timeslot.append(action)


@rpc("any_peer", "call_local", "reliable")
func receive_timeslot_ack(checksum: PackedByteArray):
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player: Player = PlayerManager.get_player_by_peer_id(peer_id)
	var player_id: int = player.get_id()

	if !_player_checksum_map.has(player_id):
		_player_checksum_map[player_id] = []
	_player_checksum_map[player_id].append(checksum)


# TODO: handle case where some player is not ready. Need to
# show this as message to all players as "Waiting for
# players...". Also need to add an option to leave the game
# if the wait is too long.

# Called by players to let the host know that player is
# loaded and ready to start simulating the game. Host will
# not start incrementing simulation ticks until all players
# are ready.
@rpc("any_peer", "call_local", "reliable")
func receive_player_ready():
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player: Player = PlayerManager.get_player_by_peer_id(peer_id)
	var player_id: int = player.get_id()

	_player_ready_map[player_id] = true

	var all_players_are_ready: bool = true
	var player_list: Array[Player] = PlayerManager.get_player_list()
	for this_player in player_list:
		var this_player_id: int = this_player.get_id()
		var this_player_is_ready: bool = _player_ready_map.has(this_player_id)

		if !this_player_is_ready:
			all_players_are_ready = false

			break

	if all_players_are_ready:
		_state = HostState.RUNNING

#		Send timeslot for 0 tick
		_send_timeslot()


@rpc("any_peer", "call_local", "reliable")
func receive_ping():
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player: Player = PlayerManager.get_player_by_peer_id(peer_id)
	var player_id: int = player.get_id()

	_update_last_contact_time_for_player(player_id)

	_game_client.receive_pong.rpc_id(peer_id)


@rpc("any_peer", "call_local", "reliable")
func receive_ping_time_for_player(ping_time: int):
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player: Player = PlayerManager.get_player_by_peer_id(peer_id)
	var player_id: int = player.get_id()

	_player_ping_time_map[player_id] = ping_time


#########################
###      Private      ###
#########################

func _update_last_contact_time_for_player(player_id: int):
	var ticks_msec: int = Time.get_ticks_msec()
	_player_last_contact_time[player_id] = ticks_msec


func _update_state_running():
	var lagging_player_list: Array[Player] = _get_lagging_players()
	var players_are_lagging: bool = lagging_player_list.size() > 0

	if players_are_lagging:
		_state = HostState.WAITING_FOR_LAGGING_PLAYERS

		var lagging_player_name_list: Array = get_player_name_list(lagging_player_list)

		_game_client.set_lagging_players.rpc(lagging_player_name_list)

		return

	_check_desynced_players()

	var update_tick_count: int = min(Globals.get_update_ticks_per_physics_tick(), Constants.MAX_UPDATE_TICKS_PER_PHYSICS_TICK)

	for i in range(0, update_tick_count):
		var timeslot_tick: int = _last_timeslot_tick + _turn_length
		var need_to_send_timeslot: bool = _current_tick == timeslot_tick || _current_tick == 0

		if need_to_send_timeslot:
			_send_timeslot()
		
		_current_tick += 1



func _send_timeslot():
	var timeslot: Array = _in_progress_timeslot.duplicate()
	_in_progress_timeslot.clear()
	_game_client.receive_timeslot.rpc(timeslot, _current_tick)
	_last_timeslot_tick = _current_tick


# Returns highest ping of all players, in msec. Ping is
# determined from the most recent ACK exchange.
func _get_highest_ping() -> int:
	var highest_ping: int = 0

	var player_list: Array[Player] = PlayerManager.get_player_list()

	for player in player_list:
		var player_id: int = player.get_id()
		var this_ping_time: int = _player_ping_time_map[player_id]

		if this_ping_time > highest_ping:
			highest_ping = this_ping_time

	return highest_ping


# NOTE: player is considered to be lagging if the last
# timeslot ACK is too old.
func _get_lagging_players() -> Array[Player]:
	var lagging_player_list: Array[Player] = []

	var player_list: Array[Player] = PlayerManager.get_player_list()

	var ticks_msec: int = Time.get_ticks_msec()

	for player in player_list:
		var player_id: int = player.get_id()
		var last_contact_time: float = _player_last_contact_time[player_id]
		var time_since_last_contact: float = ticks_msec - last_contact_time
		var player_is_lagging: bool = time_since_last_contact > LAG_TIME_MSEC

		if player_is_lagging:
			lagging_player_list.append(player)

	return lagging_player_list


# TODO: kick desynced players from the game
func _check_desynced_players():
	var desync_detected: bool = false

	var player_list: Array[Player] = PlayerManager.get_player_list()

	var have_checksums_for_all_players: bool = true
	for player in player_list:
		var player_id: int = player.get_id()

		if !_player_checksum_map.has(player_id) || _player_checksum_map[player_id].is_empty():
			have_checksums_for_all_players = false

	if !have_checksums_for_all_players:
		return

	var authority_player: Player = PlayerManager.get_player_by_peer_id(1)
	var authority_player_id: int = authority_player.get_id()

	var have_authority_checksum: bool = _player_checksum_map.has(authority_player_id) && !_player_checksum_map[authority_player_id].is_empty()

	if !have_authority_checksum:
		return

	var authority_checksum: PackedByteArray = _player_checksum_map[authority_player_id].front()

	for player in player_list:
		var player_id: int = player.get_id()
		var checksum: PackedByteArray = _player_checksum_map[player_id].pop_front()
		var checksum_match: bool = checksum == authority_checksum

		if !checksum_match:
			desync_detected = true

	if desync_detected && !_showed_desync_message:
		var game_time: float = Utils.get_time()
		var game_time_string: String = Utils.convert_time_to_string(game_time)
		var message: String = "Desync detected @ %s" % game_time_string
		_hud.show_desync_message(message)
		_showed_desync_message = true


func get_player_name_list(player_list: Array[Player]) -> Array[String]:
	var result: Array[String] = []

	for player in player_list:
		var player_name: String = player.get_player_name()
		result.append(player_name)

	return result


#########################
###     Callbacks     ###
#########################

func _on_players_created():
	var player_list: Array[Player] = PlayerManager.get_player_list()

	for player in player_list:
		var player_id: int = player.get_id()

		_player_checksum_map[player_id] = []
		_player_ping_time_map[player_id] = 0
		_player_last_contact_time[player_id] = 0


# While waiting for lagging players, periodically send a
# message to check if lagging players respond. If there's a
# response, host will stop considering those players to be
# lagging.
# 
# Also in this timeout, tell clients about which players are
# lagging.
func _on_alive_check_timer_timeout():
	if _state != HostState.WAITING_FOR_LAGGING_PLAYERS:
		return

	var lagging_players: Array[Player] = _get_lagging_players()
	var players_are_lagging: bool = lagging_players.size() > 0

	if players_are_lagging:
		for player in lagging_players:
			var peer_id: int = player.get_peer_id()

			_game_client.receive_alive_check.rpc_id(peer_id)
	else:
		_state = HostState.RUNNING

	var lagging_player_name_list: Array[String] = get_player_name_list(lagging_players)
	_game_client.set_lagging_players.rpc(lagging_player_name_list)
