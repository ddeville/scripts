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
		else
			echo "> Skipped ${file_origin}"
			return
		fi
	fi

	ln -s "${file_origin}" "${file_destination}"
	echo "> Linked ${file_origin} to ${file_destination}"
}

# Library hidden

chflags nohidden ~/Library

echo "=== ~/Library is now visible ==="

# Defaults

defaults write NSGlobalDomain NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false

echo "=== Global defaults updated ==="

# Dropbox API python package install

git submodule init
git submodule update

current_dir=`pwd`
cd externals/dropbox-sdk-python
python setup.py install
git checkout .
git clean -df
git checkout master

cd "${current_dir}"

echo "=== Dropbox API python package installed ==="

# Dot files

dot_origin_folder="${scripts_directory}/dotfiles"
dot_destination_folder="${HOME}"

mkdir "${dot_destination_folder}/.vim/colors" > /dev/null 2>&1

link_file "${dot_origin_folder}/.hushlogin" "${dot_destination_folder}/.hushlogin"
link_file "${dot_origin_folder}/.bash_profile" "${dot_destination_folder}/.bash_profile"
link_file "${dot_origin_folder}/.bashrc" "${dot_destination_folder}/.bashrc"
link_file "${dot_origin_folder}/.lldbinit" "${dot_destination_folder}/.lldbinit"
link_file "${dot_origin_folder}/.gitconfig" "${dot_destination_folder}/.gitconfig"
link_file "${dot_origin_folder}/.vim/colors/railscasts.vim" "${dot_destination_folder}/.vim/colors/railscasts.vim"
link_file "${dot_origin_folder}/.vimrc" "${dot_destination_folder}/.vimrc"
link_file "${dot_origin_folder}/.git-remote-dropbox.json" "${dot_destination_folder}/.git-remote-dropbox.json"
link_file "${dot_origin_folder}/.save-tabs-dropbox.json" "${dot_destination_folder}/.save-tabs-dropbox.json"

echo "=== Dot files linked ==="

# Fish shell

fish_origin_folder="${scripts_directory}/fish"
fish_destination_folder="${HOME}/.config/fish"

mkdir "${fish_destination_folder}" > /dev/null 2>&1

link_file "${fish_origin_folder}/config.fish" "${fish_destination_folder}/config.fish"
link_file "${fish_origin_folder}/functions" "${fish_destination_folder}/functions"

echo "=== Fish files linked ==="

# Themes

themes_origin_folder="${scripts_directory}/themes"

xcode_themes_location="$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"
mkdir "${xcode_themes_location}" > /dev/null 2>&1

link_file "${themes_origin_folder}/Pastel.dvtcolortheme" "${xcode_themes_location}/Pastel.dvtcolortheme"

bbedit_themes_location="$HOME/Library/Application Support/BBEdit/Color Schemes"
mkdir "${bbedit_themes_location}" > /dev/null 2>&1

link_file "${themes_origin_folder}/Gruber.bbcolors" "${bbedit_themes_location}/Gruber.bbcolors"

sublime_text_settings_location="$HOME/Library/Application Support/Sublime Text 3/Packages"
mkdir "${sublime_text_settings_location}" > /dev/null 2>&1

link_file "${themes_origin_folder}/Preferences.sublime-settings" "${sublime_text_settings_location}/User/Preferences.sublime-settings"

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
