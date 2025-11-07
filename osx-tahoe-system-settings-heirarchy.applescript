-- UI Element Hierarchy to JSON Exporter
-- This script captures the UI element hierarchy of a window and saves it as JSON

use AppleScript version "2.4"
use scripting additions
use framework "Foundation"

-- CONFIGURATION: Set your target application and window here
property targetApp : "System Settings" -- Change to your target application name
property targetPane : "com.apple.Displays-Settings.extension"
property targetWindowIndex : 1 -- Which window (1 = front window)

-- Main execution
on run
	tell application "System Settings"
		activate
		delay 0.5
		reveal pane id "com.apple.Displays-Settings.extension"
		delay 0.5
	end tell

	try
		tell application "System Events"
			tell process targetApp
				if not (exists window targetWindowIndex) then
					error "Window " & targetWindowIndex & " does not exist in " & targetApp
				end if

				set windowObj to window targetWindowIndex
				set windowData to my buildElementData(windowObj, 0)

				-- Convert to JSON
				set jsonString to my convertToJSON(windowData)

				-- Save to file
				set desktopPath to (path to desktop as text)
				set fileName to targetApp & "_window_hierarchy.json"
				set filePath to desktopPath & fileName

				my writeTextToFile(jsonString, filePath)

				display dialog "Hierarchy saved to:" & return & fileName buttons {"OK"} default button 1

			end tell
		end tell
	on error errMsg
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon stop
	end try
end run

-- Build element data recursively
on buildElementData(uiElement, depth)
	tell application "System Events"
		-- Create record with properly escaped property names
		set elementData to {elementClass:missing value, elementRole:missing value, elementIdentifier:missing value, elementTitle:missing value, elementDescription:missing value, elementChildren:{}}

		try
			set elementData's elementClass to class of uiElement as text
		end try

		try
			set elementData's elementRole to role of uiElement as text
		end try

		try
			set idValue to value of attribute "AXIdentifier" of uiElement
			if idValue is not missing value and idValue is not "" then
				set elementData's elementIdentifier to idValue as text
			end if
		end try

		try
			set titleValue to title of uiElement
			if titleValue is not missing value and titleValue is not "" then
				set elementData's elementTitle to titleValue as text
			end if
		end try

		try
			set descValue to description of uiElement
			if descValue is not missing value and descValue is not "" then
				set elementData's elementDescription to descValue as text
			end if
		end try

		-- Recursively process children (limit depth to avoid huge files)
		if depth < 10 then
			try
				set childElements to UI elements of uiElement
				set childList to {}
				repeat with childElement in childElements
					set end of childList to my buildElementData(childElement, depth + 1)
				end repeat
				set elementData's elementChildren to childList
			end try
		end if

		return elementData
	end tell
end buildElementData

-- Convert record to JSON string
on convertToJSON(dataRecord)
	set theDict to my recordToNSDictionary(dataRecord)

	-- Serialize to JSON
	set {jsonData, jsonError} to current application's NSJSONSerialization's dataWithJSONObject:theDict options:(current application's NSJSONWritingPrettyPrinted) |error|:(reference)

	if jsonData is missing value then
		error "JSON serialization failed"
	end if

	set jsonString to current application's NSString's alloc()'s initWithData:jsonData encoding:(current application's NSUTF8StringEncoding)

	return jsonString as text
end convertToJSON

-- Helper to convert AppleScript record to NSDictionary recursively
on recordToNSDictionary(rec)
	set dict to current application's NSMutableDictionary's dictionary()

	try
		-- Access properties with new naming
		set classVal to elementClass of rec
		set roleVal to elementRole of rec
		set identifierVal to elementIdentifier of rec
		set titleVal to elementTitle of rec
		set descVal to elementDescription of rec
		set childrenVal to elementChildren of rec

		-- Handle class
		if classVal is not missing value then
			dict's setObject:(classVal as text) forKey:"class"
		else
			dict's setObject:(current application's NSNull's |null|()) forKey:"class"
		end if

		-- Handle role
		if roleVal is not missing value then
			dict's setObject:(roleVal as text) forKey:"role"
		else
			dict's setObject:(current application's NSNull's |null|()) forKey:"role"
		end if

		-- Handle identifier
		if identifierVal is not missing value then
			dict's setObject:(identifierVal as text) forKey:"identifier"
		else
			dict's setObject:(current application's NSNull's |null|()) forKey:"identifier"
		end if

		-- Handle title
		if titleVal is not missing value then
			dict's setObject:(titleVal as text) forKey:"title"
		else
			dict's setObject:(current application's NSNull's |null|()) forKey:"title"
		end if

		-- Handle description
		if descVal is not missing value then
			dict's setObject:(descVal as text) forKey:"description"
		else
			dict's setObject:(current application's NSNull's |null|()) forKey:"description"
		end if

		-- Convert children array
		set childArray to current application's NSMutableArray's array()
		repeat with childRec in childrenVal
			set childDict to my recordToNSDictionary(childRec)
			childArray's addObject:childDict
		end repeat
		dict's setObject:childArray forKey:"children"

	on error errMsg number errNum
		error "Error converting record: " & errMsg & " (Error " & errNum & ")"
	end try

	return dict
end recordToNSDictionary

-- Write text to file
on writeTextToFile(theText, theFile)
	try
		-- Convert the text to NSString and then to data
		set nsString to current application's NSString's stringWithString:theText
		set nsData to nsString's dataUsingEncoding:(current application's NSUTF8StringEncoding)

		-- Convert HFS path to POSIX path
		set posixPath to POSIX path of theFile
		set nsPath to current application's NSString's stringWithString:posixPath

		-- Write to file
		set {writeSuccess, writeError} to nsData's writeToFile:nsPath atomically:true |error|:(reference)

		if not writeSuccess then
			error "Failed to write file: " & (writeError's localizedDescription() as text)
		end if
	on error errMsg
		error "File write error: " & errMsg
	end try
end writeTextToFile
