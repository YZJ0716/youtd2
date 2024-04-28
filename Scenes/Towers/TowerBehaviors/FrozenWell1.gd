extends TowerBehavior


var aura_bt: BuffType
var mist_bt: BuffType


func get_ability_description() -> String:
	var text: String = ""

	text += "[color=GOLD]Freezing Mist[/color]\n"
	text += "When this tower damages a creep it will be slowed by 15% for 10 seconds.\n"
	text += " \n"
	text += "[color=ORANGE]Level Bonus:[/color]\n"
	text += "+0.4% slow\n"
	text += " \n"
	text += "[color=GOLD]Flowing Frost - Aura[/color]\n"
	text += "Increases the buff duration of towers in 500 range by 25%.\n"
	text += " \n"
	text += "[color=ORANGE]Level Bonus:[/color]\n"
	text += "+0.4% buff duration\n"

	return text


func get_ability_description_short() -> String:
	var text: String = ""

	text += "[color=GOLD]Freezing Mist[/color]\n"
	text += "When this tower damages a creep it will be slowed.\n"
	text += " \n"
	text += "[color=GOLD]Flowing Frost - Aura[/color]\n"
	text += "Increases buff duration of towers in range.\n"

	return text


func load_triggers(triggers: BuffType):
	triggers.add_event_on_damage(on_damage)


func load_specials(_modifier: Modifier):
	tower.set_attack_style_splash({
		150: 1.0,
		625: 0.2
		})


func tower_init():
	aura_bt = BuffType.create_aura_effect_type("aura_bt", true, self)
	var boekie_frozen_well_aura_mod: Modifier = Modifier.new()
	boekie_frozen_well_aura_mod.add_modification(Modification.Type.MOD_BUFF_DURATION, 0.25, 0.004)
	aura_bt.set_buff_modifier(boekie_frozen_well_aura_mod)
	aura_bt.set_buff_icon("res://Resources/Textures/Buffs/orb_sparkly.tres")
	aura_bt.set_buff_tooltip("Flowing Frost Aura\nIncreases buff duration.")

	mist_bt = BuffType.new("mist_bt", 10, 0, false, self)
	var boekie_freezing_mist_mod: Modifier = Modifier.new()
	boekie_freezing_mist_mod.add_modification(Modification.Type.MOD_MOVESPEED, -0.15, -0.004)
	mist_bt.set_buff_modifier(boekie_freezing_mist_mod)
	mist_bt.set_buff_icon("res://Resources/Textures/Buffs/crystal.tres")
	mist_bt.set_buff_tooltip("Freezing Mist\nReduces movement speed.")


func get_aura_types() -> Array[AuraType]:
	var aura: AuraType = AuraType.new()
	aura.aura_range = 500
	aura.target_type = TargetType.new(TargetType.TOWERS)
	aura.target_self = true
	aura.level = 0
	aura.level_add = 1
	aura.power = 0
	aura.power_add = 1
	aura.aura_effect = aura_bt
	return [aura]


func on_damage(event: Event):
	mist_bt.apply(tower, event.get_target(), tower.get_level())
