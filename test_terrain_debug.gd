# Simple test to debug terrain name extraction
extends Node

func _ready():
	print("=== Debugging Terrain Name Extraction ===")
	
	# Test with a small sample from the actual XML
	var sample_xml = """
	<Item>
		<Key>1</Key>
		<Value>
			<Id>1</Id>
			<n>Plains</n>
			<Avoid>0</Avoid>
			<Def>0</Def>
			<Res>0</Res>
		</Value>
	</Item>
	"""
	
	print("Testing with sample XML:")
	print(sample_xml)
	
	# Test the extraction logic
	var value_start = sample_xml.find("<Value>")
	var value_end = sample_xml.find("</Value>")
	
	print("Value start: ", value_start)
	print("Value end: ", value_end)
	
	if value_start != -1 and value_end != -1:
		var value_section = sample_xml.substr(value_start, value_end - value_start + 8)
		print("Value section extracted:")
		print(value_section)
		
		# Test name extraction
		var name = _extract_xml_value(value_section, "n")
		print("Extracted name: '", name, "'")
		
		var id = _extract_xml_value(value_section, "Id")
		print("Extracted ID: '", id, "'")
	else:
		print("ERROR: Could not find Value section")
	
	# Now test with the actual file
	print("\n=== Testing with actual file ===")
	var xml_path = "/Users/sunnigen/Godot/projects/fe-map-creator/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if file:
		var xml_content = file.get_as_text()
		file.close()
		
		# Test just the first terrain entry (Plains)
		var entries = xml_content.split("<Item>")
		print("Found ", entries.size(), " entries")
		
		# Find the Plains entry (should be entry with ID 1)
		for i in range(1, min(5, entries.size())):
			var entry = entries[i]
			
			# Check if this contains Plains
			if entry.contains("<n>Plains</n>"):
				print("\nFound Plains entry!")
				print("Entry preview: ", entry.substr(0, 300))
				
				var val_start = entry.find("<Value>")
				var val_end = entry.find("</Value>")
				
				if val_start != -1 and val_end != -1:
					var val_section = entry.substr(val_start, val_end - val_start + 8)
					print("Value section for Plains:")
					print(val_section.substr(0, 200))
					
					var plains_name = _extract_xml_value(val_section, "n")
					print("Plains name extracted: '", plains_name, "'")
				break
	else:
		print("ERROR: Could not open terrain file")

func _extract_xml_value(xml_text: String, tag: String) -> String:
	var start_tag = "<" + tag + ">"
	var end_tag = "</" + tag + ">"
	
	print("Looking for tag: ", start_tag, " in text length: ", xml_text.length())
	
	var start_index = xml_text.find(start_tag)
	if start_index == -1:
		print("Start tag not found!")
		return ""
	
	start_index += start_tag.length()
	var end_index = xml_text.find(end_tag, start_index)
	if end_index == -1:
		print("End tag not found!")
		return ""
	
	var result = xml_text.substr(start_index, end_index - start_index).strip_edges()
	print("Extracted: '", result, "'")
	return result
