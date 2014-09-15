#!/bin/bash

scripts_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function link_file
{
	file_origin="${1%/}"
	file_destination="${2%/}"
	
	if [ -z "${file_origin}" ]
	then
		echo -e "> Need to specify a file origin"
		return
	fi
	
	if [ -z "${file_destination}" ]
	then
		echo -e "> Need to specify a file destination"
		return
	fi
	
	if [ -e "${file_destination}" ];
	then
		while [ 1 ]
		do
			read -r -p "> ${file_destination} already exists, overwrite? [y/n]: "
			if [ "${REPLY}" != "y" -a "${REPLY}" != "n" ]
			then
				echo "> Unknown option ${REPLY}; try again" >&2
				continue
			fi
			
			break
		done
		
		if [ "${REPLY}" = "y" ]
		then
			rm -rf "${file_destination}"
			echo "> Removed ${file_destination}"
		fi
	fi
	
	ln -s "${file_origin}" "${file_destination}"
	echo "> Linked ${file_origin} to ${file_destination}"
}

# Library hidden

chflags nohidden ~/Library

echo "=== ~/Library is now visible ==="

# Dot files

dot_origin_folder="${scripts_directory}/dotfiles"
dot_destination_folder="${HOME}"

link_file "${dot_origin_folder}/.profile" "${dot_destination_folder}/.profile"
link_file "${dot_origin_folder}/.lldbinit" "${dot_destination_folder}/.lldbinit"
link_file "${dot_origin_folder}/.gitconfig" "${dot_destination_folder}/.gitconfig"
link_file "${dot_origin_folder}/.vim" "${dot_destination_folder}/.vim"
link_file "${dot_origin_folder}/.vimrc" "${dot_destination_folder}/.vimrc"

echo "=== Dot files linked ==="

# Themes

themes_origin_folder="${scripts_directory}/themes"

xcode_themes_location="$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"
mkdir "${xcode_themes_location}" > /dev/null 2>&1

link_file "${themes_origin_folder}/Pastel.dvtcolortheme" "${xcode_themes_location}/Pastel.dvtcolortheme"

bbedit_themes_location="$HOME/Library/Application Support/BBEdit/Color Schemes"
mkdir "${bbedit_themes_location}" > /dev/null 2>&1

link_file "${themes_origin_folder}/Gruber.bbcolors" "${bbedit_themes_location}/Gruber.bbcolors"

echo "=== Themes linked ==="

# Services

services_origin_folder="${scripts_directory}/services"
services_destination_folder="$HOME/Library/Services"

mkdir "${services_destination_folder}" > /dev/null 2>&1

for wf in ${services_origin_folder}/*.{workflow,service};
do
	filename=$(basename "${wf}")
	if [ "${filename}" != "*workflow" -a "${filename}" != "*.service" ]
	then
		cp -r "${wf}" "${services_destination_folder}/$filename"
	fi
done

echo "=== Services copied ==="
