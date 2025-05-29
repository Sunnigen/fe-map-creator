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
	
	# Clear existing data if re-initializing
	terrain_data.clear()
	tileset_data.clear()
	tileset_resources.clear()
	tileset_textures.clear()
	
	# Load data in order
	load_terrain_data()
	load_tileset_data()
	load_tileset_textures()
	
	# NEW: Extract autotiling intelligence from original maps
	extract_autotiling_patterns()
	
	initialized = true
	print("AssetManager initialized successfully")
	print("- Loaded %d terrain types" % terrain_data.size())
	print("- Loaded %d tilesets" % tileset_data.size())
	print("- Loaded %d textures" % tileset_textures.size())
	print("- Pattern analysis completed for smart autotiling")
	
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
	# Try Godot project structure first
	var tilesets_path = "res://assets/tilesets/"
	var dir = DirAccess.open(tilesets_path)
	
	print("Loading tileset textures from: ", tilesets_path)
	
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

## Parse terrain XML data using proper nested XML handling
func parse_terrain_xml(xml_content: String):
	# Clean up the XML content first
	var clean_xml = xml_content.replace("\r", "")
	var terrain_count = 0
	var search_pos = 0
	
	print("Starting terrain XML parsing...")
	
	while true:
		# Find the start of the next <Item> block
		var item_start = clean_xml.find("<Item>", search_pos)
		if item_start == -1:
			break
		
		# Find the matching </Item> by counting nested tags
		var item_end = find_matching_closing_tag(clean_xml, item_start, "<Item>", "</Item>")
		if item_end == -1:
			print("Found <Item> at ", item_start, " but no matching closing </Item>")
			break
		
		# Extract the complete item block including tags
		var complete_item = clean_xml.substr(item_start, item_end - item_start + 7)  # +7 for </Item>
		
		# Find the Value section within the complete Item
		var value_start = complete_item.find("<Value>")
		var value_end = find_matching_closing_tag(complete_item, value_start, "<Value>", "</Value>")
		if value_start == -1 or value_end == -1:
			print("Item has no complete Value section, skipping")
			search_pos = item_end + 7
			continue
		
		var value_section = complete_item.substr(value_start, value_end - value_start + 8)  # +8 for </Value>
		
		var terrain = TerrainData.new()
		
		# Extract key (terrain ID) from the complete Item
		var key_match = _extract_xml_value(complete_item, "Key")
		if key_match.is_empty():
			print("Item has no Key, skipping")
			search_pos = item_end + 7
			continue
		var terrain_id = key_match.to_int()
		
		# Extract terrain properties from the Value section
		terrain.id = _extract_xml_value(value_section, "Id").to_int()
		var extracted_name = _extract_xml_value(value_section, "Name")
		
		# DEBUG: Show what we're extracting for first few terrains
		if terrain_count < 3:
			print("DEBUG terrain %d:" % terrain_count)
			print("  Extracted name: '%s'" % extracted_name)
		
		terrain.name = extracted_name
		terrain.avoid_bonus = _extract_xml_value(value_section, "Avoid").to_int()
		terrain.defense_bonus = _extract_xml_value(value_section, "Def").to_int()
		terrain.resistance_bonus = _extract_xml_value(value_section, "Res").to_int()
		
		# Parse healing data (format: "HP_amount turns" or "Null")
		var heal_data = _extract_xml_value(value_section, "Heal")
		if heal_data != "" and not heal_data.contains("Null"):
			var heal_parts = heal_data.split(" ")
			if heal_parts.size() >= 2:
				terrain.healing_amount = heal_parts[0].to_int()
				terrain.healing_turns = heal_parts[1].to_int()
		
		terrain.sound_group = _extract_xml_value(value_section, "Step_Sound_Group").to_int()
		terrain.stats_visible = _extract_xml_value(value_section, "Stats_Visible") == "true"
		terrain.fire_through = _extract_xml_value(value_section, "Fire_Through") == "true"
		
		# Parse movement costs (more complex)
		parse_movement_costs(value_section, terrain)
		
		terrain_data[terrain_id] = terrain
		
		# Only show first few for debugging
		if terrain_count < 5:
			print("Loaded terrain %d: '%s' (avoid:%d, def:%d)" % [terrain_id, terrain.name, terrain.avoid_bonus, terrain.defense_bonus])
		
		terrain_count += 1
		search_pos = item_end + 7
	
	print("Terrain parsing complete. Loaded ", terrain_count, " terrains.")

