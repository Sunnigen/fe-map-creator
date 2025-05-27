#!/usr/bin/env -S godot --headless --script

# Debug script to test terrain XML parsing
extends SceneTree

func _initialize():
	print("=== Debugging Terrain XML Parsing ===")
	
	# Read the XML file
	var xml_path = "/Users/sunnigen/Godot/projects/fe-map-creator/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open terrain data file")
		quit()
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("File loaded successfully, length: ", xml_content.length())
	
	# Split content into entries
	var entries = xml_content.split("<Item>")
	print("Found ", entries.size(), " entries")
	
	# Test parsing the first few real entries
	for i in range(1, min(4, entries.size())):  # Skip first empty entry, test first 3
		var entry = entries[i]
		print("\n--- Testing Entry ", i, " ---")
		
		# Show first 200 chars of entry
		print("Entry preview: ", entry.substr(0, 200), "...")
		
		# Find Value section
		var value_start = entry.find("<Value>")
		var value_end = entry.find("</Value>")
		
		if value_start == -1 or value_end == -1:
			print("ERROR: No Value section found")
			continue
		
		var value_section = entry.substr(value_start, value_end - value_start + 8)
		print("Value section preview: ", value_section.substr(0, 200), "...")
		
		# Test key extraction
		var key_match = _extract_xml_value(entry, "Key")
		print("Key: '", key_match, "'")
		
		# Test name extraction from value section
		var name_match = _extract_xml_value(value_section, "n")
		print("Name: '", name_match, "'")
		
		# Test other properties
		var id_match = _extract_xml_value(value_section, "Id")
		print("ID: '", id_match, "'")
		var avoid_match = _extract_xml_value(value_section, "Avoid")
		print("Avoid: '", avoid_match, "'")
	
	print("\n=== Test Complete ===")
	quit()

# Helper function (copy from AssetManager)
func _extract_xml_value(xml_text: String, tag: String) -> String:
	var start_tag = "<" + tag + ">"
	var end_tag = "</" + tag + ">"
	
	var start_index = xml_text.find(start_tag)
	if start_index == -1:
		print("DEBUG: Tag '", tag, "' not found in text")
		return ""
	
	start_index += start_tag.length()
	var end_index = xml_text.find(end_tag, start_index)
	if end_index == -1:
		print("DEBUG: End tag for '", tag, "' not found")
		return ""
	
	var result = xml_text.substr(start_index, end_index - start_index).strip_edges()
	print("DEBUG: Extracted '", tag, "' = '", result, "'")
	return result
