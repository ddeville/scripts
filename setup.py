#!/usr/bin/env python

import errno
import inspect
import os
import shutil
import subprocess
import sys
import tempfile
import urllib

SCRIPTS_PATH = os.path.dirname(os.path.realpath(__file__))

COMMAND = "command"
PRIORITY = "priority"
PLATFORM = "platform"

MACOS = "macos"
LINUX = "linux"
ALL_PLATFORMS = (MACOS, LINUX)

# Commands

def setup_cmd_install_brew_if_needed():
    def cmd():
        if _is_cmd_installed("brew"):
            print("====> brew already installed")
        else:
            script_path, _ = urllib.urlretrieve("https://raw.githubusercontent.com/Homebrew/install/master/install")
            subprocess.check_call(["/usr/bin/ruby", script_path])

    return {
        COMMAND: cmd,
        PRIORITY: 0,
        PLATFORM: MACOS,
    }

def setup_cmd_update_apt_get_if_needed():
    def cmd():
        print("====> updating package manager")
        subprocess.check_call(["sudo", "apt-add-repository", "ppa:fish-shell/release-2"])
        subprocess.check_call(["sudo", "apt-get", "update", "--fix-missing"])

    return {
        COMMAND: cmd,
        PRIORITY: 0,
        PLATFORM: LINUX,
    }

PACKAGES_MACOS = [
    "fish",
    "the_silver_searcher",
    "tmux",
]

def setup_cmd_install_brew_formulas_if_needed():
    def cmd():
        for package in PACKAGES_MACOS:
            print("====> installing %s" % package)
            try:
                print("====> checking status of %s" % package)
                subprocess.check_call(["brew", "ls", "--versions", package])
                # if the previous call succeeded, the package is installed so upgrade
                print("====> %s installed, upgrading" % package)
                try:
                    _run_command_no_output(["brew", "upgrade", package])
                except subprocess.CalledProcessError:
                    print("====> %s up to date" % package)
            except subprocess.CalledProcessError:
                # the package has never been installed, do that now
                print("====> installing %s" % package)
                try:
                    subprocess.check_call(["brew", "install", package])
                except subprocess.CalledProcessError:
                    # brew install succeeds by returning a status code of 1...
                    pass
            print("====> %s linking" % package)
            _run_command_no_output(["brew", "link", package])
    
    return {
        COMMAND: cmd,
        PRIORITY: 8,
        PLATFORM: MACOS,
    }

PACKAGES_LINUX = [
    "fish",
    "silversearcher-ag",
    "tmux",
    "vim",
]

def setup_cmd_install_linux_packages_if_needed():
    def cmd():
        for package in PACKAGES_LINUX:
            print("====> installing %s" % package)
            subprocess.check_call(["sudo", "apt-get", "upgrade", package])

    return {
        COMMAND: cmd,
        PRIORITY: 8,
        PLATFORM: LINUX,
    }

def setup_cmd_update_shell_macos_if_needed():
    def cmd():
        # let's check whether fish was added to /etc/shells
        with open("/etc/shells") as f:
            if not "/usr/local/bin/fish" in f.read():
                # we need to add fish to /etc/shells
                print("====> adding fish to /etc/shells")
                script = "#!/bin/bash\necho \"/usr/local/bin/fish\" >> /etc/shells"
                _run_script_as_root(script)
            else:
                print("====> fish already in /etc/shells")
    
        # next let's check whether we need to change the shell
        if os.environ.get("SHELL") != "/usr/local/bin/fish":
            print("====> changing shell to fish")
            subprocess.check_call(["chsh", "-s", "/usr/local/bin/fish"])
        else:
            print("====> fish is already default shell")
    
    return {
        COMMAND: cmd,
        PRIORITY: 16,
        PLATFORM: MACOS,
    }

def setup_cmd_update_shell_linux_if_needed():
    def cmd():
        if os.environ.get("SHELL") != "/usr/bin/fish":
            print("====> changing shell to fish")
            subprocess.check_call(["chsh", "-s", "/usr/bin/fish"])
        else:
            print("====> fish is already default shell")

    return {
        COMMAND: cmd,
        PRIORITY: 16,
        PLATFORM: LINUX,
    }

def setup_cmd_update_dot_files():
    def cmd():
        # regular dot files
        orig_dir = os.path.join(SCRIPTS_PATH, "dotfiles")
        dest_dir = os.path.expanduser("~")

        links = [
            ("hushlogin", ".hushlogin"),
            ("bash_profile", ".bash_profile"),
            ("bashrc", ".bashrc"),
            ("lldbinit", ".lldbinit"),
            ("gitconfig", ".gitconfig"),
            ("vim", ".vim"),
            ("vimrc", ".vimrc"),
        ]

        print("====> linking dot files")
        for f1, f2 in links:
            _force_symlink(os.path.join(orig_dir, f1), os.path.join(dest_dir, f2))
        
        # fish
        orig_dir = os.path.join(SCRIPTS_PATH, "fish")
        dest_dir = os.path.join(os.path.expanduser("~"), ".config", "fish")
        
        links = [
            ("config.fish", "config.fish"),
            ("functions", "functions"),
        ]

        print("====> linking fish config files")
        _create_dirs_if_needed(dest_dir)
        for f1, f2 in links:
            _force_symlink(os.path.join(orig_dir, f1), os.path.join(dest_dir, f2))

    return {
        COMMAND: cmd,
        PRIORITY: 32,
        PLATFORM: ALL_PLATFORMS,
    }