## Find matching closing tag by counting nested tags
func find_matching_closing_tag(text: String, start_pos: int, open_tag: String, close_tag: String) -> int:
	var pos = start_pos + open_tag.length()
	var nesting_level = 1
	
	while nesting_level > 0 and pos < text.length():
		# Look for the next occurrence of either opening or closing tag
		var next_open = text.find(open_tag, pos)
		var next_close = text.find(close_tag, pos)
		
		if next_close == -1:
			# No more closing tags found
			return -1
		
		if next_open != -1 and next_open < next_close:
			# Found another opening tag before the closing tag
			nesting_level += 1
			pos = next_open + open_tag.length()
		else:
			# Found a closing tag
			nesting_level -= 1
			if nesting_level == 0:
				return next_close
			pos = next_close + close_tag.length()
	
	return -1

## Parse movement cost data from terrain XML entry
func parse_movement_costs(entry: String, terrain: TerrainData):
	terrain.movement_costs = []
	
	# Look for Move_Costs section
	var start_tag = "<Move_Costs>"
	var end_tag = "</Move_Costs>"
	
	var start_index = entry.find(start_tag)
	if start_index == -1:
		return
	
	var end_index = entry.find(end_tag, start_index)
	if end_index == -1:
		return
	
	var move_costs_section = entry.substr(start_index + start_tag.length(), end_index - start_index - start_tag.length())
	
	# Parse each Item (faction's movement costs)
	var items = move_costs_section.split("<Item>")
	for i in range(1, items.size()):  # Skip first empty split
		var item = items[i]
		if not item.contains("</Item>"):
			continue
			
		var costs_str = item.split("</Item>")[0].strip_edges()
		if costs_str.is_empty():
			continue
		
		# Split the space-separated costs and convert to integers
		var cost_parts = costs_str.split(" ")
		var faction_costs: Array[int] = []
		
		for cost_str in cost_parts:
			cost_str = cost_str.strip_edges()
			if not cost_str.is_empty():
				faction_costs.append(cost_str.to_int())
		
		if faction_costs.size() > 0:
			terrain.movement_costs.append(faction_costs)

## Parse tileset XML data
func parse_tileset_xml(xml_content: String):
	# Split content into entries - the XML uses <Item> tags
	var entries = xml_content.split("<Item>")
	
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
		tileset_data_obj.name = _extract_xml_value(entry, "Name")  # XML uses 'Name' tag
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
	# Clean up line endings first to handle Windows/Unix compatibility
	var clean_xml = xml_text.replace("\r", "")
	
	var start_tag = "<" + tag + ">"
	var end_tag = "</" + tag + ">"
	
	var start_index = clean_xml.find(start_tag)
	if start_index == -1:
		return ""
	
	start_index += start_tag.length()
	var end_index = clean_xml.find(end_tag, start_index)
	if end_index == -1:
		return ""
	
	var result = clean_xml.substr(start_index, end_index - start_index).strip_edges()
	return result

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
	# Try Godot project structure first
	var godot_tilesets_path = "res://assets/tilesets/"
	var original_tilesets_path = fe_data_path + "/Tilesets/"
	
	var tilesets_path = godot_tilesets_path
	var dir = DirAccess.open(tilesets_path)
	
	# If that fails, try original structure
	if not dir:
		tilesets_path = original_tilesets_path
		dir = DirAccess.open(tilesets_path)
	
	if not dir:
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# Create variations of the graphic name to try matching
	var name_variants = [
		graphic_name,
		graphic_name.replace("_", " "),  # Mountain_Village -> Mountain Village
		graphic_name.replace("1", ""),   # Village1 -> Village
		graphic_name.split("_")[0]       # Coastal_Village -> Coastal, Mountain_Village -> Mountain
	]
	
	while file_name != "":
		if file_name.ends_with(".png"):
			# Try all name variants
			for variant in name_variants:
				if not variant.is_empty() and file_name.to_lower().contains(variant.to_lower()):
					return extract_tileset_id_from_filename(file_name)
		file_name = dir.get_next()
	
	return ""

## Find matching tileset ID for a pattern database ID (handles "xx" wildcards)
func find_matching_tileset_id(pattern_db_id: String, tileset_ids: Array) -> String:
	# First try exact match
	if pattern_db_id in tileset_ids:
		return pattern_db_id
	
	# If pattern_db_id contains "xx", try wildcard matching
	if pattern_db_id.contains("xx"):
		# Convert pattern like "5300xx55" to regex pattern "5300..55"
		var regex_pattern = pattern_db_id.replace("xx", "..")
		var regex = RegEx.new()
		regex.compile("^" + regex_pattern + "$")
		
		for tileset_id in tileset_ids:
			if regex.search(tileset_id):
				return tileset_id
	
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

