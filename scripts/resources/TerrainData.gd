## Fire Emblem Terrain Data Resource
## 
## Stores gameplay properties for a terrain type, including movement costs,
## defensive bonuses, and special effects like healing.
@tool
class_name TerrainData
extends Resource

## Unique terrain type ID
@export var id: int = 0

## Human-readable terrain name
@export var name: String = ""

## Avoid bonus provided by this terrain (percentage)
@export var avoid_bonus: int = 0

## Defense bonus provided by this terrain
@export var defense_bonus: int = 0

## Resistance bonus provided by this terrain
@export var resistance_bonus: int = 0

## Movement costs [faction][unit_type]
## faction: 0=Player, 1=Enemy, 2=NPC
## unit_type varies by faction but typically: 0=Infantry, 1=Cavalry, 2=Flying, etc.
@export var movement_costs: Array[Array] = []

## Amount of HP healed per turn (0 = no healing)
@export var healing_amount: int = 0

## Number of turns between healing (0 = every turn)
@export var healing_turns: int = 0

## Sound group for terrain effects
@export var sound_group: int = 0

## Whether terrain stats are visible to player
@export var stats_visible: bool = true

## Whether projectiles can pass through this terrain
@export var fire_through: bool = true

## Gets movement cost for a specific unit
func get_movement_cost(faction: int, unit_type: int) -> int:
	if faction < 0 or faction >= movement_costs.size():
		return -1  # Impassable
		
	var faction_costs = movement_costs[faction]
	if unit_type < 0 or unit_type >= faction_costs.size():
		return -1  # Impassable
		
	return faction_costs[unit_type]

## Checks if terrain is passable for a unit
func is_passable(faction: int, unit_type: int) -> bool:
	var cost = get_movement_cost(faction, unit_type)
	return cost > 0

## Gets display string for terrain stats
func get_stats_string() -> String:
	var parts: Array[String] = []
	
	if avoid_bonus != 0:
		parts.append("Avoid: %+d" % avoid_bonus)
	if defense_bonus != 0:
		parts.append("Def: %+d" % defense_bonus)
	if resistance_bonus != 0:
		parts.append("Res: %+d" % resistance_bonus)
	if healing_amount > 0:
		parts.append("Heal: %d" % healing_amount)
		
	return " ".join(parts) if parts.size() > 0 else "No bonuses"

func _validate_property(property: Dictionary):
	# Make ID read-only after it's set
	if property.name == "id" and id > 0:
		property.usage = PROPERTY_USAGE_READ_ONLY
