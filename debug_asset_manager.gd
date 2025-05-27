## Debug AssetManager Initialization
##
## Script to debug exactly where AssetManager initialization fails
extends Node

func _ready():
	print("=== ASSET MANAGER INITIALIZATION DEBUG ===")
	
	# Test initialization step by step
	var fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	
	print("Step 1: Setting up AssetManager...")
	AssetManager.fe_data_path = fe_data_path
	AssetManager.initialized = false
	
	print("Step 2: Testing terrain data loading...")
	_test_terrain_loading(fe_data_path)
	
	print("Step 3: Testing tileset data loading...")
	_test_tileset_loading(fe_data_path)
	
	print("Step 4: Testing texture loading...")
	_test_texture_loading(fe_data_path)
	
	print("Step 5: Testing signal emission...")
	_test_signal_emission()
	
	print("=== INITIALIZATION DEBUG COMPLETE ===")

func _test_terrain_loading(fe_data_path: String):
	print("  → Loading terrain data...")
	
	var xml_path = fe_data_path + "/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("  ✗ FAILED: Could not open terrain data file: " + xml_path)
		return
	else:
		print("  ✓ Terrain data file opened successfully")
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("  → XML content length: %d characters" % xml_content.length())
	
	# Test the parsing directly
	print("  → Calling AssetManager.load_terrain_data()...")
	AssetManager.load_terrain_data()
	print("  ✓ Terrain loading completed: %d terrains loaded" % AssetManager.terrain_data.size())

func _test_tileset_loading(fe_data_path: String):
	print("  → Loading tileset data...")
	
	var xml_path = fe_data_path + "/Tileset_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("  ✗ FAILED: Could not open tileset data file: " + xml_path)
		return
	else:
		print("  ✓ Tileset data file opened successfully")
	
	file.close()
	
	print("  → Calling AssetManager.load_tileset_data()...")
	AssetManager.load_tileset_data()
	print("  ✓ Tileset loading completed: %d tilesets loaded" % AssetManager.tileset_data.size())

func _test_texture_loading(fe_data_path: String):
	print("  → Loading textures...")
	
	var assets_path = fe_data_path + "/assets/tilesets/"
	var dir = DirAccess.open(assets_path)
	if not dir:
		print("  ✗ FAILED: Could not open texture directory: " + assets_path)
		return
	else:
		print("  ✓ Texture directory accessible")
	
	# Count PNG files
	dir.list_dir_begin()
	var png_count = 0
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png"):
			png_count += 1
		file_name = dir.get_next()
	
	print("  → Found %d PNG files in directory" % png_count)
	
	print("  → Calling AssetManager.load_tileset_textures()...")
	AssetManager.load_tileset_textures()
	print("  ✓ Texture loading completed: %d textures loaded" % AssetManager.tileset_textures.size())

func _test_signal_emission():
	print("  → Testing signal emission...")
	
	# Connect to the signal to verify it works
	var signal_received = false
	
	var signal_callback = func():
		signal_received = true
		print("  ✓ initialization_completed signal received!")
	
	AssetManager.initialization_completed.connect(signal_callback)
	
	# Try to emit the signal manually
	print("  → Manually emitting signal...")
	AssetManager.initialization_completed.emit()
	
	# Wait a frame for signal processing
	await get_tree().process_frame
	
	if signal_received:
		print("  ✓ Signal emission working correctly")
	else:
		print("  ✗ FAILED: Signal was not received")
	
	# Disconnect the test signal
	AssetManager.initialization_completed.disconnect(signal_callback)


