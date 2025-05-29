## Pattern Analyzer
##
## Extracts autotiling intelligence from professional Fire Emblem maps.
## Analyzes tile placement patterns to learn how terrain should connect naturally.
class_name PatternAnalyzer
extends RefCounted

## Progress tracking for pattern analysis
signal analysis_progress(current: int, total: int, message: String)

## Main entry point for pattern analysis
static func analyze_all_original_maps(fe_data_path: String) -> Dictionary:
	print("🔍 Starting autotiling pattern analysis...")
	print("  Data path: %s" % fe_data_path)
	
	var tileset_databases = {}
	var total_maps_processed = 0
	
	# Analyze each game's maps
	for game in ["FE6", "FE7", "FE8"]:
		var maps_path = fe_data_path + "/maps/" + game + " Maps/"
		var game_results = analyze_game_maps(maps_path, tileset_databases)
		total_maps_processed += game_results.get("maps_processed", 0)
		print("  📊 %s: %d maps processed" % [game, game_results.get("maps_processed", 0)])
	
	print("✅ Pattern analysis complete!")
	print("  Total maps analyzed: %d" % total_maps_processed)
	print("  Tilesets with patterns: %d" % tileset_databases.size())
	
	return tileset_databases

## Analyzes all maps for a specific game
static func analyze_game_maps(maps_path: String, databases: Dictionary) -> Dictionary:
	var dir = DirAccess.open(maps_path)
	if not dir:
		push_error("Cannot access maps directory: " + maps_path)
		return {"maps_processed": 0}
	
	var maps_processed = 0
	var game_name = maps_path.split("/")[-2]  # Extract game name from path
	
	# Iterate through tileset folders
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var tileset_path = maps_path + folder_name + "/"
			var tileset_results = analyze_tileset_maps(tileset_path, folder_name, databases, game_name)
			maps_processed += tileset_results.get("maps_processed", 0)
		folder_name = dir.get_next()
	
	return {"maps_processed": maps_processed}

## Analyzes all maps for a specific tileset
static func analyze_tileset_maps(tileset_path: String, tileset_id: String, databases: Dictionary, game_name: String) -> Dictionary:
	print("  📊 Analyzing %s tileset: %s" % [game_name, tileset_id])
	
	# Initialize database for this tileset if needed
	if tileset_id not in databases:
		databases[tileset_id] = AutotilingDatabase.new()
		databases[tileset_id].tileset_id = tileset_id
		databases[tileset_id].initialize()
	
	var db = databases[tileset_id]
	var dir = DirAccess.open(tileset_path)
	var maps_processed = 0
	
	if not dir:
		push_warning("Cannot access tileset directory: " + tileset_path)
		return {"maps_processed": 0}
	
	# Process all .map files in this tileset folder
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".map") and not file_name.contains("Tile Changes"):
			var map_path = tileset_path + file_name
			if extract_patterns_from_map(map_path, db):
				maps_processed += 1
		file_name = dir.get_next()
	
	print("    ✓ Processed %d maps for tileset %s" % [maps_processed, tileset_id])
	return {"maps_processed": maps_processed}

## Extracts patterns from a single map file
static func extract_patterns_from_map(map_path: String, db: AutotilingDatabase) -> bool:
	# Load map using existing MapIO
	var map = MapIO.load_map_from_file(map_path)
	if not map:
		push_warning("Failed to load map: " + map_path)
		return false
	
	# Get tileset data for terrain mapping
	var tileset_data = AssetManager.get_tileset_data(map.tileset_id)
	if not tileset_data:
		push_warning("No tileset data for ID: " + map.tileset_id)
		return false
	
	# Skip maps that are too small for meaningful analysis
	if map.width < 5 or map.height < 5:
		return false
	
	var patterns_extracted = 0
	var source_map_name = map_path.get_file().get_basename()
	
	# Analyze every tile position (except borders to avoid edge cases)
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			if analyze_tile_context(map, x, y, tileset_data, db, source_map_name):
				patterns_extracted += 1
	
	if patterns_extracted > 0:
		#print("    Extracted %d patterns from %s" % [patterns_extracted, source_map_name])
		return true
	
	return false

## Analyzes the terrain context around a specific tile position
static func analyze_tile_context(map: FEMap, x: int, y: int, tileset_data: FETilesetData, db: AutotilingDatabase, source_map: String) -> bool:
	var center_tile = map.get_tile_at(x, y)
	if center_tile < 0:
		return false
	
	var center_terrain = get_terrain_id_for_tile(center_tile, tileset_data)
	
	# Get 8-directional neighbors
	var neighbors = []
	var directions = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),  # NW, N, NE
		Vector2i(-1,  0),                   Vector2i(1,  0),  # W,     E  
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)   # SW, S, SE
	]
	
	for dir in directions:
		var neighbor_tile = map.get_tile_at(x + dir.x, y + dir.y)
		var neighbor_terrain = get_terrain_id_for_tile(neighbor_tile, tileset_data)
		neighbors.append(neighbor_terrain)
	
	# Validate neighbor array
	if neighbors.size() != 8:
		return false
	
	# Store this successful pattern
	db.add_pattern(center_terrain, neighbors, center_tile, source_map)
	return true

