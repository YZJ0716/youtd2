extends TowerBehavior


var acid_bt: BuffType

# NOTE: values here are pre-multiplied by 1000, so 600 = 0.6
# as final value. That's how it is in original script and we
# stick to original to avoid introducting bugs.
func get_tier_stats() -> Dictionary:
	return {
		1: {armor_base = 600, armor_add = 24},
		2: {armor_base = 1200, armor_add = 48},
		3: {armor_base = 2400, armor_add = 96},
		4: {armor_base = 4800, armor_add = 192},
		5: {armor_base = 9600, armor_add = 384},
	}


func get_ability_description() -> String:
	var armor_base: String = Utils.format_float(_stats.armor_base / 1000.0, 3)
	var armor_add: String = Utils.format_float(_stats.armor_add / 1000.0, 3)

	var text: String = ""

	text += "[color=GOLD]Acid Coating[/color]\n"
	text += "Decreases the armor of damaged units by %s for 3 seconds.\n" % armor_base
	text += " \n"
	text += "[color=ORANGE]Level Bonus:[/color]\n"
	text += "+%s armor reduction\n" % armor_add
	text += "+0.12 seconds"

	return text


func get_ability_description_short() -> String:
	var text: String = ""

	text += "[color=GOLD]Acid Coating[/color]\n"
	text += "Decreases the armor of damaged units.\n"

	return text


func load_triggers(triggers_buff_type: BuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func load_specials(_modifier: Modifier):
	tower.set_attack_style_bounce(3, 0.15)


func tower_init():
	var m: Modifier = Modifier.new()
	m.add_modification(Modification.Type.MOD_ARMOR, 0.0, -0.001)
	acid_bt = BuffType.new("acid_bt", 3.0, 0.12, false, self)
	acid_bt.set_buff_icon("res://Resources/Textures/Buffs/armor_chest.tres")
	acid_bt.set_buff_modifier(m)

	acid_bt.set_buff_tooltip("Acid Corosion\nReduces armor.")


func on_damage(event: Event):
	acid_bt.apply_custom_timed(tower, event.get_target(), _stats.armor_base + tower.get_level() * _stats.armor_add, 3.0 + 0.12 * tower.get_level())
