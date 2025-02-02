extends Node3D


@onready var debris = $Debris
@onready var fire = $Fire
@onready var smoke = $Smoke


# Trait based explosions would be dope 
# should eventually hold all info for all kinds of different explosions

func explode():
	debris.emitting = true
	fire.emitting = true
	smoke.emitting = true
	await get_tree().create_timer(2.0).timeout
	queue_free()
