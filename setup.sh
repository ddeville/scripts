#!/bin/bash

chflags nohidden ~/Library

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
	
	file_origin="${scripts_directory}/dotfiles/${file_name}"
	
	ln -s "${file_origin}" "${file_location}"
	echo "> Linked ${file_origin} to ${file_location}"
}

# Dot files

link_file .profile
link_file .lldbinit
link_file .gitconfig
link_file .vim
link_file .vimrc

echo "=== Dot files copied ==="

# Xcode themes

xcode_themes_location="$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"

mkdir "${xcode_themes_location}" > /dev/null 2>&1
cp "${scripts_directory}/themes/Pastel.dvtcolortheme" "${xcode_themes_location}/Pastel.dvtcolortheme"

echo "=== Xcode themes copied ==="

# BBEdit

bbedit_themes_location="$HOME/Library/Application Support/BBEdit/Color Schemes"

mkdir "${bbedit_themes_location}" > /dev/null 2>&1
cp "${scripts_directory}/themes/Gruber.bbcolors" "${bbedit_themes_location}/Gruber.bbcolors"

echo "=== BBEdit themes copied ==="


