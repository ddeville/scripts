set need_reply_mailbox_name to "Needs Reply"
set need_reply_account_name to "FastMail"
set omnifocus_email_folder_name to "Email"
set omnifocus_needsreply_project_name to "Needs Reply"

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
	set needs_reply_mailbox to mailbox need_reply_mailbox_name of account need_reply_account_name
	set selected_messages to selection
	
	repeat with selected_message in selected_messages
		if mailbox of selected_message is not needs_reply_mailbox then
			move selected_message to needs_reply_mailbox
			
			set task_title to the subject of selected_message
			set task_content to the content of selected_message
			set task_body to "message://%3c" & message id of selected_message & "%3e" & return & return & task_content
			
			tell application "OmniFocus"
				tell default document
					set email_folder to folder named omnifocus_email_folder_name
					tell email_folder
						set needsreply_project to (first project whose name is omnifocus_needsreply_project_name)
						tell needsreply_project
							make new task with properties {name:task_title, note:task_body}
						end tell
					end tell
				end tell
			end tell
		end if
	end repeat
end tell