## Safely wait for AssetManager to be ready, handling race conditions
func await_ready() -> void:
	if initialized:
		# Already initialized, return immediately
		return
	
	# Connect to the signal and wait for initialization
	var signal_received = false
	var connection = initialization_completed.connect(
		func(): signal_received = true,
		CONNECT_ONE_SHOT
	)
	
	# Wait with timeout to prevent infinite hangs
	var timeout_time = 10.0  # 10 second timeout
	var start_time = Time.get_time_dict_from_system()
	
	while not initialized and not signal_received:
		await get_tree().process_frame
		
		# Check timeout
		var current_time = Time.get_time_dict_from_system()
		var elapsed = (current_time.hour * 3600 + current_time.minute * 60 + current_time.second) - \
		              (start_time.hour * 3600 + start_time.minute * 60 + start_time.second)
		
		if elapsed > timeout_time:
			push_error("AssetManager initialization timeout after %d seconds" % timeout_time)
			break

## Extract autotiling intelligence from original maps
func extract_autotiling_patterns():
	print("🧠 Extracting autotiling intelligence from original maps...")
	
	# First, try to load existing pattern databases
	var pattern_databases = load_pattern_databases()
	
	# If no existing patterns found, analyze maps to create them
	if pattern_databases.is_empty():
		print("  📊 No existing patterns found, analyzing original maps...")
		pattern_databases = PatternAnalyzer.analyze_all_original_maps(fe_data_path)
		
		# Save the newly generated patterns
		save_pattern_databases(pattern_databases)
	else:
		print("  ✅ Loaded %d existing pattern databases" % pattern_databases.size())
	
	# Integrate pattern databases into tileset data
	print("  🔗 Linking patterns to tilesets...")
	print("  Available tilesets: %s" % str(tileset_data.keys()))
	print("  Pattern databases: %s" % str(pattern_databases.keys()))
	
	for pattern_db_id in pattern_databases:
		var matching_tileset_id = find_matching_tileset_id(pattern_db_id, tileset_data.keys())
		if matching_tileset_id != "":
			tileset_data[matching_tileset_id].autotiling_db = pattern_databases[pattern_db_id]
			tileset_data[matching_tileset_id].pattern_analysis_complete = true
			
			print("  📚 Tileset %s matches pattern DB %s: %d patterns available" % [matching_tileset_id, pattern_db_id, pattern_databases[pattern_db_id].patterns.size()])
		else:
			print("  ⚠️ Pattern database %s has no matching tileset!" % pattern_db_id)

func load_pattern_databases() -> Dictionary:
	var loaded_databases = {}
	var patterns_dir = "res://resources/autotiling_patterns/"
	
	if not DirAccess.dir_exists_absolute(patterns_dir):
		return loaded_databases
	
	var dir = DirAccess.open(patterns_dir)
	if not dir:
		return loaded_databases
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with("_patterns.tres"):
			var pattern_db = load(patterns_dir + file_name) as AutotilingDatabase
			if pattern_db and pattern_db.patterns.size() > 0:
				# Extract tileset ID from filename (e.g., "0100xx03_patterns.tres" -> "0100xx03")
				var tileset_id = file_name.replace("_patterns.tres", "")
				loaded_databases[tileset_id] = pattern_db
		file_name = dir.get_next()
	
	return loaded_databases

func save_pattern_databases(databases: Dictionary):
	var patterns_dir = "res://resources/autotiling_patterns/"
	
	# Create directory if needed
	if not DirAccess.dir_exists_absolute(patterns_dir):
		DirAccess.open("res://").make_dir_recursive(patterns_dir)
	
	# Save each database as a .tres resource
	for tileset_id in databases:
		var save_path = patterns_dir + tileset_id + "_patterns.tres"
		var error = ResourceSaver.save(databases[tileset_id], save_path)
		
		if error == OK:
			pass
			#print("  💾 Saved patterns: ", save_path)
		else:
			push_error("Failed to save pattern database: " + save_path)

## Get initialization status
func get_status() -> Dictionary:
	var autotiling_stats = {}
	for tileset_id in tileset_data:
		var tileset = tileset_data[tileset_id]
		autotiling_stats[tileset_id] = tileset.has_autotiling_intelligence()
	
	return {
		"initialized": initialized,
		"terrain_count": terrain_data.size(),
		"tileset_count": tileset_data.size(),
		"texture_count": tileset_textures.size(),
		"fe_data_path": fe_data_path,
		"autotiling_available": autotiling_stats
	}
