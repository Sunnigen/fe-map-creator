## Map Validator
##
## Validates Fire Emblem maps for common issues and provides suggestions
## for improvements. Checks terrain layout, balance, and tactical considerations.
class_name MapValidator
extends RefCounted

# Validation issue severity
enum Severity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

# Issue categories
enum Category {
	TERRAIN,
	BALANCE,
	ACCESSIBILITY,
	TACTICAL,
	TECHNICAL
}

# Validation issue
class ValidationIssue:
	var severity: Severity
	var category: Category
	var title: String
	var description: String
	var position: Vector2i = Vector2i(-1, -1)
	var affected_area: Rect2i = Rect2i()
	var suggestion: String = ""
	var auto_fixable: bool = false
	
	func _init(sev: Severity, cat: Category, issue_title: String, desc: String):
		severity = sev
		category = cat
		title = issue_title
		description = desc
	
	func set_position(pos: Vector2i) -> ValidationIssue:
		position = pos
		return self
	
	func set_area(area: Rect2i) -> ValidationIssue:
		affected_area = area
		return self
	
	func set_suggestion(sug: String) -> ValidationIssue:
		suggestion = sug
		return self
	
	func set_auto_fixable(fixable: bool) -> ValidationIssue:
		auto_fixable = fixable
		return self

# Validation result
class ValidationResult:
	var issues: Array[ValidationIssue] = []
	var stats: Dictionary = {}
	var is_valid: bool = true
	var validation_time: float = 0.0
	
	func add_issue(issue: ValidationIssue):
		issues.append(issue)
		if issue.severity >= Severity.ERROR:
			is_valid = false
	
	func get_issues_by_severity(severity: Severity) -> Array[ValidationIssue]:
		var filtered: Array[ValidationIssue] = []
		for issue in issues:
			if issue.severity == severity:
				filtered.append(issue)
		return filtered
	
	func get_issues_by_category(category: Category) -> Array[ValidationIssue]:
		var filtered: Array[ValidationIssue] = []
		for issue in issues:
			if issue.category == category:
				filtered.append(issue)
		return filtered
	
	func has_critical_issues() -> bool:
		return get_issues_by_severity(Severity.CRITICAL).size() > 0
	
	func get_summary() -> String:
		var counts = {
			Severity.INFO: 0,
			Severity.WARNING: 0,
			Severity.ERROR: 0,
			Severity.CRITICAL: 0
		}
		
		for issue in issues:
			counts[issue.severity] += 1
		
		return "Issues: %d Critical, %d Error, %d Warning, %d Info" % [
			counts[Severity.CRITICAL],
			counts[Severity.ERROR],
			counts[Severity.WARNING],
			counts[Severity.INFO]
		]

## Validate a Fire Emblem map
static func validate_map(map: FEMap) -> ValidationResult:
	var start_time = Time.get_ticks_msec()
	var result = ValidationResult.new()
	
	if not map:
		var issue = ValidationIssue.new(Severity.CRITICAL, Category.TECHNICAL, "Null Map", "Map is null or invalid")
		result.add_issue(issue)
		return result
	
	# Get tileset data
	var tileset_data = AssetManager.get_tileset_data(map.tileset_id)
	if not tileset_data:
		var issue = ValidationIssue.new(Severity.CRITICAL, Category.TECHNICAL, "Missing Tileset", "Tileset data not found for: " + map.tileset_id)
		result.add_issue(issue)
		return result
	
	# Run validation checks
	_validate_basic_structure(map, result)
	_validate_terrain_distribution(map, tileset_data, result)
	_validate_accessibility(map, tileset_data, result)
	_validate_tactical_balance(map, tileset_data, result)
	_validate_map_bounds(map, result)
	_validate_spawn_areas(map, tileset_data, result)
	
	# Calculate statistics
	result.stats = _calculate_map_statistics(map, tileset_data)
	
	var end_time = Time.get_ticks_msec()
	result.validation_time = (end_time - start_time) / 1000.0
	
	return result

