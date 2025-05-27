## Quick Demo of Autotiling Intelligence
##
## Run this script to verify the pattern analysis system is working
extends Node

func _ready():
	print("🚀 Starting Autotiling Intelligence Demo")
	
	# Initialize AssetManager with the correct path
	var fe_data_path = "/Users/sunnigen/Godot/OldFEMapCreator"
	
	print("📂 Initializing AssetManager with path: %s" % fe_data_path)
	AssetManager.initialize(fe_data_path)
	
	# Wait for initialization to complete
	await AssetManager.initialization_completed
	
	print("\n✅ AssetManager initialization complete!")
	demo_autotiling_intelligence()
	
	print("\n🎉 Demo complete! Check AutotilingIntelligenceTest.tscn for full testing interface.")

func demo_autotiling_intelligence():
	print("\n🧠 Testing Autotiling Intelligence:")
	
	# Get available tilesets
	var tileset_ids = AssetManager.get_tileset_ids()
	print("  Found %d tilesets" % tileset_ids.size())
	
	# Test a few tilesets
	var tested = 0
	var intelligent = 0
	
	for tileset_id in tileset_ids:
		if tested >= 5:  # Limit to first 5 for demo
			break
			
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if not tileset_data:
			continue
			
		tested += 1
		print("\n  📊 Tileset: %s (%s)" % [tileset_id, tileset_data.name])
		
		if tileset_data.has_autotiling_intelligence():
			intelligent += 1
			var stats = tileset_data.get_autotiling_stats()
			print("    ✅ Autotiling available: %d patterns, %d terrains" % [stats.patterns, stats.terrain_coverage])
			
			# Test smart tile selection
			test_smart_tile_selection(tileset_data)
		else:
			print("    ❌ No autotiling intelligence available")
	
	print("\n📈 Summary:")
	print("  • Tilesets tested: %d" % tested)
	print("  • With autotiling: %d" % intelligent)
	print("  • Success rate: %.1f%%" % (float(intelligent) / float(tested) * 100.0))

func test_smart_tile_selection(tileset_data: FETilesetData):
	# Test some common scenarios
	var test_cases = [
		{"name": "Plains in plains", "terrain": 1, "neighbors": [1,1,1,1,1,1,1,1]},
		{"name": "Forest edge", "terrain": 2, "neighbors": [1,1,1,2,2,1,1,1]},
		{"name": "Water transition", "terrain": 3, "neighbors": [1,2,1,3,3,3,2,1]}
	]
	
	for test_case in test_cases:
		var smart_tile = tileset_data.get_smart_tile(test_case.terrain, test_case.neighbors)
		var basic_tile = tileset_data.get_basic_tile_for_terrain(test_case.terrain)
		
		if smart_tile != basic_tile:
			print("    🎯 %s: Smart tile %d (basic: %d) - Intelligence active!" % [test_case.name, smart_tile, basic_tile])
		else:
			print("    📍 %s: Tile %d (standard)" % [test_case.name, smart_tile])
