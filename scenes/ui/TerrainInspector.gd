## Terrain Inspector
##
## Displays detailed information about terrain properties at the selected tile position.
extends Control

# UI References
@onready var terrain_name_label: Label = $VBoxContainer/TerrainNameLabel
@onready var position_label: Label = $VBoxContainer/PositionLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var movement_costs_grid: GridContainer = $VBoxContainer/MovementCostsContainer/MovementCostsGrid
@onready var special_properties_label: Label = $VBoxContainer/SpecialPropertiesLabel

# Current state
var current_position: Vector2i = Vector2i(-1, -1)
var current_map: FEMap
var current_terrain: TerrainData

# Unit type names for display
var unit_type_names = {
	0: ["Infantry", "Cavalry", "Flying", "Armor", "Archer"],
	1: ["Infantry", "Cavalry", "Flying", "Armor", "Archer"], 
	2: ["Infantry", "Cavalry", "Flying", "Armor", "Archer"]
}

var faction_names = ["Player", "Enemy", "NPC"]

func _ready():
	# Connect to EventBus
	EventBus.map_loaded.connect(_on_map_loaded)
	EventBus.tile_selected.connect(_on_tile_selected)
	
	# Clear display initially
	_clear_display()

## Update display for a specific tile position
func display_terrain_info(tile_pos: Vector2i, map: FEMap):
	current_position = tile_pos
	current_map = map
	
	if not _is_valid_position(tile_pos, map):
		_clear_display()
		return
	
	# Get tile and terrain information
	var tile_index = map.get_tile_at(tile_pos.x, tile_pos.y)
	var tileset_data = AssetManager.get_tileset_data(map.tileset_id)
	
	if not tileset_data:
		_show_error("No tileset data available")
		return
	
	var terrain_id = tileset_data.get_terrain_type(tile_index)
	current_terrain = AssetManager.get_terrain_data(terrain_id)
	
	if not current_terrain:
		_show_error("No terrain data for type: " + str(terrain_id))
		return
	
	# Update all display elements
	_update_position_info(tile_pos, tile_index)
	_update_terrain_info()
	_update_stats_display()
	_update_movement_costs()
	_update_special_properties()

## Clear all display elements
func _clear_display():
	terrain_name_label.text = "No terrain selected"
	position_label.text = ""
	_clear_stats_container()
	_clear_movement_costs()
	special_properties_label.text = ""

## Show error message
func _show_error(message: String):
	terrain_name_label.text = "Error: " + message
	position_label.text = ""
	_clear_stats_container()
	_clear_movement_costs()
	special_properties_label.text = ""

## Update position and tile information
func _update_position_info(tile_pos: Vector2i, tile_index: int):
	position_label.text = "Position: (%d, %d) | Tile: %d" % [tile_pos.x, tile_pos.y, tile_index]

## Update terrain name and basic info
func _update_terrain_info():
	if current_terrain:
		terrain_name_label.text = current_terrain.name
	else:
		terrain_name_label.text = "Unknown Terrain"

## Update terrain stats display
func _update_stats_display():
	_clear_stats_container()
	
	if not current_terrain:
		return
	
	# Create stat labels
	_add_stat_label("Avoid Bonus", str(current_terrain.avoid_bonus), current_terrain.avoid_bonus != 0)
	_add_stat_label("Defense Bonus", str(current_terrain.defense_bonus), current_terrain.defense_bonus != 0)
	_add_stat_label("Resistance Bonus", str(current_terrain.resistance_bonus), current_terrain.resistance_bonus != 0)
	
	if current_terrain.healing_amount > 0:
		var heal_text = str(current_terrain.healing_amount)
		if current_terrain.healing_turns > 0:
			heal_text += " (every " + str(current_terrain.healing_turns) + " turns)"
		_add_stat_label("Healing", heal_text, true)

## Add a stat label to the stats container
func _add_stat_label(name: String, value: String, highlight: bool = false):
	var hbox = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = name + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	if highlight:
		value_label.modulate = Color.YELLOW
	
	hbox.add_child(value_label)
	stats_container.add_child(hbox)

## Clear stats container
func _clear_stats_container():
	for child in stats_container.get_children():
		child.queue_free()