## Validate basic map structure
static func _validate_basic_structure(map: FEMap, result: ValidationResult):
	# Check dimensions
	if map.width < 10 or map.height < 10:
		var issue = ValidationIssue.new(Severity.WARNING, Category.TECHNICAL, 
			"Small Map", "Map is very small (%dx%d). Consider at least 15x10 for tactical gameplay." % [map.width, map.height])
		result.add_issue(issue.set_suggestion("Resize map to at least 15x10 tiles"))
	
	if map.width > 50 or map.height > 50:
		var issue = ValidationIssue.new(Severity.WARNING, Category.TECHNICAL,
			"Large Map", "Map is very large (%dx%d). May cause performance issues." % [map.width, map.height])
		result.add_issue(issue.set_suggestion("Consider breaking into smaller maps or optimizing"))
	
	# Check tile data integrity
	var expected_tiles = map.width * map.height
	if map.tile_data.size() != expected_tiles:
		var issue = ValidationIssue.new(Severity.ERROR, Category.TECHNICAL,
			"Tile Data Mismatch", "Expected %d tiles, found %d." % [expected_tiles, map.tile_data.size()])
		result.add_issue(issue.set_auto_fixable(true))
	
	# Check for invalid tile indices
	var invalid_count = 0
	for i in range(map.tile_data.size()):
		var tile_index = map.tile_data[i]
		if tile_index < 0 or tile_index >= 1024:
			invalid_count += 1
	
	if invalid_count > 0:
		var issue = ValidationIssue.new(Severity.ERROR, Category.TECHNICAL,
			"Invalid Tiles", "%d tiles have invalid indices (outside 0-1023 range)." % invalid_count)
		result.add_issue(issue.set_auto_fixable(true))

## Validate terrain distribution
static func _validate_terrain_distribution(map: FEMap, tileset_data: FETilesetData, result: ValidationResult):
	var terrain_counts = {}
	var total_tiles = map.tile_data.size()
	
	# Count terrain types
	for tile_index in map.tile_data:
		if tile_index < tileset_data.terrain_tags.size():
			var terrain_id = tileset_data.terrain_tags[tile_index]
			terrain_counts[terrain_id] = terrain_counts.get(terrain_id, 0) + 1
	
	# Check for terrain variety
	if terrain_counts.size() < 3:
		var issue = ValidationIssue.new(Severity.WARNING, Category.TERRAIN,
			"Low Terrain Variety", "Map uses only %d terrain types. Consider adding more variety." % terrain_counts.size())
		result.add_issue(issue.set_suggestion("Add forests, hills, or other tactical terrain"))
	
	# Check for dominant terrain
	for terrain_id in terrain_counts:
		var count = terrain_counts[terrain_id]
		var percentage = (float(count) / float(total_tiles)) * 100.0
		
		if percentage > 70.0:
			var terrain_data = AssetManager.get_terrain_data(terrain_id)
			var terrain_name = terrain_data.name if terrain_data else "Unknown"
			
			var issue = ValidationIssue.new(Severity.WARNING, Category.BALANCE,
				"Dominant Terrain", "%s covers %.1f%% of the map. Consider more variety." % [terrain_name, percentage])
			result.add_issue(issue.set_suggestion("Add other terrain types for tactical depth"))

## Validate accessibility (can units reach all areas?)
static func _validate_accessibility(map: FEMap, tileset_data: FETilesetData, result: ValidationResult):
	# Simple flood fill to check if all passable tiles are connected
	var passable_tiles = {}
	var total_passable = 0
	
	# Find all passable tiles for infantry
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			if tile_index >= 0 and tile_index < tileset_data.terrain_tags.size():
				var terrain_id = tileset_data.terrain_tags[tile_index]
				var terrain_data = AssetManager.get_terrain_data(terrain_id)
				
				if terrain_data and terrain_data.is_passable(0, 0):  # Player infantry
					passable_tiles[Vector2i(x, y)] = true
					total_passable += 1
	
	if total_passable == 0:
		var issue = ValidationIssue.new(Severity.CRITICAL, Category.ACCESSIBILITY,
			"No Passable Terrain", "Map has no passable terrain for infantry units.")
		result.add_issue(issue)
		return
	
	# Flood fill from first passable tile
	var start_pos: Vector2i
	for pos in passable_tiles:
		start_pos = pos
		break
	
	var reachable = _flood_fill_passable(map, tileset_data, start_pos, passable_tiles)
	
	if reachable < total_passable:
		var unreachable = total_passable - reachable
		var issue = ValidationIssue.new(Severity.WARNING, Category.ACCESSIBILITY,
			"Unreachable Areas", "%d passable tiles cannot be reached by infantry." % unreachable)
		result.add_issue(issue.set_suggestion("Add bridges or paths to connect isolated areas"))

