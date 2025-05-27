## Manual Test Script for Map Generation Debugging
##
## Run this script to generate a test map and create debug files
extends Node

func _ready():
	print("=== MANUAL MAP GENERATION DEBUG TEST ===")
	
	# Initialize AssetManager
	var fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	print("About to call AssetManager.initialize() with path: %s" % fe_data_path)
	
	# Connect to signal first
	AssetManager.initialization_completed.connect(_on_asset_manager_ready)
	
	AssetManager.initialize(fe_data_path)
	print("AssetManager.initialize() call completed")
	print("AssetManager.initialized = %s" % AssetManager.initialized)
	
	# Skip the await since AssetManager.initialize() is synchronous
	if AssetManager.initialized:
		print("AssetManager ready immediately - proceeding...")
		_continue_test()
	else:
		print("AssetManager not ready - waiting for signal...")
		await AssetManager.initialization_completed
		print("Signal received! Continuing...")
		_continue_test()

func _continue_test():
	print("AssetManager initialized")
	var status = AssetManager.get_status()
	print("- Terrain count: %d" % status.terrain_count)
	print("- Tileset count: %d" % status.tileset_count)
	print("- Texture count: %d" % status.texture_count)
	
	# Create generation parameters
	var tileset_ids = AssetManager.get_tileset_ids()
	if tileset_ids.is_empty():
		print("ERROR: No tilesets available!")
		return
	
	print("Available tilesets: %s" % str(tileset_ids))
	
	# Test with first available tileset
	var test_tileset_id = tileset_ids[0]
	print("Using tileset: %s" % test_tileset_id)
	
	# Create test parameters
	var params = MapGenerator.GenerationParams.new()
	params.width = 15
	params.height = 10
	params.tileset_id = test_tileset_id
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.PLAINS
	params.seed_value = 12345
	
	print("Generating map with parameters:")
	print("- Size: %dx%d" % [params.width, params.height])
	print("- Algorithm: %s" % _get_algorithm_name(params.algorithm))
	print("- Theme: %s" % _get_theme_name(params.map_theme))
	print("- Seed: %d" % params.seed_value)
	
	# Generate map
	var generated_map = MapGenerator.generate_map(params)
	
	if generated_map:
		print("Map generation successful!")
		
		# Create debug files using our debugger
		MapGenerationDebugger.debug_map_generation(generated_map, params)
		
		# Test tileset loading
		print("\n=== TILESET LOADING TEST ===")
		var tileset_data = AssetManager.get_tileset_data(test_tileset_id)
		if tileset_data:
			print("Tileset data found: %s" % tileset_data.name)
			print("Has texture: %s" % (tileset_data.texture != null))
			print("Has TileSet resource: %s" % (tileset_data.tileset_resource != null))
			
			if tileset_data.texture:
				print("Texture size: %dx%d" % [tileset_data.texture.get_width(), tileset_data.texture.get_height()])
			
			if tileset_data.tileset_resource:
				var tileset = tileset_data.tileset_resource
				print("TileSet source count: %d" % tileset.get_source_count())
				
				if tileset.get_source_count() > 0:
					var source = tileset.get_source(0)
					print("Source type: %s" % source.get_class())
					if source is TileSetAtlasSource:
						var atlas = source as TileSetAtlasSource
						print("Atlas has texture: %s" % (atlas.texture != null))
						if atlas.texture:
							print("Atlas texture size: %dx%d" % [atlas.texture.get_width(), atlas.texture.get_height()])
		
		# Test manual TileMap creation
		print("\n=== MANUAL TILEMAP TEST ===")
		_test_manual_tilemap_creation(generated_map, tileset_data)
		
	else:
		print("Map generation FAILED!")
	
	print("\n=== DEBUG TEST COMPLETE ===")
	print("Check the project directory for debug files:")
	print("- debug_map_*_data.txt (map data)")
	print("- debug_map_*_visual.png (visual representation)")
	print("- debug_map_*_tileset.txt (tileset information)")

func _on_asset_manager_ready():
	print("*** AssetManager initialization_completed signal callback triggered ***")

func _test_manual_tilemap_creation(map: FEMap, tileset_data: FETilesetData):
	print("Testing manual TileMap creation...")
	
	# Create a minimal scene to test TileMap rendering
	var test_scene = Node2D.new()
	var tilemap = TileMap.new()
	
	# Set up the tilemap
	tilemap.tile_set = tileset_data.tileset_resource
	test_scene.add_child(tilemap)
	
	print("TileMap created with TileSet: %s" % (tilemap.tile_set != null))
	
	if tilemap.tile_set:
		print("Setting up test tiles...")
		
		# Set a few test tiles
		for y in range(min(3, map.height)):
			for x in range(min(3, map.width)):
				var tile_index = map.get_tile_at(x, y)
				var atlas_coords = Vector2i(tile_index % 32, tile_index / 32)
				tilemap.set_cell(0, Vector2i(x, y), 0, atlas_coords)
				print("Set cell (%d,%d) to tile %d (atlas %s)" % [x, y, tile_index, atlas_coords])
		
		# Check if cells were actually set
		var used_cells = tilemap.get_used_cells(0)
		print("TileMap has %d used cells" % used_cells.size())
		
		if used_cells.size() > 0:
			print("Sample cells:")
			for i in range(min(3, used_cells.size())):
				var cell_pos = used_cells[i]
				var source_id = tilemap.get_cell_source_id(0, cell_pos)
				var atlas_coords = tilemap.get_cell_atlas_coords(0, cell_pos)
				print("  Cell %s: source=%d, atlas=%s" % [cell_pos, source_id, atlas_coords])
		else:
			print("WARNING: No cells were set in TileMap!")
	else:
		print("ERROR: TileMap.tile_set is null!")
	
	# Clean up
	test_scene.queue_free()

func _get_algorithm_name(algorithm: MapGenerator.Algorithm) -> String:
	match algorithm:
		MapGenerator.Algorithm.RANDOM:
			return "Random"
		MapGenerator.Algorithm.PERLIN_NOISE:
			return "Perlin Noise"
		MapGenerator.Algorithm.CELLULAR_AUTOMATA:
			return "Cellular Automata"
		MapGenerator.Algorithm.TEMPLATE_BASED:
			return "Template Based"
		MapGenerator.Algorithm.STRATEGIC_PLACEMENT:
			return "Strategic Placement"
		_:
			return "Unknown"

func _get_theme_name(theme: MapGenerator.MapTheme) -> String:
	match theme:
		MapGenerator.MapTheme.PLAINS:
			return "Plains"
		MapGenerator.MapTheme.FOREST:
			return "Forest"
		MapGenerator.MapTheme.MOUNTAIN:
			return "Mountain"
		MapGenerator.MapTheme.DESERT:
			return "Desert"
		MapGenerator.MapTheme.CASTLE:
			return "Castle"
		MapGenerator.MapTheme.VILLAGE:
			return "Village"
		MapGenerator.MapTheme.MIXED:
			return "Mixed"
		_:
			return "Unknown"