## Update movement costs display
func _update_movement_costs():
	_clear_movement_costs()
	
	if not current_terrain or current_terrain.movement_costs.is_empty():
		var no_data_label = Label.new()
		no_data_label.text = "No movement data"
		movement_costs_grid.add_child(no_data_label)
		return
	
	# Set up grid columns (Unit types + 1 for faction name)
	var max_unit_types = 0
	for faction_costs in current_terrain.movement_costs:
		max_unit_types = max(max_unit_types, faction_costs.size())
	
	movement_costs_grid.columns = max_unit_types + 1
	
	# Header row - faction names and unit types
	var header_label = Label.new()
	header_label.text = "Faction"
	header_label.add_theme_font_size_override("font_size", 10)
	movement_costs_grid.add_child(header_label)
	
	for i in range(max_unit_types):
		var unit_label = Label.new()
		unit_label.text = _get_unit_type_name(0, i)  # Use player unit names
		unit_label.add_theme_font_size_override("font_size", 10)
		unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		movement_costs_grid.add_child(unit_label)
	
	# Add faction rows
	for faction_id in range(current_terrain.movement_costs.size()):
		var faction_costs = current_terrain.movement_costs[faction_id]
		
		# Faction name
		var faction_label = Label.new()
		faction_label.text = _get_faction_name(faction_id)
		faction_label.add_theme_font_size_override("font_size", 10)
		movement_costs_grid.add_child(faction_label)
		
		# Movement costs
		for unit_id in range(max_unit_types):
			var cost_label = Label.new()
			
			if unit_id < faction_costs.size():
				var cost = faction_costs[unit_id]
				if cost == 0:
					cost_label.text = "X"
					cost_label.modulate = Color.RED
				elif cost < 0:
					cost_label.text = "∞"
					cost_label.modulate = Color.RED
				else:
					cost_label.text = str(cost)
					if cost > 3:
						cost_label.modulate = Color.ORANGE
			else:
				cost_label.text = "-"
				cost_label.modulate = Color.GRAY
			
			cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost_label.add_theme_font_size_override("font_size", 10)
			movement_costs_grid.add_child(cost_label)

## Clear movement costs grid
func _clear_movement_costs():
	for child in movement_costs_grid.get_children():
		child.queue_free()

## Update special properties display
func _update_special_properties():
	if not current_terrain:
		special_properties_label.text = ""
		return
	
	var properties: Array[String] = []
	
	if not current_terrain.stats_visible:
		properties.append("Hidden stats")
	
	if not current_terrain.fire_through:
		properties.append("Blocks projectiles")
	
	if current_terrain.sound_group != 0:
		properties.append("Sound group: " + str(current_terrain.sound_group))
	
	if properties.is_empty():
		special_properties_label.text = "No special properties"
	else:
		special_properties_label.text = "Special: " + ", ".join(properties)

## Get faction name for display
func _get_faction_name(faction_id: int) -> String:
	if faction_id < faction_names.size():
		return faction_names[faction_id]
	return "Faction " + str(faction_id)

## Get unit type name for display
func _get_unit_type_name(faction_id: int, unit_type_id: int) -> String:
	if faction_id in unit_type_names:
		var unit_names = unit_type_names[faction_id]
		if unit_type_id < unit_names.size():
			return unit_names[unit_type_id]
	
	return "Unit " + str(unit_type_id)

## Check if position is valid
func _is_valid_position(pos: Vector2i, map: FEMap) -> bool:
	if not map:
		return false
	return pos.x >= 0 and pos.x < map.width and pos.y >= 0 and pos.y < map.height

## Get movement cost for specific unit type
func get_movement_cost(faction: int, unit_type: int) -> int:
	if not current_terrain:
		return -1
	return current_terrain.get_movement_cost(faction, unit_type)

## Get terrain bonuses as dictionary
func get_terrain_bonuses() -> Dictionary:
	if not current_terrain:
		return {}
	
	return {
		"avoid": current_terrain.avoid_bonus,
		"defense": current_terrain.defense_bonus,
		"resistance": current_terrain.resistance_bonus,
		"healing": current_terrain.healing_amount
	}

## Check if terrain has specific property
func has_property(property: String) -> bool:
	if not current_terrain:
		return false
	
	match property:
		"healing":
			return current_terrain.healing_amount > 0
		"defensive":
			return current_terrain.defense_bonus > 0
		"evasive":
			return current_terrain.avoid_bonus > 0
		"magic_resistant":
			return current_terrain.resistance_bonus > 0
		"hidden_stats":
			return not current_terrain.stats_visible
		"blocks_projectiles":
			return not current_terrain.fire_through
		_:
			return false

# Event handlers
func _on_map_loaded(map: FEMap):
	current_map = map
	_clear_display()

func _on_tile_selected(tile_index: int):
	# Convert tile index to position if we have a current map
	if current_map:
		# This is a simplified approach - in reality we'd need the actual position
		# For now, we'll wait for the MapCanvas to call display_terrain_info directly
		pass

## Get current terrain data
func get_current_terrain() -> TerrainData:
	return current_terrain

## Get current position
func get_current_position() -> Vector2i:
	return current_position
