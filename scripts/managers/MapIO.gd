## Map Input/Output Manager
##
## Handles loading and saving Fire Emblem maps in various formats.
## Supports the original FEMapCreator .map format and new formats.
class_name MapIO
extends RefCounted

## Load a Fire Emblem map from a .map file
static func load_map_from_file(file_path: String) -> FEMap:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open map file: " + file_path)
		return null
	
	print("Loading map from: ", file_path)
	
	# Parse map format:
	# Line 1: Tileset ID
	# Line 2: Width Height
	# Remaining: Tile data (space-separated)
	
	var tileset_id = file.get_line().strip_edges()
	var dimensions_line = file.get_line().strip_edges()
	var dimensions = dimensions_line.split(" ")
	
	if dimensions.size() != 2:
		push_error("Invalid map format: expected width/height on line 2")
		file.close()
		return null
	
	var width = dimensions[0].to_int()
	var height = dimensions[1].to_int()
	
	if width <= 0 or height <= 0:
		push_error("Invalid map dimensions: %dx%d" % [width, height])
		file.close()
		return null
	
	# Create map
	var map = FEMap.new()
	map.tileset_id = tileset_id
	map.width = width
	map.height = height
	map.filename = file_path.get_file()
	map.name = file_path.get_file().get_basename()
	
	# Read remaining content as tile data
	var remaining_text = file.get_as_text()
	file.close()
	
	# Parse all tile indices
	var tile_indices: Array[int] = []
	var parts = remaining_text.split(" ")
	
	for part in parts:
		var clean_part = part.strip_edges()
		if clean_part != "" and clean_part.is_valid_int():
			tile_indices.append(clean_part.to_int())
	
	# Validate tile count
	var expected_tiles = width * height
	if tile_indices.size() != expected_tiles:
		push_warning("Map tile count mismatch: expected %d, got %d" % [expected_tiles, tile_indices.size()])
		
		# Pad or trim as needed
		while tile_indices.size() < expected_tiles:
			tile_indices.append(0)
		while tile_indices.size() > expected_tiles:
			tile_indices.pop_back()
	
	map.tile_data = tile_indices
	
	print("Map loaded successfully: %dx%d, tileset %s" % [width, height, tileset_id])
	return map

