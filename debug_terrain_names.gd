## Debug Terrain Name Extraction
##
## Test exactly why terrain names are empty
extends Node

func _ready():
	print("=== TERRAIN NAME EXTRACTION DEBUG ===")
	
	var xml_path = "/Users/sunnigen/Godot/projects/fe-map-creator/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open terrain file")
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("XML file length: %d characters" % xml_content.length())
	
	# Test the exact parsing logic from AssetManager
	var clean_xml = xml_content.replace("\r", "")
	var search_pos = 0
	var terrain_count = 0
	
	# Find the first few <Item> blocks like AssetManager does
	for test_item in range(3):  # Test first 3 terrains
		var item_start = clean_xml.find("<Item>", search_pos)
		if item_start == -1:
			break
		
		print("\n--- Testing Item %d ---" % test_item)
		print("Item starts at position: %d" % item_start)
		
		# Find the matching </Item> using the same logic as AssetManager
		var item_end = _find_matching_closing_tag(clean_xml, item_start, "<Item>", "</Item>")
		if item_end == -1:
			print("ERROR: No matching </Item> found")
			break
		
		print("Item ends at position: %d" % item_end)
		
		# Extract the complete item
		var complete_item = clean_xml.substr(item_start, item_end - item_start + 7)
		print("Complete item length: %d characters" % complete_item.length())
		
		# Find Value section
		var value_start = complete_item.find("<Value>")
		var value_end = _find_matching_closing_tag(complete_item, value_start, "<Value>", "</Value>")
		
		if value_start == -1 or value_end == -1:
			print("ERROR: No complete Value section found")
			search_pos = item_end + 7
			continue
		
		print("Value section: start=%d, end=%d" % [value_start, value_end])
		
		var value_section = complete_item.substr(value_start, value_end - value_start + 8)
		print("Value section length: %d characters" % value_section.length())
		
		# Show first part of value section
		print("Value section preview:")
		print(value_section.substr(0, 200))
		print("...")
		
		# Test name extraction
		print("\n--- Testing Name Extraction ---")
		var extracted_name = _extract_xml_value(value_section, "n")
		print("Extracted name: '%s'" % extracted_name)
		
		# Test other fields for comparison
		var extracted_id = _extract_xml_value(value_section, "Id")
		var extracted_avoid = _extract_xml_value(value_section, "Avoid")
		print("Extracted ID: '%s'" % extracted_id)
		print("Extracted Avoid: '%s'" % extracted_avoid)
		
		# Manual check for <n> tags
		print("\n--- Manual Name Check ---")
		var n_start = value_section.find("<n>")
		var n_end = value_section.find("</n>")
		if n_start != -1 and n_end != -1:
			var manual_name = value_section.substr(n_start + 3, n_end - n_start - 3)
			print("Manual extraction: '%s'" % manual_name)
		else:
			print("No <n> tags found manually!")
			# Look for any text that might be the name
			if value_section.contains("Plains"):
				print("Found 'Plains' in value section")
			if value_section.contains("Road"):
				print("Found 'Road' in value section")
		
		search_pos = item_end + 7
	
	print("\n=== TERRAIN EXTRACTION DEBUG COMPLETE ===")

# Copy the exact functions from AssetManager
func _find_matching_closing_tag(text: String, start_pos: int, open_tag: String, close_tag: String) -> int:
	var pos = start_pos + open_tag.length()
	var nesting_level = 1
	
	while nesting_level > 0 and pos < text.length():
		var next_open = text.find(open_tag, pos)
		var next_close = text.find(close_tag, pos)
		
		if next_close == -1:
			return -1
		
		if next_open != -1 and next_open < next_close:
			nesting_level += 1
			pos = next_open + open_tag.length()
		else:
			nesting_level -= 1
			if nesting_level == 0:
				return next_close
			pos = next_close + close_tag.length()
	
	return -1

func _extract_xml_value(xml_text: String, tag: String) -> String:
	var start_tag = "<" + tag + ">"
	var end_tag = "</" + tag + ">"
	
	var start_index = xml_text.find(start_tag)
	if start_index == -1:
		return ""
	
	start_index += start_tag.length()
	var end_index = xml_text.find(end_tag, start_index)
	if end_index == -1:
		return ""
	
	var result = xml_text.substr(start_index, end_index - start_index).strip_edges()
	return result
