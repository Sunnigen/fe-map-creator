## Asset Manager
##
## Handles loading and conversion of FEMapCreator data to Godot resources.
## Manages terrain data, tileset data, and PNG tilesets.
extends Node

# Signals
signal initialization_completed

# Data storage
var terrain_data: Dictionary = {}          # terrain_id -> TerrainData
var tileset_data: Dictionary = {}          # tileset_id -> FETilesetData
var tileset_resources: Dictionary = {}     # tileset_id -> TileSet
var tileset_textures: Dictionary = {}      # tileset_id -> Texture2D

# Constants
const TILESET_WIDTH = 32
const TILESET_HEIGHT = 32
const TILE_SIZE = 16
const TOTAL_TILES = 1024

# Paths (relative to original FEMapCreator folder)
var fe_data_path: String = ""
var initialized: bool = false

## Initialize the asset manager with FEMapCreator data path
func initialize(data_path: String):
	fe_data_path = data_path
	print("Initializing AssetManager with path: ", data_path)
	
	# Load data in order
	load_terrain_data()
	load_tileset_data()
	load_tileset_textures()
	
	initialized = true
	print("AssetManager initialized successfully")
	print("- Loaded %d terrain types" % terrain_data.size())
	print("- Loaded %d tilesets" % tileset_data.size())
	print("- Loaded %d textures" % tileset_textures.size())
	
	# Emit signal to notify other systems that initialization is complete
	initialization_completed.emit()

## Load and parse Terrain_Data.xml
func load_terrain_data():
	var xml_path = fe_data_path + "/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		push_error("Could not open terrain data: " + xml_path)
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("Parsing terrain data...")
	parse_terrain_xml(xml_content)

## Load and parse Tileset_Data.xml
func load_tileset_data():
	var xml_path = fe_data_path + "/Tileset_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		push_error("Could not open tileset data: " + xml_path)
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("Parsing tileset data...")
	parse_tileset_xml(xml_content)

## Load tileset PNG files and create Godot TileSet resources
func load_tileset_textures():
	#var tilesets_path = fe_data_path + "/Tilesets/"
	var tilesets_path = "res://assets/tilesets/"
	var dir = DirAccess.open(tilesets_path)
	if not dir:
		push_error("Could not open tilesets directory: " + tilesets_path)
		return
	
	print("Loading tileset textures...")
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".png"):
			var texture = load(tilesets_path + file_name) as Texture2D
			if texture:
				var tileset_id = extract_tileset_id_from_filename(file_name)
				tileset_textures[tileset_id] = texture
				
				# Create TileSet resource
				create_tileset_resource(tileset_id, texture)
				
				print("- Loaded tileset: ", tileset_id, " (", file_name, ")")
		file_name = dir.get_next()

## Parse terrain XML data using simple string parsing
func parse_terrain_xml(xml_content: String):
	# Split content into entries
	var entries = xml_content.split("<KeyValuePairOfInt32TerrainTerrainData>")
	
	for entry in entries:
		if entry.strip_edges().is_empty():
			continue
			
		var terrain = TerrainData.new()
		
		# Extract key (terrain ID)
		var key_match = _extract_xml_value(entry, "Key")
		if key_match.is_empty():
			continue
		var terrain_id = key_match.to_int()
		
		# Extract terrain properties
		terrain.id = _extract_xml_value(entry, "Id").to_int()
		terrain.name = _extract_xml_value(entry, "n")
		terrain.avoid_bonus = _extract_xml_value(entry, "Avoid").to_int()
		terrain.defense_bonus = _extract_xml_value(entry, "Def").to_int()
		terrain.resistance_bonus = _extract_xml_value(entry, "Res").to_int()
		terrain.healing_amount = _extract_xml_value(entry, "HP").to_int()
		terrain.healing_turns = _extract_xml_value(entry, "HP_Turns").to_int() 
		terrain.sound_group = _extract_xml_value(entry, "Sound_Group").to_int()
		terrain.stats_visible = _extract_xml_value(entry, "Stats_Visible") == "true"
		terrain.fire_through = _extract_xml_value(entry, "Fire_Through") == "true"
		
		# Parse movement costs (more complex)
		parse_movement_costs(entry, terrain)
		
		terrain_data[terrain_id] = terrain

