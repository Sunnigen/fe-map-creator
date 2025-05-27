## Debug Map Generation
##
## Script to debug map generation and UI rendering issues.
## Saves generated maps and creates debug visualizations.
extends RefCounted
class_name MapGenerationDebugger

## Save debug data for a generated map
static func debug_map_generation(map: FEMap, generation_params: MapGenerator.GenerationParams):
	print("\n=== MAP GENERATION DEBUG ===")
	
	if not map:
		print("ERROR: Map is null!")
		return
	
	print("Map Details:")
	print("- Name: %s" % map.name)
	print("- Dimensions: %dx%d" % [map.width, map.height])
	print("- Tileset ID: %s" % map.tileset_id)
	print("- Tile data size: %d" % map.tile_data.size())
	print("- Expected size: %d" % (map.width * map.height))
	
	# Check tileset data
	var tileset_data = AssetManager.get_tileset_data(map.tileset_id)
	if tileset_data:
		print("- Tileset found: %s" % tileset_data.name)
		print("- Has TileSet resource: %s" % (tileset_data.tileset_resource != null))
		print("- Has texture: %s" % (tileset_data.texture != null))
		if tileset_data.tileset_resource:
			print("- TileSet sources: %d" % tileset_data.tileset_resource.get_source_count())
	else:
		print("- ERROR: Tileset data not found!")
	
	# Analyze tile distribution
	var tile_counts = {}
	var min_tile = 999999
	var max_tile = -1
	
	for tile in map.tile_data:
		tile_counts[tile] = tile_counts.get(tile, 0) + 1
		min_tile = min(min_tile, tile)
		max_tile = max(max_tile, tile)
	
	print("Tile Analysis:")
	print("- Unique tiles used: %d" % tile_counts.size())
	print("- Tile range: %d to %d" % [min_tile, max_tile])
	print("- Most common tiles:")
	
	# Sort by frequency
	var sorted_tiles = []
	for tile in tile_counts:
		sorted_tiles.append([tile, tile_counts[tile]])
	sorted_tiles.sort_custom(func(a, b): return a[1] > b[1])
	
	for i in range(min(5, sorted_tiles.size())):
		var tile_data = sorted_tiles[i]
		print("  - Tile %d: %d times (%.1f%%)" % [tile_data[0], tile_data[1], (tile_data[1] * 100.0) / map.tile_data.size()])
	
	# Save debug files
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var base_filename = "debug_map_%s" % timestamp
	
	_save_map_data(map, base_filename)
	_create_debug_png(map, tileset_data, base_filename)
	_save_tileset_info(tileset_data, base_filename)
	
	print("Debug files saved with prefix: %s" % base_filename)
	print("=== END MAP GENERATION DEBUG ===\n")

## Save raw map data to file
static func _save_map_data(map: FEMap, base_filename: String):
	var file_path = "/Users/sunnigen/Godot/projects/fe-map-creator/" + base_filename + "_data.txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("ERROR: Could not create debug data file")
		return
	
	file.store_line("=== FE MAP DEBUG DATA ===")
	file.store_line("Name: " + map.name)
	file.store_line("Dimensions: %dx%d" % [map.width, map.height])
	file.store_line("Tileset ID: " + map.tileset_id)
	file.store_line("Total tiles: %d" % map.tile_data.size())
	file.store_line("")
	
	# Save in original .map format
	file.store_line("=== MAP FILE FORMAT ===")
	file.store_line(map.tileset_id)
	file.store_line("%d %d" % [map.width, map.height])
	
	# Write tile data in rows for readability
	for y in range(map.height):
		var row_data = []
		for x in range(map.width):
			row_data.append(str(map.get_tile_at(x, y)))
		file.store_line(" ".join(row_data))
	
	file.store_line("")
	file.store_line("=== TILE GRID VISUALIZATION ===")
	
	# Create a visual representation using characters
	var tile_chars = {}
	var char_index = 0
	var available_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	
	for y in range(map.height):
		var row_chars = []
		for x in range(map.width):
			var tile = map.get_tile_at(x, y)
			if not tile in tile_chars:
				if char_index < available_chars.length():
					tile_chars[tile] = available_chars[char_index]
					char_index += 1
				else:
					tile_chars[tile] = "?"
			row_chars.append(tile_chars[tile])
		file.store_line("".join(row_chars))
	
	file.store_line("")
	file.store_line("=== TILE LEGEND ===")
	for tile in tile_chars:
		file.store_line("%s = tile %d" % [tile_chars[tile], tile])
	
	file.close()
	print("Saved map data to: " + file_path)

