extends TowerBehavior


var slow_bt: BuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {slow_value = 0.075, slow_duration = 2.0, aoe_range = 250, aoe_damage = 150, aoe_damage_add = 7.5},
		2: {slow_value = 0.090, slow_duration = 3.0, aoe_range = 300, aoe_damage = 500, aoe_damage_add = 25},
		3: {slow_value = 0.011, slow_duration = 4.0, aoe_range = 350, aoe_damage = 1250, aoe_damage_add = 62.5},
		4: {slow_value = 0.014, slow_duration = 5.0, aoe_range = 400, aoe_damage = 2500, aoe_damage_add = 125},
	}


const NOVA_CHANCE: float = 0.20
const NOVA_CHANCE_ADD: float = 0.004
const EXTRA_CRIT_CHANCE: float = 0.30


func get_ability_info_list() -> Array[AbilityInfo]:
	var nova_chance: String = Utils.format_percent(NOVA_CHANCE, 2)
	var nova_chance_add: String = Utils.format_percent(NOVA_CHANCE_ADD, 2)
	var aoe_damage: String = Utils.format_float(_stats.aoe_damage, 2)
	var aoe_range: String = Utils.format_float(_stats.aoe_range, 2)
	var slow_value: String = Utils.format_percent(_stats.slow_value, 2)
	var slow_duration: String = Utils.format_float(_stats.slow_duration, 2)
	var aoe_damage_add: String = Utils.format_float(_stats.aoe_damage_add, 2)
	var extra_crit_chance: String = Utils.format_percent(EXTRA_CRIT_CHANCE, 2)

	var list: Array[AbilityInfo] = []
	
	var ability: AbilityInfo = AbilityInfo.new()
	ability.name = "Ice Nova"
	ability.icon = "res://resources/icons/elements/ice.tres"
	ability.description_short = "Chance to blast hit creeps target with an [color=GOLD]Ice Nova[/color], dealing AoE spell damage and slowing all affected creeps.\n"
	ability.description_full = "%s chance to blast hit creeps with an [color=GOLD]Ice Nova[/color], dealing %s spell damage in %s range and slowing all affected creeps by %s for %s seconds. Has a %s bonus chance to crit.\n" % [nova_chance, aoe_damage, aoe_range, slow_value, slow_duration, extra_crit_chance] \
	+ " \n" \
	+ "[color=ORANGE]Level Bonus:[/color]\n" \
	+ "+%s chance\n" % [nova_chance_add] \
	+ "+%s spell damage\n" % [aoe_damage_add]
	list.append(ability)

	return list


func load_triggers(triggers: BuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	var m: Modifier = Modifier.new()

	slow_bt = BuffType.new("slow_bt", _stats.slow_duration, 0.0, false, self)
	m.add_modification(Modification.Type.MOD_MOVESPEED, -_stats.slow_value, 0.0)
	slow_bt.set_buff_modifier(m)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_tooltip("Ice Nova\nReduces movement speed.")


func on_damage(event: Event):
	var level: int = tower.get_level()
	var nova_chance: float = NOVA_CHANCE + NOVA_CHANCE_ADD * level

	if !tower.calc_chance(nova_chance):
		return

	var target: Unit = event.get_target()
	var it: Iterate = Iterate.over_units_in_range_of_unit(tower, TargetType.new(TargetType.CREEPS), target, _stats.aoe_range)
	var next: Unit

	CombatLog.log_ability(tower, target, "Ice Nova")

	while true:
		next = it.next()

		if next == null:
			break

		slow_bt.apply(tower, next, level)

	var damage: float = _stats.aoe_damage + _stats.aoe_damage_add * tower.get_level()
	tower.do_spell_damage_aoe_unit(target, _stats.aoe_range, damage, tower.calc_spell_crit(EXTRA_CRIT_CHANCE, 0.0), 0)
	SFX.sfx_at_unit("FrostNovaTarget.mdl", target)
