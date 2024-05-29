class_name HUD extends Control


signal start_wave(wave_index)
signal stop_wave()


@export var _error_message_container: VBoxContainer
@export var _normal_message_container: VBoxContainer
@export var _game_over_label: RichTextLabel
@export var _elements_menu: ElementsMenu
@export var _tower_stash_menu: TowerStashMenu
@export var _item_stash_menu: ItemStashMenu
@export var _tower_stash_button: MenuExpandingButton
@export var _item_stash_button: MenuExpandingButton
@export var _top_left_menu: TopLeftMenu
@export var _unit_menu: UnitMenu
@export var _host_player_label: Label
@export var _second_player_label: Label
@export var _chat_line_edit: LineEdit
@export var _desync_label: Label
@export var _button_tooltip_top: ButtonTooltip
@export var _button_tooltip_bottom: ButtonTooltip
@export var _tower_details: TowerDetails
@export var _creep_details: CreepDetails

# NOTE: this list is ordered by priority of closure. If
# multiple windows are open, then the first window in the
# list will be closed, others will stay.
@onready var _window_list: Array = [_tower_details, _creep_details, _elements_menu, _tower_stash_menu, _item_stash_menu]


#########################
###     Built-in      ###
#########################

func _ready():
	if OS.is_debug_build() and Config.dev_controls_enabled():
		$DevControls.call_deferred("create_instance")
	
	SFX.connect_sfx_to_signal_in_group("res://assets/sfx/menu_sound_5.wav", "pressed", "sfx_menu_click")

	EventBus.local_player_rolled_towers.connect(_on_local_player_rolled_towers)
	EventBus.item_started_flying_to_item_stash.connect(_on_item_started_flying_to_item_stash)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	ButtonTooltip.setup_tooltip_instances(_button_tooltip_top, _button_tooltip_bottom)


#########################
###       Public      ###
#########################

func show_desync_message(message: String):
	_desync_label.show()
	_desync_label.text = message


func start_editing_chat():
	_chat_line_edit.show()
	_chat_line_edit.grab_focus()


func finish_editing_chat():
	_chat_line_edit.clear()
	_chat_line_edit.hide()


func enter_slash_into_chat():
	_chat_line_edit.text = "/"
	_chat_line_edit.caret_column = 1


func editing_chat() -> bool:
	return _chat_line_edit.visible


func get_chat_edit_text() -> String:
	var text: String = _chat_line_edit.text

	return text


func add_chat_message(player: Player, message: String):
	var player_name: String = player.get_player_name()

	var complete_message: String = "[%s]: %s" % [player_name, message]
	
	Messages.add_normal(null, complete_message)


# Set tower or creep which should be displayed in unit menus
# NOTE: the callback for set_pressed() which make tower menu
# or creep menu visible.
func set_menu_unit(unit: Unit):
	_unit_menu.set_unit(unit)
	_unit_menu.visible = unit != null
	
	var tower: Tower = unit as Tower
	var creep: Creep = unit as Creep
	_tower_details.set_tower(tower)
	_creep_details.set_creep(creep)

	if tower == null:
		_tower_details.hide()
	if creep == null:
		_creep_details.hide()


func connect_to_local_player(local_player: Player):
	_item_stash_menu.connect_to_local_player(local_player)
	_tower_stash_menu.connect_to_local_player(local_player)
	_elements_menu.connect_to_local_player(local_player)
	_top_left_menu.connect_to_local_player(local_player)


func set_game_start_timer(timer: ManualTimer):
	_top_left_menu.set_game_start_timer(timer)


func close_one_window():
	for window in _window_list:
		if window.visible:
			window.hide()
			break


func show_game_over():
	_game_over_label.show()


#########################
###     Callbacks     ###
#########################

func _on_peer_connected(id):
	_host_player_label.text = "Player ID: %s" % multiplayer.get_unique_id()
	_second_player_label.text = "Player ID: %s" % id


func _on_peer_disconnected(_id):
	_second_player_label.text = ""


#########################
### Setters / Getters ###
#########################

func get_error_message_container() -> VBoxContainer:
	return _error_message_container


func get_normal_message_container() -> VBoxContainer:
	return _normal_message_container


func any_window_is_open() -> bool:
	for window in _window_list:
		if window.visible:
			return true
	
	return false


func _on_towers_status_card_main_button_toggled(toggled_on: bool):
	_tower_stash_menu.visible = toggled_on


func _on_items_status_card_main_button_toggled(toggled_on: bool):
	_item_stash_menu.visible = toggled_on


func _on_element_status_card_main_button_toggled(toggled_on):
	_elements_menu.visible = toggled_on


# Manually press status button for tower stash menu to
# switch to tower stash menu after rolling towers.
func _on_local_player_rolled_towers():
	_tower_stash_button.set_pressed(true)


func _on_item_started_flying_to_item_stash(item: Item, canvas_pos: Vector2):
	if !item.belongs_to_local_player():
		return

	var item_stash_button_pos: Vector2 = _item_stash_button.global_position + Vector2(45, 45)
	var item_id: int = item.get_id()

	var flying_item: FlyingItem = FlyingItem.create(item_id, canvas_pos, item_stash_button_pos)
	flying_item.visible = item.is_visible()
	add_child(flying_item)


func _on_unit_menu_details_pressed():
	var current_unit: Unit = _unit_menu.get_unit()
	
	if current_unit is Tower:
		_tower_details.visible = !_tower_details.visible
		_creep_details.visible = false
	
		_tower_details.update_text()
	elif current_unit is Creep:
		_tower_details.visible = false
		_creep_details.visible = !_creep_details.visible
	
		_creep_details.update_text()
	else:
		_tower_details.visible = false
		_creep_details.visible = false
