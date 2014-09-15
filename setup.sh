#!/usr/bin/env bash

scripts_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function link_file
{
	file_name="${1%/}"
	
	if [ -z "${file_name}" ]
	then
		echo -e "> Need to specify a file name"
		return
	fi
	
	file_location="${HOME}/${file_name}"
	
	if [ -e "${file_location}" ];
	then
		while [ 1 ]
		do
			read -r -p "> ${file_location} already exists, overwrite? [y/n]: "
			if [ "${REPLY}" != "y" -a "${REPLY}" != "n" ]
			then
				echo "> Unknown option ${REPLY}; try again" >&2
				continue
			fi
			
			break
		done
		
		if [ "${REPLY}" = "y" ]
		then
			rm -rf "${file_location}"
			echo "> Removed ${file_location}"
		fi
	fi
	
	file_origin="${scripts_directory}/${file_name}"
	
	ln -s "${file_origin}" "${file_location}"
	echo "> Linked ${file_origin} to ${file_location}"
}

link_file .profile
link_file .lldbinit
link_file .gitconfig
link_file .vim
link_file .vimrc