## Flood fill to count reachable passable tiles
static func _flood_fill_passable(map: FEMap, tileset_data: FETilesetData, start: Vector2i, passable_tiles: Dictionary) -> int:
	var visited = {}
	var stack = [start]
	var count = 0
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		var key = str(pos.x) + "," + str(pos.y)
		
		if key in visited or not pos in passable_tiles:
			continue
		
		visited[key] = true
		count += 1
		
		# Add neighbors
		var neighbors = [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]
		
		for neighbor in neighbors:
			if neighbor.x >= 0 and neighbor.x < map.width and neighbor.y >= 0 and neighbor.y < map.height:
				if neighbor in passable_tiles:
					stack.append(neighbor)
	
	return count

## Validate tactical balance
static func _validate_tactical_balance(map: FEMap, tileset_data: FETilesetData, result: ValidationResult):
	var defensive_tiles = 0
	var total_tiles = map.tile_data.size()
	
	# Count defensive terrain
	for tile_index in map.tile_data:
		if tile_index < tileset_data.terrain_tags.size():
			var terrain_id = tileset_data.terrain_tags[tile_index]
			var terrain_data = AssetManager.get_terrain_data(terrain_id)
			
			if terrain_data and (terrain_data.defense_bonus > 0 or terrain_data.avoid_bonus > 10):
				defensive_tiles += 1
	
	var defensive_percentage = (float(defensive_tiles) / float(total_tiles)) * 100.0
	
	if defensive_percentage < 15.0:
		var issue = ValidationIssue.new(Severity.WARNING, Category.TACTICAL,
			"Low Defensive Terrain", "Only %.1f%% of tiles provide defensive bonuses." % defensive_percentage)
		result.add_issue(issue.set_suggestion("Add forests, hills, or forts for tactical positioning"))
	
	elif defensive_percentage > 60.0:
		var issue = ValidationIssue.new(Severity.WARNING, Category.TACTICAL,
			"Too Much Defensive Terrain", "%.1f%% of tiles provide defensive bonuses. May slow gameplay." % defensive_percentage)
		result.add_issue(issue.set_suggestion("Balance with open terrain for unit movement"))

## Validate map bounds
static func _validate_map_bounds(map: FEMap, result: ValidationResult):
	# Check for empty borders (might indicate map could be smaller)
	var empty_borders = {
		"top": true,
		"bottom": true,
		"left": true,
		"right": true
	}
	
	# Check top and bottom rows
	for x in range(map.width):
		if map.get_tile_at(x, 0) != 0:
			empty_borders["top"] = false
		if map.get_tile_at(x, map.height - 1) != 0:
			empty_borders["bottom"] = false
	
	# Check left and right columns
	for y in range(map.height):
		if map.get_tile_at(0, y) != 0:
			empty_borders["left"] = false
		if map.get_tile_at(map.width - 1, y) != 0:
			empty_borders["right"] = false
	
	var empty_count = 0
	for border in empty_borders.values():
		if border:
			empty_count += 1
	
	if empty_count >= 2:
		var issue = ValidationIssue.new(Severity.INFO, Category.TECHNICAL,
			"Empty Borders", "Map has %d empty borders. Consider resizing to optimize space." % empty_count)
		result.add_issue(issue.set_suggestion("Trim empty borders or add decorative terrain"))

## Validate spawn areas (look for good starting positions)
static func _validate_spawn_areas(map: FEMap, tileset_data: FETilesetData, result: ValidationResult):
	# Look for clusters of good starting terrain (plains, roads)
	var good_spawn_terrain = []
	
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			if tile_index < tileset_data.terrain_tags.size():
				var terrain_id = tileset_data.terrain_tags[tile_index]
				var terrain_data = AssetManager.get_terrain_data(terrain_id)
				
				# Good spawn terrain: passable with low movement cost
				if terrain_data and terrain_data.is_passable(0, 0):
					var move_cost = terrain_data.get_movement_cost(0, 0)
					if move_cost <= 2:  # Easy movement
						good_spawn_terrain.append(Vector2i(x, y))
	
	if good_spawn_terrain.size() < 10:
		var issue = ValidationIssue.new(Severity.WARNING, Category.TACTICAL,
			"Limited Spawn Areas", "Few tiles suitable for unit deployment. Consider adding plains or roads.")
		result.add_issue(issue.set_suggestion("Add plains or road tiles near map edges for unit spawning"))