## Create debug PNG visualization
static func _create_debug_png(map: FEMap, tileset_data: FETilesetData, base_filename: String):
	if not tileset_data or not tileset_data.texture:
		print("Cannot create debug PNG: no tileset texture")
		return
	
	var png_path = "/Users/sunnigen/Godot/projects/fe-map-creator/" + base_filename + "_visual.png"
	
	# Create image for the map
	var tile_size = 16
	var image_width = map.width * tile_size
	var image_height = map.height * tile_size
	
	var debug_image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	debug_image.fill(Color.BLACK)  # Fill with black background
	
	# Get source texture as Image
	var tileset_image = tileset_data.texture.get_image()
	if not tileset_image:
		print("Could not get tileset image data")
		return
	
	# Draw each tile
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			if tile_index >= 0 and tile_index < 1024:
				# Calculate source position in tileset (32x32 grid)
				var src_x = (tile_index % 32) * tile_size
				var src_y = (tile_index / 32) * tile_size
				
				# Calculate destination position in map
				var dst_x = x * tile_size
				var dst_y = y * tile_size
				
				# Copy tile from tileset to map image
				var src_rect = Rect2i(src_x, src_y, tile_size, tile_size)
				debug_image.blit_rect(tileset_image, src_rect, Vector2i(dst_x, dst_y))
	
	# Save the image
	var error = debug_image.save_png(png_path)
	if error == OK:
		print("Saved debug PNG to: " + png_path)
	else:
		print("Failed to save debug PNG: " + str(error))

## Save tileset information
static func _save_tileset_info(tileset_data: FETilesetData, base_filename: String):
	var file_path = "/Users/sunnigen/Godot/projects/fe-map-creator/" + base_filename + "_tileset.txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("ERROR: Could not create tileset info file")
		return
	
	file.store_line("=== TILESET DEBUG INFO ===")
	
	if tileset_data:
		file.store_line("Tileset ID: " + str(tileset_data.id))
		file.store_line("Tileset Name: " + str(tileset_data.name))
		file.store_line("Graphic Name: " + str(tileset_data.graphic_name))
		file.store_line("Has Texture: " + str(tileset_data.texture != null))
		file.store_line("Has TileSet Resource: " + str(tileset_data.tileset_resource != null))
		file.store_line("Terrain Tags Size: " + str(tileset_data.terrain_tags.size()))
		
		if tileset_data.texture:
			file.store_line("Texture Size: %dx%d" % [tileset_data.texture.get_width(), tileset_data.texture.get_height()])
		
		if tileset_data.tileset_resource:
			var tileset = tileset_data.tileset_resource
			file.store_line("TileSet Source Count: " + str(tileset.get_source_count()))
			
			if tileset.get_source_count() > 0:
				var source = tileset.get_source(0)
				if source is TileSetAtlasSource:
					var atlas_source = source as TileSetAtlasSource
					file.store_line("Atlas Source Texture: " + str(atlas_source.texture != null))
					if atlas_source.texture:
						file.store_line("Atlas Texture Size: %dx%d" % [atlas_source.texture.get_width(), atlas_source.texture.get_height()])
		
		# Sample terrain mappings
		file.store_line("")
		file.store_line("=== TERRAIN MAPPINGS (first 20) ===")
		for i in range(min(20, tileset_data.terrain_tags.size())):
			var terrain_id = tileset_data.terrain_tags[i]
			var terrain_data = AssetManager.get_terrain_data(terrain_id)
			var terrain_name = terrain_data.name if terrain_data else "Unknown"
			file.store_line("Tile %d -> Terrain %d (%s)" % [i, terrain_id, terrain_name])
	else:
		file.store_line("ERROR: Tileset data is null")
	
	file.close()
	print("Saved tileset info to: " + file_path)

## Debug MapCanvas state
static func debug_map_canvas_state(map_canvas: MapCanvas):
	print("\n=== MAP CANVAS DEBUG ===")
	
	if not map_canvas:
		print("ERROR: MapCanvas is null!")
		return
	
	var current_map = map_canvas.get_current_map()
	print("Current Map: %s" % (current_map.name if current_map else "null"))
	
	# Check TileMap state
	var tilemap = map_canvas.tilemap
	if tilemap:
		print("TileMap exists: true")
		print("TileMap visible: %s" % tilemap.visible)
		print("TileMap scale: %s" % tilemap.scale)
		print("TileMap position: %s" % tilemap.position)
		
		var tileset = tilemap.tile_set
		if tileset:
			print("TileSet assigned: true")
			print("TileSet source count: %d" % tileset.get_source_count())
			
			if tileset.get_source_count() > 0:
				var source = tileset.get_source(0)
				print("Source 0 type: %s" % source.get_class())
				if source is TileSetAtlasSource:
					var atlas = source as TileSetAtlasSource
					print("Atlas texture: %s" % (atlas.texture != null))
		else:
			print("TileSet assigned: false")
		
		# Check cell count
		var used_cells = tilemap.get_used_cells(0)
		print("Used cells on layer 0: %d" % used_cells.size())
		
		if used_cells.size() > 0:
			print("Sample cell data:")
			for i in range(min(5, used_cells.size())):
				var cell_pos = used_cells[i]
				var source_id = tilemap.get_cell_source_id(0, cell_pos)
				var atlas_coords = tilemap.get_cell_atlas_coords(0, cell_pos)
				print("  Cell %s: source=%d, atlas=%s" % [cell_pos, source_id, atlas_coords])
	else:
		print("ERROR: TileMap is null!")
	
	print("=== END MAP CANVAS DEBUG ===\n")
