## Quick Test: Hardcode Terrain Names
##
## Test if hardcoding terrain names fixes map generation
extends Node

func _ready():
	print("=== TERRAIN NAME OVERRIDE TEST ===")
	
	# Initialize AssetManager normally
	var fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	AssetManager.initialize(fe_data_path)
	
	print("Original terrain names (first 5):")
	for i in range(5):
		if i in AssetManager.terrain_data:
			var terrain = AssetManager.terrain_data[i]
			print("  Terrain %d: '%s'" % [i, terrain.name])
	
	# OVERRIDE: Manually fix terrain names
	print("\nOverriding terrain names...")
	_fix_terrain_names()
	
	print("Fixed terrain names (first 5):")
	for i in range(5):
		if i in AssetManager.terrain_data:
			var terrain = AssetManager.terrain_data[i]
			print("  Terrain %d: '%s'" % [i, terrain.name])
	
	# Test map generation with fixed names
	print("\n=== TESTING MAP GENERATION WITH FIXED NAMES ===")
	var tileset_ids = AssetManager.get_tileset_ids()
	var test_tileset_id = tileset_ids[0]
	
	var params = MapGenerator.GenerationParams.new()
	params.width = 8
	params.height = 6
	params.tileset_id = test_tileset_id
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.PLAINS
	params.seed_value = 12345
	
	print("Generating map with fixed terrain names...")
	var generated_map = MapGenerator.generate_map(params)
	
	if generated_map:
		print("✓ Map generation successful!")
		print("Map dimensions: %dx%d" % [generated_map.width, generated_map.height])
		
		# Check tile variety
		var tile_counts = {}
		for tile in generated_map.tile_data:
			tile_counts[tile] = tile_counts.get(tile, 0) + 1
		
		print("Tile variety: %d unique tiles" % tile_counts.size())
		print("Tile distribution:")
		for tile in tile_counts:
			print("  Tile %d: %d times (%.1f%%)" % [tile, tile_counts[tile], (tile_counts[tile] * 100.0) / generated_map.tile_data.size()])
		
		# Print a small sample of the map
		print("\nMap sample (first 8x6):")
		for y in range(generated_map.height):
			var row = []
			for x in range(generated_map.width):
				row.append(str(generated_map.get_tile_at(x, y)))
			print("  " + " ".join(row))
		
		# Create debug files
		print("\nCreating debug files...")
		MapGenerationDebugger.debug_map_generation(generated_map, params)
		
	else:
		print("✗ Map generation failed even with fixed names!")

func _fix_terrain_names():
	# Hardcode some common Fire Emblem terrain names based on typical terrain IDs
	var terrain_name_fixes = {
		0: "Debug",
		1: "Plains", 
		2: "Road",
		3: "Village",
		4: "Village", 
		5: "House",
		6: "Armory",
		7: "Vendor",
		8: "Arena",
		10: "Fort",
		11: "Gate",
		12: "Forest",
		13: "Thicket",
		14: "Sand",
		15: "Desert",
		16: "River",
		17: "Hill",
		18: "Peak",
		19: "Bridge",
		21: "Sea",
		22: "Lake",
		23: "Floor",
		25: "Fence",
		26: "Wall",
		27: "Wall",
		29: "Pillar",
		30: "Door",
		31: "Throne",
		32: "Chest",
		33: "Chest",
		34: "Roof",
		35: "Gate"
	}
	
	for terrain_id in terrain_name_fixes:
		if terrain_id in AssetManager.terrain_data:
			AssetManager.terrain_data[terrain_id].name = terrain_name_fixes[terrain_id]
			print("  Fixed terrain %d: '%s'" % [terrain_id, terrain_name_fixes[terrain_id]])
