extends Node
class_name Item

enum Item_Type{
	ROCK, METAL, OXYGEN, WATER
}

var type : Item_Type


static func type_name(t: Item_Type) -> String:
	match t:
		Item_Type.ROCK:
			return "Rock"
		Item_Type.METAL:
			return "Metal"
		Item_Type.OXYGEN:
			return "Oxygen"
		Item_Type.WATER:
			return "Water"
	return "?"