## Gets terrain ID for a tile index using tileset data
static func get_terrain_id_for_tile(tile_index: int, tileset_data: FETilesetData) -> int:
	if tile_index < 0 or tile_index >= tileset_data.terrain_tags.size():
		return 0  # Default terrain (usually plains/void)
	return tileset_data.terrain_tags[tile_index]

## Validates extracted patterns for quality
static func validate_pattern_database(db: AutotilingDatabase) -> Dictionary:
	var results = {
		"tileset_id": db.tileset_id,
		"total_patterns": db.patterns.size(),
		"terrain_coverage": {},
		"pattern_quality": {},
		"recommendations": []
	}
	
	# Check terrain coverage
	var terrain_stats = {}
	for signature in db.patterns:
		var pattern = db.patterns[signature] as TilePattern
		var terrain_id = pattern.center_terrain
		
		if terrain_id not in terrain_stats:
			terrain_stats[terrain_id] = {"patterns": 0, "tiles": 0, "frequency": 0}
		
		terrain_stats[terrain_id].patterns += 1
		terrain_stats[terrain_id].tiles += pattern.valid_tiles.size()
		terrain_stats[terrain_id].frequency += pattern.frequency
	
	results.terrain_coverage = terrain_stats
	
	# Generate recommendations
	for terrain_id in terrain_stats:
		var stats = terrain_stats[terrain_id]
		if stats.patterns < 5:
			results.recommendations.append("Terrain %d has limited patterns (%d)" % [terrain_id, stats.patterns])
		if stats.frequency < 10:
			results.recommendations.append("Terrain %d appears infrequently (%d occurrences)" % [terrain_id, stats.frequency])
	
	# Check pattern quality distribution
	var quality_stats = {"high": 0, "medium": 0, "low": 0}
	for signature in db.patterns:
		var pattern = db.patterns[signature] as TilePattern
		var quality = pattern.get_quality_score()
		
		if quality >= 0.7:
			quality_stats.high += 1
		elif quality >= 0.4:
			quality_stats.medium += 1
		else:
			quality_stats.low += 1
	
	results.pattern_quality = quality_stats
	
	# Add quality recommendations
	if quality_stats.low > quality_stats.high:
		results.recommendations.append("Many low-quality patterns detected - consider processing more maps")
	
	return results

## Gets summary statistics for all analyzed tilesets
static func get_analysis_summary(databases: Dictionary) -> Dictionary:
	var summary = {
		"total_tilesets": databases.size(),
		"total_patterns": 0,
		"total_terrains": 0,
		"tileset_breakdown": {},
		"recommendations": []
	}
	
	for tileset_id in databases:
		var db = databases[tileset_id] as AutotilingDatabase
		var validation = validate_pattern_database(db)
		
		summary.total_patterns += db.patterns.size()
		summary.total_terrains += db.terrain_tiles.size()
		summary.tileset_breakdown[tileset_id] = {
			"patterns": db.patterns.size(),
			"terrains": db.terrain_tiles.size(),
			"quality": validation.pattern_quality
		}
		
		# Collect recommendations
		for rec in validation.recommendations:
			summary.recommendations.append("[%s] %s" % [tileset_id, rec])
	
	# Overall recommendations  
	if summary.total_tilesets < 20:
		summary.recommendations.append("Consider analyzing more tilesets for better coverage")
	
	return summary

## Exports analysis results to debug files
static func export_analysis_debug(databases: Dictionary, output_path: String):
	print("📊 Exporting analysis debug data to: %s" % output_path)
	
	# Create output directory if needed
	if not DirAccess.dir_exists_absolute(output_path):
		DirAccess.open(output_path.get_base_dir()).make_dir_recursive(output_path.get_file())
	
	# Export summary
	var summary = get_analysis_summary(databases)
	var summary_file = FileAccess.open(output_path + "/analysis_summary.json", FileAccess.WRITE)
	if summary_file:
		summary_file.store_string(JSON.stringify(summary, "\t"))
		summary_file.close()
	
	# Export individual tileset data
	for tileset_id in databases:
		var db = databases[tileset_id] as AutotilingDatabase
		var validation = validate_pattern_database(db)
		
		var tileset_file = FileAccess.open("%s/tileset_%s.json" % [output_path, tileset_id], FileAccess.WRITE)
		if tileset_file:
			tileset_file.store_string(JSON.stringify(validation, "\t"))
			tileset_file.close()
	
	print("  ✅ Debug data exported successfully")

## Progress tracking helper for UI integration
class ProgressTracker:
	var current: int = 0
	var total: int = 0
	var message: String = ""
	
	func update(curr: int, tot: int, msg: String):
		current = curr
		total = tot
		message = msg
		# Could emit signal here for UI updates
		
	func get_percentage() -> int:
		return int((float(current) / float(total)) * 100.0) if total > 0 else 0