## Calculate detailed map statistics
static func _calculate_map_statistics(map: FEMap, tileset_data: FETilesetData) -> Dictionary:
	var stats = {
		"dimensions": "%dx%d" % [map.width, map.height],
		"total_tiles": map.tile_data.size(),
		"terrain_types": {},
		"terrain_distribution": {},
		"movement_analysis": {},
		"defensive_analysis": {},
		"special_features": {}
	}
	
	# Analyze terrain distribution
	var terrain_counts = {}
	for tile_index in map.tile_data:
		if tile_index < tileset_data.terrain_tags.size():
			var terrain_id = tileset_data.terrain_tags[tile_index]
			terrain_counts[terrain_id] = terrain_counts.get(terrain_id, 0) + 1
	
	stats.terrain_types = terrain_counts.size()
	
	for terrain_id in terrain_counts:
		var count = terrain_counts[terrain_id]
		var percentage = (float(count) / float(map.tile_data.size())) * 100.0
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		var terrain_name = terrain_data.name if terrain_data else "Unknown"
		
		stats.terrain_distribution[terrain_name] = {
			"count": count,
			"percentage": percentage
		}
	
	# Movement analysis
	var passable_count = 0
	var difficult_count = 0
	
	for tile_index in map.tile_data:
		if tile_index < tileset_data.terrain_tags.size():
			var terrain_id = tileset_data.terrain_tags[tile_index]
			var terrain_data = AssetManager.get_terrain_data(terrain_id)
			
			if terrain_data:
				var move_cost = terrain_data.get_movement_cost(0, 0)  # Player infantry
				if move_cost > 0:
					passable_count += 1
					if move_cost > 2:
						difficult_count += 1
	
	stats.movement_analysis = {
		"passable_tiles": passable_count,
		"passable_percentage": (float(passable_count) / float(map.tile_data.size())) * 100.0,
		"difficult_terrain": difficult_count
	}
	
	# Defensive analysis
	var defensive_tiles = 0
	var healing_tiles = 0
	
	for tile_index in map.tile_data:
		if tile_index < tileset_data.terrain_tags.size():
			var terrain_id = tileset_data.terrain_tags[tile_index]
			var terrain_data = AssetManager.get_terrain_data(terrain_id)
			
			if terrain_data:
				if terrain_data.defense_bonus > 0 or terrain_data.avoid_bonus > 0:
					defensive_tiles += 1
				if terrain_data.healing_amount > 0:
					healing_tiles += 1
	
	stats.defensive_analysis = {
		"defensive_tiles": defensive_tiles,
		"defensive_percentage": (float(defensive_tiles) / float(map.tile_data.size())) * 100.0,
		"healing_tiles": healing_tiles
	}
	
	# Special features
	stats.special_features = {
		"animated_tiles": tileset_data.animated_tiles.size(),
		"unique_terrains": terrain_counts.size()
	}
	
	return stats

## Auto-fix common issues
static func auto_fix_map(map: FEMap, issues: Array[ValidationIssue]) -> int:
	var fixed_count = 0
	
	for issue in issues:
		if not issue.auto_fixable:
			continue
		
		match issue.title:
			"Tile Data Mismatch":
				_fix_tile_data_mismatch(map)
				fixed_count += 1
			"Invalid Tiles":
				_fix_invalid_tiles(map)
				fixed_count += 1
	
	return fixed_count

## Fix tile data size mismatch
static func _fix_tile_data_mismatch(map: FEMap):
	var expected_size = map.width * map.height
	while map.tile_data.size() < expected_size:
		map.tile_data.append(0)
	while map.tile_data.size() > expected_size:
		map.tile_data.pop_back()

## Fix invalid tile indices
static func _fix_invalid_tiles(map: FEMap):
	for i in range(map.tile_data.size()):
		var tile_index = map.tile_data[i]
		if tile_index < 0 or tile_index >= 1024:
			map.tile_data[i] = 0  # Replace with safe default