## Parse movement cost data from terrain XML entry
func parse_movement_costs(entry: String, terrain: TerrainData):
	terrain.movement_costs = []
	
	# Look for ArrayOfArrayOfByte sections
	var array_sections = entry.split("<ArrayOfArrayOfByte>")
	for i in range(1, array_sections.size()):  # Skip first split
		var section = array_sections[i]
		if not section.contains("</ArrayOfArrayOfByte>"):
			continue
			
		section = section.split("</ArrayOfArrayOfByte>")[0]
		
		# Parse individual byte arrays (unit types for this faction)
		var unit_costs: Array[int] = []
		var byte_arrays = section.split("<ArrayOfByte>")
		
		for j in range(1, byte_arrays.size()):
			var byte_section = byte_arrays[j]
			if not byte_section.contains("</ArrayOfByte>"):
				continue
				
			byte_section = byte_section.split("</ArrayOfByte>")[0]
			
			# Extract individual bytes
			var items = byte_section.split("<byte>")
			for k in range(1, items.size()):
				var item = items[k]
				if item.contains("</byte>"):
					var cost = item.split("</byte>")[0].strip_edges().to_int()
					unit_costs.append(cost)
		
		if unit_costs.size() > 0:
			terrain.movement_costs.append(unit_costs)

## Parse tileset XML data
func parse_tileset_xml(xml_content: String):
	var entries = xml_content.split("<KeyValuePairOfInt32TileSetData>")
	
	for entry in entries:
		if entry.strip_edges().is_empty():
			continue
			
		var tileset_data_obj = FETilesetData.new()
		
		# Extract key (tileset internal ID)
		var key_match = _extract_xml_value(entry, "Key")
		if key_match.is_empty():
			continue
		var tileset_key = key_match.to_int()
		
		# Extract tileset properties
		tileset_data_obj.id = _extract_xml_value(entry, "Id")
		tileset_data_obj.name = _extract_xml_value(entry, "Name")
		tileset_data_obj.graphic_name = _extract_xml_value(entry, "Graphic_Name")
		
		# Parse terrain tags
		var terrain_tags_str = _extract_xml_value(entry, "Terrain_Tags")
		tileset_data_obj.set_terrain_tags_from_string(terrain_tags_str)
		
		# Parse animation data
		var anim_data_str = _extract_xml_value(entry, "Animated_Tile_Data")
		var anim_names = _extract_xml_array(entry, "Animated_Tile_Names", "Item")
		
		if not anim_data_str.is_empty():
			tileset_data_obj.parse_animation_data(anim_data_str, anim_names)
		
		# Store using hex ID if we can find it in the texture files
		var hex_id = find_hex_id_for_tileset(tileset_data_obj.graphic_name)
		if not hex_id.is_empty():
			tileset_data_obj.id = hex_id
			tileset_data[hex_id] = tileset_data_obj
		else:
			# Fallback to internal ID
			tileset_data[str(tileset_key)] = tileset_data_obj

## Create a Godot TileSet resource from texture and data
func create_tileset_resource(tileset_id: String, texture: Texture2D):
	var tileset = TileSet.new()
	
	# Create TileSetAtlasSource
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = texture
	
	# Set up terrain set
	tileset.add_terrain_set()
	
	# Add custom data layer for terrain type
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "terrain_type")
	tileset.set_custom_data_layer_type(0, TYPE_INT)
	
	# Add the source to the tileset BEFORE creating tiles (required in Godot 4)
	tileset.add_source(atlas_source, 0)
	
	# Get tileset data for terrain mapping
	var tileset_data_obj = tileset_data.get(tileset_id, null)
	
	# Set up all tiles in the 32x32 grid
	for y in range(TILESET_HEIGHT):
		for x in range(TILESET_WIDTH):
			var atlas_coords = Vector2i(x, y)
			atlas_source.create_tile(atlas_coords)
			
			# Get terrain type for this tile
			var tile_index = y * TILESET_WIDTH + x
			var terrain_type = 0
			
			if tileset_data_obj and tile_index < tileset_data_obj.terrain_tags.size():
				terrain_type = tileset_data_obj.terrain_tags[tile_index]
			
			# Set up tile data
			var tile_data = atlas_source.get_tile_data(atlas_coords, 0)
			
			# Store terrain type in custom data (use layer name)
			tile_data.set_custom_data("terrain_type", terrain_type)
			
			# Set terrain for pathfinding if we have terrain data
			if terrain_type in terrain_data:
				var terrain = terrain_data[terrain_type]
				# We could set up terrain here if needed
	
	tileset_resources[tileset_id] = tileset
	
	# Update the tileset data object
	if tileset_data_obj:
		tileset_data_obj.tileset_resource = tileset
		tileset_data_obj.texture = texture