def setup_cmd_update_library_visibility():
    def cmd():
        print("====> updating ~/Library visibility")
        nohidden_flag = 1 << 15
        library_path = os.path.expanduser("~/Library")
        library_stat = os.stat(library_path)
        os.chflags(library_path, library_stat.st_flags & ~nohidden_flag)
   
    return {
        COMMAND: cmd,
        PRIORITY: 33,
        PLATFORM: MACOS,
    }

def setup_cmd_update_system_preferences():
    def cmd():
        print("====> updating system preferences")
        _run_command_no_output(["defaults", "write", "NSGlobalDomain",
                                "NSShowAppCentricOpenPanelInsteadOfUntitledFile", "false"])
        _run_command_no_output(["defaults", "write", "NSGlobalDomain",
                                "NSQuitAlwaysKeepsWindows", "true"])
        _run_command_no_output(["defaults", "write", "NSGlobalDomain",
                                "NSAutomaticSpellingCorrectionEnabled", "false"])
        _run_command_no_output(["defaults", "write", "NSGlobalDomain",
                                "KeyRepeat", "1"])
        _run_command_no_output(["defaults", "write", "NSGlobalDomain",
                                "InitialKeyRepeat", "15"])
        _run_command_no_output(["defaults", "write", "NSGlobalDomain",
                                "ApplePressAndHoldEnabled", "false"])
    
    return {
        COMMAND: cmd,
        PRIORITY: 34,
        PLATFORM: MACOS,
    }

def setup_cmd_update_iterm_sync_folder_prefs():
    def cmd():
        print("====> updating iterm preferences")
        _run_command_no_output(["defaults", "write", "com.googlecode.iterm2", "PrefsCustomFolder",
                                os.path.join(SCRIPTS_PATH, "macos", "iterm")])

    return {
        COMMAND: cmd,
        PRIORITY: 35,
        PLATFORM: MACOS,
    }

def setup_cmd_install_fonts():
    def cmd():
        print("====> installing fonts")
        fonts_path = os.path.join(SCRIPTS_PATH, "fonts")
        dest_path = os.path.join(os.path.expanduser("~"), "Library", "Fonts")
        _create_dirs_if_needed(dest_path)
        for folder in os.listdir(fonts_path):
            font_path = os.path.join(fonts_path, folder)
            if os.path.isdir(font_path) and not folder.startswith("."):
                _copy_file_if_needed(font_path, os.path.join(dest_path, folder), True)

    return {
        COMMAND: cmd,
        PRIORITY: 36,
        PLATFORM: MACOS,
    }

def setup_cmd_install_xcode_themes():
    def cmd():
        print("====> installing xcode themes")
        themes_path = os.path.join(SCRIPTS_PATH, "macos", "xcode")
        dest_path = os.path.join(os.path.expanduser("~"), "Library", "Developer", "Xcode", "UserData",
                                 "FontAndColorThemes")
        _create_dirs_if_needed(dest_path)
        for theme in os.listdir(themes_path):
            theme_path = os.path.join(themes_path, theme)
            if not theme.startswith("."):
                _copy_file_if_needed(theme_path, os.path.join(dest_path, theme))

    return {
        COMMAND: cmd,
        PRIORITY: 37,
        PLATFORM: MACOS,
    }

# Private helpers

def _is_cmd_installed(cmd):
    try:
        path = subprocess.check_output(["which", cmd]).strip()
        return os.path.exists(path) and os.access(path, os.X_OK)
    except subprocess.CalledProcessError as e:
        return False

def _run_script_as_root(script):
    with tempfile.NamedTemporaryFile() as fw:
        fw.write(script)
        fw.flush()
        subprocess.check_call(["sudo", "bash", "-e", fw.name])

def _run_command_no_output(cmd):
    with open(os.devnull, "w") as f:
        subprocess.check_call(cmd, stderr=f, stdout=f)

def _force_symlink(path1, path2):
    try:
        os.symlink(path1, path2)
    except OSError as e:
        if e.errno == errno.EEXIST:
            os.remove(path2)
            os.symlink(path1, path2)
        else:
            raise

def _create_dirs_if_needed(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def _copy_file_if_needed(orig, dest, isdir=False):
    try:
        if isdir:
            shutil.copytree(orig, dest)
        else:
            shutil.copyfile(orig, dest)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def _get_current_platform():
    if "darwin" in sys.platform:
        return MACOS
    elif "linux" in sys.platform:
        return LINUX
    else:
        return None

# main

def _run_all_commands():
    plat = _get_current_platform()

    manifests = [func() for name, func in 
            inspect.getmembers(sys.modules[__name__], inspect.isfunction)
            if name.startswith("setup_cmd")]
    manifests = sorted([manifest for manifest in manifests if plat in manifest[PLATFORM]],
                       key=lambda item: item[PRIORITY])
    
    for manifest in manifests:
        func = manifest[COMMAND]
        func()

if __name__ == "__main__":
    _run_all_commands()
