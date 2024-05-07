extends TowerBehavior


var entangle_bt: BuffType
var aura_bt: BuffType


func get_ability_info_list() -> Array[AbilityInfo]:
	var list: Array[AbilityInfo] = []
	
	var ability: AbilityInfo = AbilityInfo.new()
	ability.name = "Gift of Nature - Aura"
	ability.description_short = "All nearby towers have a chance to entangle creeps.\n"
	ability.description_full = "All towers in 175 range will receive a gift of nature. When a gifted tower attacks a creep there is a 10% attackspeed adjusted chance to entangle that creep for 1.2 seconds, dealing 700 damage per second. Does not work on air units or bosses!\n" \
	+ " \n" \
	+ "[color=ORANGE]Level Bonus:[/color]\n" \
	+ "+0.2% chance \n" \
	+ "+35 additional damage\n"
	list.append(ability)

	return list


func tower_init():
	entangle_bt = CbStun.new("entangle_bt", 1.2, 0, false, self)
	entangle_bt.set_buff_icon("res://Resources/Icons/GenericIcons/ophiucus.tres")
	entangle_bt.add_periodic_event(entangle_bt_periodic, 1.0)
	entangle_bt.set_buff_tooltip("Entangled\nThis creep is entangled; it can't move and will take periodic damage.")

	aura_bt = BuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_icon("res://Resources/Icons/GenericIcons/holy_grail.tres")
	aura_bt.add_event_on_attack(aura_bt_on_attack)
	aura_bt.set_buff_tooltip("Gift of Nature\nChance to entangle creeps.")


func get_aura_types() -> Array[AuraType]:
	var aura: AuraType = AuraType.new()
	aura.aura_range = 175
	aura.target_type = TargetType.new(TargetType.TOWERS)
	aura.target_self = true
	aura.level = 0
	aura.level_add = 1
	aura.power = 0
	aura.power_add = 1
	aura.aura_effect = aura_bt

	return [aura]


func aura_bt_on_attack(event: Event):
	var buff: Buff = event.get_buff()
	var caster: Tower = buff.get_caster()
	var buffed_tower: Tower = buff.get_buffed_unit()
	var target: Creep = event.get_target()
	var entangle_chance: float = (0.10 + 0.002 * caster.get_level()) * buffed_tower.get_base_attackspeed()
	var target_is_boss: bool = target.get_size() >= CreepSize.enm.BOSS
	var target_is_air: bool = target.get_size() == CreepSize.enm.AIR

	if !caster.calc_chance(entangle_chance):
		return

	if target_is_boss || target_is_air:
		return

	CombatLog.log_ability(caster, target, "Sacred Altar Entangle")

	entangle_bt.apply(caster, target, caster.get_level())


func entangle_bt_periodic(event: Event):
	var buff: Buff = event.get_buff()
	var caster: Tower = buff.get_caster()
	var creep: Unit = buff.get_buffed_unit()
	var damage: float = 700 + 35 * buff.get_level()

	caster.do_spell_damage(creep, damage, caster.calc_spell_crit_no_bonus())
