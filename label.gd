extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var weapon_manager = $".."
	if weapon_manager.current_weapon:
		text = str(weapon_manager.current_weapon.current_ammo) + " / " + str(weapon_manager.current_weapon.reserve_ammo)
