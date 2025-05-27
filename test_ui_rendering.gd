## Test Map Generation and Rendering
##
## Reproduces the exact "Generate Map" button scenario to debug UI rendering
extends Node

func _ready():
	print("=== MAP GENERATION AND RENDERING TEST ===")
	
	# Initialize AssetManager (we know this works now)
	var fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	AssetManager.initialize(fe_data_path)
	
	if not AssetManager.initialized:
		print("ERROR: AssetManager failed to initialize")
		return
	
	print("✓ AssetManager initialized: %d terrains, %d tilesets, %d textures" % [
		AssetManager.terrain_data.size(),
		AssetManager.tileset_data.size(), 
		AssetManager.tileset_textures.size()
	])
	
	# Test the exact scenario from the "Generate Map" button
	print("\n=== TESTING GENERATE MAP BUTTON SCENARIO ===")
	
	var tileset_ids = AssetManager.get_tileset_ids()
	print("Available tilesets: %s" % str(tileset_ids.slice(0, 3)))  # Show first 3
	
	# Create a preset exactly like the editor does
	var params = MapGenerator.create_preset("small_skirmish", tileset_ids[0])
	print("Generation parameters:")
	print("- Size: %dx%d" % [params.width, params.height])
	print("- Tileset: %s" % params.tileset_id)
	print("- Algorithm: %s" % _get_algorithm_name(params.algorithm))
	
	# Generate map exactly like Editor._on_map_generation_requested()
	print("\n→ Calling MapGenerator.generate_map()...")
	var generated_map = MapGenerator.generate_map(params)
	
	if not generated_map:
		print("✗ Map generation failed!")
		return
	
	print("✓ Map generated: %dx%d with %d tiles" % [generated_map.width, generated_map.height, generated_map.tile_data.size()])
	
	# DEBUG: Save map files like we would in the editor
	print("\n→ Creating debug files...")
	MapGenerationDebugger.debug_map_generation(generated_map, params)
	
	# Test loading map exactly like Editor._load_map() -> MapCanvas.load_map()
	print("\n=== TESTING MAPCANVAS LOADING SCENARIO ===")
	_test_map_loading(generated_map)
	
	print("\n=== TEST COMPLETE ===")
	print("Check debug files in project directory for visual verification!")

func _test_map_loading(map: FEMap):
	print("→ Simulating MapCanvas.load_map()...")
	
	# Get tileset data exactly like MapCanvas does
	var current_tileset_data = AssetManager.get_tileset_data(map.tileset_id)
	if not current_tileset_data:
		print("✗ Could not load tileset data for: %s" % map.tileset_id)
		return
	
	print("✓ Tileset data loaded: %s" % current_tileset_data.name)
	print("  - Has texture: %s" % (current_tileset_data.texture != null))
	print("  - Has TileSet resource: %s" % (current_tileset_data.tileset_resource != null))
	
	if not current_tileset_data.tileset_resource:
		print("✗ No TileSet resource available!")
		return
	
	# Create TileMap exactly like MapCanvas does
	print("→ Creating TileMap and setting TileSet...")
	var tilemap = TileMap.new()
	tilemap.tile_set = current_tileset_data.tileset_resource
	
	print("✓ TileMap created")
	print("  - TileSet assigned: %s" % (tilemap.tile_set != null))
	
	if tilemap.tile_set:
		var tileset = tilemap.tile_set
		print("  - TileSet source count: %d" % tileset.get_source_count())
		
		if tileset.get_source_count() > 0:
			var source = tileset.get_source(0)
			print("  - Source type: %s" % source.get_class())
			if source is TileSetAtlasSource:
				var atlas_source = source as TileSetAtlasSource
				print("  - Atlas texture: %s" % (atlas_source.texture != null))
				if atlas_source.texture:
					print("  - Atlas size: %dx%d" % [atlas_source.texture.get_width(), atlas_source.texture.get_height()])
	
	# Test _refresh_tilemap() exactly like MapCanvas does
	print("→ Simulating MapCanvas._refresh_tilemap()...")
	tilemap.clear()
	
	var tiles_set = 0
	var tiles_failed = 0
	
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			if tile_index >= 0:
				var atlas_coords = Vector2i(tile_index % 32, tile_index / 32)
				tilemap.set_cell(0, Vector2i(x, y), 0, atlas_coords)
				tiles_set += 1
			else:
				tiles_failed += 1
	
	print("✓ Attempted to set %d tiles (%d failed)" % [tiles_set, tiles_failed])
	
	# Check if tiles were actually set
	var used_cells = tilemap.get_used_cells(0)
	print("✓ TileMap reports %d used cells" % used_cells.size())
	
	if used_cells.size() == 0:
		print("✗ PROBLEM FOUND: No cells were set in TileMap!")
		print("  This explains why the MapCanvas appears empty!")
		_diagnose_tilemap_issue(tilemap, map, current_tileset_data)
	else:
		print("✓ TileMap cell setting working correctly")
		# Show a few sample cells
		for i in range(min(3, used_cells.size())):
			var cell_pos = used_cells[i]
			var source_id = tilemap.get_cell_source_id(0, cell_pos)
			var atlas_coords = tilemap.get_cell_atlas_coords(0, cell_pos)
			print("  Sample cell %s: source=%d, atlas=%s" % [cell_pos, source_id, atlas_coords])
	
	# Clean up
	tilemap.queue_free()

func _diagnose_tilemap_issue(tilemap: TileMap, map: FEMap, tileset_data: FETilesetData):
	print("\n=== DIAGNOSING TILEMAP ISSUE ===")
	
	# Test with a simple tile
	print("→ Testing simple tile placement...")
	var test_tile_index = 0  # Try tile 0
	var test_atlas_coords = Vector2i(0, 0)
	
	tilemap.set_cell(0, Vector2i(0, 0), 0, test_atlas_coords)
	var test_cells = tilemap.get_used_cells(0)
	
	if test_cells.size() > 0:
		print("✓ Simple tile placement works")
	else:
		print("✗ Even simple tile placement fails!")
		
		# Check TileSet validity in detail
		if not tilemap.tile_set:
			print("  → TileSet is null")
		elif tilemap.tile_set.get_source_count() == 0:
			print("  → TileSet has no sources")
		else:
			var source = tilemap.tile_set.get_source(0)
			if not source:
				print("  → Source 0 is null")
			elif not source is TileSetAtlasSource:
				print("  → Source 0 is not TileSetAtlasSource: %s" % source.get_class())
			else:
				var atlas = source as TileSetAtlasSource
				if not atlas.texture:
					print("  → Atlas texture is null")
				else:
					print("  → Atlas texture is valid: %dx%d" % [atlas.texture.get_width(), atlas.texture.get_height()])
					print("  → Unknown TileMap issue!")

func _get_algorithm_name(algorithm: MapGenerator.Algorithm) -> String:
	match algorithm:
		MapGenerator.Algorithm.RANDOM: return "Random"
		MapGenerator.Algorithm.PERLIN_NOISE: return "Perlin Noise"
		MapGenerator.Algorithm.CELLULAR_AUTOMATA: return "Cellular Automata"
		MapGenerator.Algorithm.TEMPLATE_BASED: return "Template Based"
		MapGenerator.Algorithm.STRATEGIC_PLACEMENT: return "Strategic Placement"
		_: return "Unknown"
