set omnifocus_email_folder_name to "Email"
set omnifocus_support_project_name to "Support"

set omnifocus_running to false

tell application "System Events"
	if exists process "OmniFocus" then
		set omnifocus_running to true
	end if
end tell

if omnifocus_running is false then
	tell application "OmniFocus" to activate
end if

tell application "Mail"
	set selected_messages to selection
	
	repeat with selected_message in selected_messages
		set task_title to the subject of selected_message
		set task_content to the content of selected_message
		set task_body to "message://%3c" & message id of selected_message & "%3e" & return & return & task_content
		
		tell application "OmniFocus"
			tell default document
				set email_folder to folder named omnifocus_email_folder_name
				tell email_folder
					set support_project to (first project whose name is omnifocus_support_project_name)
					tell support_project
						make new task with properties {name:task_title, note:task_body}
					end tell
				end tell
			end tell
		end tell
	end repeat
end tell