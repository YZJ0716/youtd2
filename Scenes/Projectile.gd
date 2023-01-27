extends KinematicBody2D


# Projectile moves towards the target and disappears when it
# reaches the target.

var target_mob: Mob = null
export var speed: int = 100
export var contact_distance: int = 30
var damage: Array


func init(target_mob_arg: Mob, tower_position: Vector2, damage_arg: Array):
	target_mob = target_mob_arg
	position = tower_position
	damage = damage_arg


func have_target() -> bool:
	return target_mob != null and is_instance_valid(target_mob)


func _process(delta):
	if !have_target():
		queue_free()
		return
	
#	Move towards mob
	var target_pos = target_mob.position
	var pos_diff = target_pos - position
	
	var reached_mob = pos_diff.length() < contact_distance

	if reached_mob:
		target_mob.apply_damage(damage)

		queue_free()
		return
	
	var move_vector = speed * pos_diff.normalized() * delta
	
	position += move_vector
