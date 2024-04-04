extends TowerBehavior


var roots_bt: BuffType
var stun_bt: BuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {stun_chance = 0.05, slow_chance = 0.10, slow_duration = 7.5},
		2: {stun_chance = 0.06, slow_chance = 0.15, slow_duration = 8.5},
		3: {stun_chance = 0.07, slow_chance = 0.20, slow_duration = 9.5},
	}


const STUN_CHANCE_ADD: float = 0.001
const STUN_DURATION: float = 1.75
const STUN_DURATION_ADD: float = 0.05
const SLOW_AMOUNT: float = 0.15
const SLOW_CHANCE_ADD: float = 0.001
const SLOW_DURATION_ADD: float = 0.2


func get_ability_description() -> String:
	var stun_chance: String = Utils.format_percent(_stats.stun_chance, 2)
	var stun_chance_add: String = Utils.format_percent(STUN_CHANCE_ADD, 2)
	var stun_duration: String = Utils.format_float(STUN_DURATION, 2)
	var stun_duration_add: String = Utils.format_float(STUN_DURATION_ADD, 2)
	var slow_chance: String = Utils.format_percent(_stats.slow_chance, 2)
	var slow_chance_add: String = Utils.format_percent(SLOW_CHANCE_ADD, 2)
	var slow_amount: String = Utils.format_percent(SLOW_AMOUNT, 2)
	var slow_duration: String = Utils.format_float(_stats.slow_duration, 2)
	var slow_duration_add: String = Utils.format_float(SLOW_DURATION_ADD, 2)

	var text: String = ""

	text += "[color=GOLD]Advanced Multishot[/color]\n"
	text += "Multishot count increases by 1 at level 15.\n"
	text += " \n"
	
	text += "[color=GOLD]Gift of the Forest[/color]\n"
	text += "The magical powers of the forest grant this archer enchanted arrows. These arrows have a %s chance to stun for %s seconds. If they don't stun there is a %s chance to slow by %s for %s seconds.\n" % [stun_chance, stun_duration, slow_chance, slow_amount, slow_duration]
	text += " \n"
	text += "[color=ORANGE]Level Bonus:[/color]\n"
	text += "+%s chance to stun\n" % stun_chance_add
	text += "+%s seconds stun duration\n" % stun_duration_add
	text += "+%s chance to slow\n" % slow_chance_add
	text += "+%s seconds slow duration\n" % slow_duration_add

	return text


func get_ability_description_short() -> String:
	var text: String = ""

	text += "[color=GOLD]Advanced Multishot[/color]\n"
	text += "Multishot count increases by 1 at level 15.\n"
	text += " \n"

	text += "[color=GOLD]Gift of the Forest[/color]\n"
	text += "The magical powers of the forest grant this archer enchanted arrows.\n"

	return text


func load_triggers(triggers: BuffType):
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_level_up(on_level_up)


func load_specials(_modifier: Modifier):
	tower.set_target_count(3)


func tower_init():
	var mod: Modifier = Modifier.new()
	mod.add_modification(Modification.Type.MOD_MOVESPEED, -SLOW_AMOUNT, 0.0)
	roots_bt = BuffType.new("roots_bt", 0, 0, false, self)
	roots_bt.set_buff_icon("foot.tres")
	roots_bt.set_buff_modifier(mod)
	roots_bt.set_stacking_group("ForestArcherStacks")
	roots_bt.set_buff_tooltip("Forest Roots\nReduces movement speed.")

	stun_bt = CbStun.new("stun_bt", 0, 0, false, self)


func on_damage(event: Event):
	var level: int = tower.get_level()
	var creep: Unit = event.get_target()
	var slow_duration: float = _stats.slow_duration + SLOW_DURATION_ADD * level
	var slow_level: int = int(slow_duration * 1000)

	if tower.calc_chance(_stats.stun_chance + STUN_CHANCE_ADD * level):
		CombatLog.log_ability(tower, creep, "Gift of the Forest Stun")

		stun_bt.apply_only_timed(tower, creep, STUN_DURATION + STUN_DURATION_ADD * level)
	elif tower.calc_chance(_stats.slow_chance + SLOW_CHANCE_ADD * level):
		CombatLog.log_ability(tower, creep, "Gift of the Forest Slow")

		roots_bt.apply_custom_timed(tower, creep, slow_level, slow_duration)


func on_level_up(_event: Event):
	if tower.get_level() == 15:
		tower.set_target_count(4)


func on_create(_preceding: Tower):
	if tower.get_level() >= 15:
		tower.set_target_count(4)