## Extract value from XML tags
func _extract_xml_value(xml_text: String, tag: String) -> String:
	var start_tag = "<" + tag + ">"
	var end_tag = "</" + tag + ">"
	
	var start_index = xml_text.find(start_tag)
	if start_index == -1:
		return ""
	
	start_index += start_tag.length()
	var end_index = xml_text.find(end_tag, start_index)
	if end_index == -1:
		return ""
	
	return xml_text.substr(start_index, end_index - start_index).strip_edges()

## Extract array from XML
func _extract_xml_array(xml_text: String, array_tag: String, item_tag: String) -> Array[String]:
	var result: Array[String] = []
	var start_tag = "<" + array_tag + ">"
	var end_tag = "</" + array_tag + ">"
	
	var start_index = xml_text.find(start_tag)
	if start_index == -1:
		return result
	
	var end_index = xml_text.find(end_tag, start_index)
	if end_index == -1:
		return result
	
	var array_content = xml_text.substr(start_index, end_index - start_index + end_tag.length())
	
	var item_start_tag = "<" + item_tag + ">"
	var item_end_tag = "</" + item_tag + ">"
	
	var pos = 0
	while true:
		var item_start = array_content.find(item_start_tag, pos)
		if item_start == -1:
			break
			
		item_start += item_start_tag.length()
		var item_end = array_content.find(item_end_tag, item_start)
		if item_end == -1:
			break
			
		var item_value = array_content.substr(item_start, item_end - item_start).strip_edges()
		result.append(item_value)
		
		pos = item_end + item_end_tag.length()
	
	return result

## Extract tileset ID from PNG filename
func extract_tileset_id_from_filename(filename: String) -> String:
	# Extract hex ID from filename like "FE7 - Plains - 01000703.png"
	var parts = filename.split(" - ")
	if parts.size() >= 3:
		var hex_part = parts[-1].replace(".png", "")
		return hex_part
	return ""

## Find hex ID for a tileset by graphic name
func find_hex_id_for_tileset(graphic_name: String) -> String:
	var tilesets_path = fe_data_path + "/Tilesets/"
	var dir = DirAccess.open(tilesets_path)
	if not dir:
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".png") and file_name.contains(graphic_name):
			return extract_tileset_id_from_filename(file_name)
		file_name = dir.get_next()
	
	return ""

## Get terrain data by ID
func get_terrain_data(terrain_id: int) -> TerrainData:
	return terrain_data.get(terrain_id, null)

## Get tileset data by ID
func get_tileset_data(tileset_id: String) -> FETilesetData:
	return tileset_data.get(tileset_id, null)

## Get tileset resource by ID
func get_tileset_resource(tileset_id: String) -> TileSet:
	return tileset_resources.get(tileset_id, null)

## Get tileset texture by ID
func get_tileset_texture(tileset_id: String) -> Texture2D:
	return tileset_textures.get(tileset_id, null)

## Get all available tileset IDs
func get_tileset_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in tileset_data.keys():
		ids.append(str(id))
	return ids

## Get movement cost for a unit at a specific terrain
func get_movement_cost(terrain_id: int, faction: int, unit_type: int) -> int:
	var terrain = get_terrain_data(terrain_id)
	if not terrain:
		return -1  # Impassable
	
	return terrain.get_movement_cost(faction, unit_type)

## Check if asset manager is ready
func is_ready() -> bool:
	return initialized

## Get initialization status
func get_status() -> Dictionary:
	return {
		"initialized": initialized,
		"terrain_count": terrain_data.size(),
		"tileset_count": tileset_data.size(),
		"texture_count": tileset_textures.size(),
		"fe_data_path": fe_data_path
	}