## Save a Fire Emblem map to a .map file
static func save_map_to_file(map: FEMap, file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Could not create map file: " + file_path)
		return false
	
	print("Saving map to: ", file_path)
	
	# Write header
	file.store_line(map.tileset_id)
	file.store_line(str(map.width) + " " + str(map.height))
	
	# Write tile data in rows for readability
	for y in range(map.height):
		var row_data: Array[String] = []
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			row_data.append(str(tile_index))
		file.store_line(" ".join(row_data))
	
	file.close()
	
	print("Map saved successfully")
	return true

## Load multiple maps from a directory
static func load_maps_from_directory(directory_path: String, recursive: bool = true) -> Array[FEMap]:
	var maps: Array[FEMap] = []
	var dir = DirAccess.open(directory_path)
	
	if not dir:
		push_error("Could not open directory: " + directory_path)
		return maps
	
	_scan_directory_for_maps(dir, directory_path, maps, recursive)
	
	print("Loaded %d maps from directory: %s" % [maps.size(), directory_path])
	return maps

## Recursively scan directory for .map files
static func _scan_directory_for_maps(dir: DirAccess, current_path: String, maps: Array[FEMap], recursive: bool):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = current_path + "/" + file_name
		
		if dir.current_is_dir() and recursive and file_name != "." and file_name != "..":
			# Recursively scan subdirectory
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_scan_directory_for_maps(sub_dir, full_path, maps, recursive)
		elif file_name.ends_with(".map"):
			# Load map file
			var map = load_map_from_file(full_path)
			if map:
				maps.append(map)
		
		file_name = dir.get_next()

## Export map to JSON format
static func export_to_json(map: FEMap, file_path: String) -> bool:
	var data = {
		"version": "1.0",
		"name": map.name,
		"description": map.description,
		"tileset_id": map.tileset_id,
		"dimensions": {
			"width": map.width,
			"height": map.height
		},
		"tiles": map.tile_data,
		"metadata": {
			"created": Time.get_datetime_string_from_system(),
			"original_filename": map.filename
		}
	}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Could not create JSON file: " + file_path)
		return false
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	
	print("Map exported to JSON: ", file_path)
	return true

## Import map from JSON format
static func import_from_json(file_path: String) -> FEMap:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open JSON file: " + file_path)
		return null
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Invalid JSON in file: " + file_path)
		return null
	
	var data = json.data
	
	# Create map from JSON data
	var map = FEMap.new()
	map.name = data.get("name", "")
	map.description = data.get("description", "")
	map.tileset_id = data.get("tileset_id", "")
	
	var dimensions = data.get("dimensions", {})
	map.width = dimensions.get("width", 20)
	map.height = dimensions.get("height", 15)
	
	var tiles = data.get("tiles", [])
	map.tile_data = []
	for tile in tiles:
		map.tile_data.append(int(tile))
	
	# Validate and fix tile data if needed
	var expected_size = map.width * map.height
	while map.tile_data.size() < expected_size:
		map.tile_data.append(0)
	while map.tile_data.size() > expected_size:
		map.tile_data.pop_back()
	
	print("Map imported from JSON: ", file_path)
	return map

## Create a Godot scene from a map
static func export_to_scene(map: FEMap, file_path: String) -> bool:
	# Get tileset resource
	var tileset_resource = AssetManager.get_tileset_resource(map.tileset_id)
	if not tileset_resource:
		push_error("No tileset resource found for: " + map.tileset_id)
		return false
	
	# Create TileMap
	var tilemap = TileMap.new()
	tilemap.name = "FEMap_" + (map.name if map.name else "Untitled")
	tilemap.tile_set = tileset_resource
	
	# Populate tiles
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			var atlas_coords = Vector2i(tile_index % 32, tile_index / 32)
			tilemap.set_cell(0, Vector2i(x, y), 0, atlas_coords)
	
	# Create scene
	var scene = PackedScene.new()
	scene.pack(tilemap)
	
	var result = ResourceSaver.save(scene, file_path)
	if result != OK:
		push_error("Failed to save scene: " + file_path)
		return false
	
	print("Map exported to scene: ", file_path)
	return true

## Get list of all .map files in FE data directory
static func get_available_maps(fe_data_path: String) -> Dictionary:
	var map_collections = {}
	
	# Check each game directory
	var games = ["FE6", "FE7", "FE8"]
	for game in games:
		var game_path = fe_data_path + "/" + game + " Maps"
		var dir = DirAccess.open(game_path)
		if not dir:
			continue
		
		map_collections[game] = []
		
		# Scan game directory
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		
		while folder_name != "":
			if dir.current_is_dir() and folder_name != "." and folder_name != "..":
				var folder_path = game_path + "/" + folder_name
				var maps_in_folder = _get_maps_in_folder(folder_path)
				
				if maps_in_folder.size() > 0:
					map_collections[game].append({
						"folder": folder_name,
						"path": folder_path,
						"maps": maps_in_folder
					})
			
			folder_name = dir.get_next()
	
	return map_collections

## Get all .map files in a specific folder
static func _get_maps_in_folder(folder_path: String) -> Array[Dictionary]:
	var maps: Array[Dictionary] = []
	var dir = DirAccess.open(folder_path)
	if not dir:
		return maps
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".map"):
			maps.append({
				"name": file_name.get_basename(),
				"filename": file_name,
				"path": folder_path + "/" + file_name
			})
		file_name = dir.get_next()
	
	return maps

## Validate a map file without fully loading it
static func validate_map_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"valid": false, "error": "Could not open file"}
	
	var line_count = 0
	var tileset_id = ""
	var width = 0
	var height = 0
	var tile_count = 0
	
	# Read first two lines
	if not file.eof_reached():
		tileset_id = file.get_line().strip_edges()
		line_count += 1
	
	if not file.eof_reached():
		var dimensions_line = file.get_line().strip_edges()
		line_count += 1
		var parts = dimensions_line.split(" ")
		if parts.size() == 2:
			width = parts[0].to_int()
			height = parts[1].to_int()
	
	# Count remaining tiles
	var remaining_text = file.get_as_text()
	var tile_parts = remaining_text.split(" ")
	for part in tile_parts:
		if part.strip_edges() != "" and part.strip_edges().is_valid_int():
			tile_count += 1
	
	file.close()
	
	var expected_tiles = width * height
	var valid = width > 0 and height > 0 and tile_count == expected_tiles
	
	return {
		"valid": valid,
		"tileset_id": tileset_id,
		"width": width,
		"height": height,
		"expected_tiles": expected_tiles,
		"actual_tiles": tile_count,
		"line_count": line_count
	}
