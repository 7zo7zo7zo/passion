extends RigidBody3D

@export var hp = 200

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$"Label3D".text = "HP: " + str(hp)

func take_damage(amount: float):
	hp -= amount
	if hp <= 0:
		queue_free()
