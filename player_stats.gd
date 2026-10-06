extends Node
var money : float = 500
var reputation_species : Dictionary = {
	"Slime" : 0,
	"Human" : 0,
	"Vampire" : 0,
	"Fish" : 0,
	"Tiny" : 0,
}

var upgrades : Dictionary = {
	
}

var unlocks : Dictionary = {
	"Drinks" :{
		"Gin" : true,
		"Rum" : true,
		"Vodka" : true,
		"Spirit" : true
	}
}

func _change_money(new_value: float) -> void:
	GameState.gameplay_ui._change_money(new_value)
