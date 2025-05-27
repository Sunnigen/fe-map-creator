@tool
## Quick Phase 1 Status Check
##
## This script can be run from the Godot editor to quickly check Phase 1 status.
## Use Tools > Execute Script or run this scene to see results in the output panel.
extends EditorScript

func _run():
	print("🔍 Phase 1 Quick Status Check")
	print("=" * 50)
	
	_check_files()
	_check_data_path()
	_check_asset_manager()
	_provide_recommendations()
	
	print("=" * 50)
	print("✅ Quick check complete! Run Phase1Verification.tscn for detailed testing.")

func _check_files():
	print("\n📁 Checking File Structure:")
	
	var required_files = [
		"res://scripts/resources/TilePattern.gd",
		"res://scripts/resources/AutotilingDatabase.gd", 
		"res://scripts/tools/PatternAnalyzer.gd",
		"res://Phase1Verification.tscn"
	]
	
	var missing_files = []
	
	for file_path in required_files:
		if FileAccess.file_exists(file_path):
			print("  ✅ %s" % file_path.get_file())
		else:
			print("  ❌ %s" % file_path.get_file())
			missing_files.append(file_path)
	
	if missing_files.is_empty():
		print("  🎉 All required files present!")
	else:
		print("  ⚠️ Missing %d files - Phase 1 incomplete" % missing_files.size())

func _check_data_path():
	print("\n📂 Checking FE Data Path:")
	
	var data_path = "/Users/sunnigen/Godot/OldFEMapCreator"
	
	if DirAccess.dir_exists_absolute(data_path):
		print("  ✅ FE data directory exists: %s" % data_path)
		
		# Check for key subdirectories
		var required_dirs = ["FE6 Maps", "FE7 Maps", "FE8 Maps", "Tilesets"]
		var missing_dirs = []
		
		for dir_name in required_dirs:
			var full_path = data_path + "/" + dir_name
			if DirAccess.dir_exists_absolute(full_path):
				print("  ✅ %s/" % dir_name)
			else:
				print("  ❌ %s/" % dir_name)
				missing_dirs.append(dir_name)
		
		# Check for XML files
		var xml_files = ["Terrain_Data.xml", "Tileset_Data.xml"]
		for xml_file in xml_files:
			var xml_path = data_path + "/" + xml_file
			if FileAccess.file_exists(xml_path):
				print("  ✅ %s" % xml_file)
			else:
				print("  ❌ %s" % xml_file)
		
		if missing_dirs.is_empty():
			print("  🎉 FE data structure looks good!")
		else:
			print("  ⚠️ Missing directories: %s" % str(missing_dirs))
	else:
		print("  ❌ FE data directory not found: %s" % data_path)
		print("     Make sure the FEMapCreator data is at this location")

func _check_asset_manager():
	print("\n⚙️ Checking AssetManager Integration:")
	
	# Check if AssetManager has new methods
	var has_extract_method = AssetManager.has_method("extract_autotiling_patterns")
	var has_save_method = AssetManager.has_method("save_pattern_databases")
	
	print("  • extract_autotiling_patterns(): %s" % ("✅" if has_extract_method else "❌"))
	print("  • save_pattern_databases(): %s" % ("✅" if has_save_method else "❌"))
	
	if AssetManager.initialized:
		print("  ✅ AssetManager is initialized")
		
		# Check if any tilesets have autotiling
		var tileset_ids = AssetManager.get_tileset_ids()
		print("  📊 Found %d tilesets" % tileset_ids.size())
		
		var intelligent_tilesets = 0
		for tileset_id in tileset_ids:
			var tileset_data = AssetManager.get_tileset_data(tileset_id)
			if tileset_data and tileset_data.has_method("has_autotiling_intelligence"):
				if tileset_data.has_autotiling_intelligence():
					intelligent_tilesets += 1
		
		print("  🧠 Tilesets with intelligence: %d" % intelligent_tilesets)
		
		if intelligent_tilesets > 0:
			print("  🎉 Autotiling intelligence is active!")
		else:
			print("  ⚠️ No intelligent tilesets found - pattern extraction may not have run")
	else:
		print("  ⚠️ AssetManager not initialized - run a scene that initializes it first")

func _provide_recommendations():
	print("\n💡 Recommendations:")
	
	# Check overall status and provide guidance
	var files_ok = FileAccess.file_exists("res://scripts/resources/TilePattern.gd")
	var data_path_ok = DirAccess.dir_exists_absolute("/Users/sunnigen/Godot/OldFEMapCreator")
	var integration_ok = AssetManager.has_method("extract_autotiling_patterns")
	
	if files_ok and data_path_ok and integration_ok:
		print("  🚀 Everything looks good! Run Phase1Verification.tscn for comprehensive testing.")
		print("  📖 See PHASE1_VERIFICATION_GUIDE.md for detailed instructions.")
	elif not files_ok:
		print("  🔧 Some Phase 1 files are missing - check that all scripts were created correctly.")
	elif not data_path_ok:
		print("  📂 FE data path issue - verify that /Users/sunnigen/Godot/OldFEMapCreator exists.")
	elif not integration_ok:
		print("  ⚙️ AssetManager integration incomplete - check that AssetManager.gd was updated correctly.")
	else:
		print("  🔍 Mixed results - run Phase1Verification.tscn for detailed diagnosis.")
