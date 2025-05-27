## Simple AssetManager Debug
##
## Test AssetManager initialization step by step to find where it fails
extends Node

func _ready():
	print("=== SIMPLE ASSET MANAGER DEBUG ===")
	
	var fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	
	print("1. Before AssetManager.initialize() call")
	print("   → AssetManager.initialized = %s" % AssetManager.initialized)
	print("   → fe_data_path = %s" % fe_data_path)
	
	# Connect to the signal BEFORE calling initialize
	print("2. Connecting to initialization_completed signal...")
	AssetManager.initialization_completed.connect(_on_initialization_completed)
	
	print("3. Calling AssetManager.initialize()...")
	AssetManager.initialize(fe_data_path)
	
	print("4. After AssetManager.initialize() call")
	print("   → AssetManager.initialized = %s" % AssetManager.initialized)
	print("   → terrain_data.size() = %s" % AssetManager.terrain_data.size())
	print("   → tileset_data.size() = %s" % AssetManager.tileset_data.size())
	print("   → tileset_textures.size() = %s" % AssetManager.tileset_textures.size())
	
	print("5. Waiting for signal or timeout...")
	
	# Wait up to 5 seconds for the signal
	var timeout_frames = 300  # 5 seconds at 60 FPS
	
	while timeout_frames > 0:
		await get_tree().process_frame
		timeout_frames -= 1
		
		if AssetManager.initialized:
			print("   → AssetManager reports initialized!")
			break
	
	if timeout_frames <= 0:
		print("   ✗ TIMEOUT: Signal was never received after 5 seconds")
		print("   → This means AssetManager.initialize() never completed")
		_analyze_partial_state()
	else:
		print("   ✓ AssetManager initialization completed successfully")

func _on_initialization_completed():
	print("   ✓ initialization_completed signal received!")

func _analyze_partial_state():
	print("\n=== ANALYZING PARTIAL INITIALIZATION ===")
	
	print("Current AssetManager state:")
	print("  → initialized: %s" % AssetManager.initialized)
	print("  → fe_data_path: '%s'" % AssetManager.fe_data_path)
	print("  → terrain_data count: %d" % AssetManager.terrain_data.size())
	print("  → tileset_data count: %d" % AssetManager.tileset_data.size())
	print("  → tileset_textures count: %d" % AssetManager.tileset_textures.size())
	
	# Check file accessibility
	print("\nFile accessibility check:")
	var terrain_file = AssetManager.fe_data_path + "/Terrain_Data.xml"
	var tileset_file = AssetManager.fe_data_path + "/Tileset_Data.xml"
	var texture_dir = AssetManager.fe_data_path + "/assets/tilesets/"
	
	print("  → Terrain XML exists: %s" % FileAccess.file_exists(terrain_file))
	print("  → Tileset XML exists: %s" % FileAccess.file_exists(tileset_file))
	print("  → Texture directory exists: %s" % DirAccess.dir_exists_absolute(texture_dir))
	
	if DirAccess.dir_exists_absolute(texture_dir):
		var dir = DirAccess.open(texture_dir)
		if dir:
			dir.list_dir_begin()
			var png_count = 0
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".png"):
					png_count += 1
				file_name = dir.get_next()
			print("  → PNG files in texture directory: %d" % png_count)
		else:
			print("  → Could not open texture directory")
