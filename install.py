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

MACOS = "macos"
LINUX = "linux"
ALL_PLATFORMS = (MACOS, LINUX)

PACKAGES = [
    "fish",
    "tmux",
    "irssi",
    "jq",
    "radare2",
]

PACKAGES_MACOS = [
    "the_silver_searcher",
]

PACKAGES_LINUX = [
    "silversearcher-ag",
    "ttf-anonymous-pro",
    "vim",
]

# Commands

def setup_cmd_install_brew_if_needed():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        if _is_cmd_installed("brew"):
            print("====> brew already installed")
        else:
            script_path, _ = urllib.urlretrieve("https://raw.githubusercontent.com/Homebrew/install/master/install")
            subprocess.check_call(["/usr/bin/ruby", script_path])

    return Manifest(cmd=cmd, priority=0, platform=MACOS)

def setup_cmd_update_apt_get_if_needed():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        print("====> updating package manager")
        subprocess.check_call(["sudo", "apt-get", "update", "--fix-missing"])

    return Manifest(cmd=cmd, priority=0, platform=LINUX)

def setup_cmd_install_brew_formulas_if_needed():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        for package in PACKAGES + PACKAGES_MACOS:
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
    
    return Manifest(cmd=cmd, priority=8, platform=MACOS)

def setup_cmd_install_linux_packages_if_needed():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        for package in PACKAGES + PACKAGES_LINUX:
            print("====> installing %s" % package)
            subprocess.check_call(["sudo", "apt-get", "upgrade", package])

    return Manifest(cmd=cmd, priority=8, platform=LINUX)

def setup_cmd_update_shell_macos_if_needed():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
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
    
    return Manifest(cmd=cmd, priority=16, platform=MACOS)

def setup_cmd_update_shell_linux_if_needed():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        if os.environ.get("SHELL") != "/usr/bin/fish":
            print("====> changing shell to fish")
            subprocess.check_call(["chsh", "-s", "/usr/bin/fish"])
        else:
            print("====> fish is already default shell")

    return Manifest(cmd=cmd, priority=16, platform=LINUX)

def setup_cmd_update_dot_files():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        orig_dir = os.path.join(SCRIPTS_PATH, "config")
        dest_dir = os.path.expanduser("~")

        links = [
            ("hushlogin", ".hushlogin"),
            ("bash_profile", ".bash_profile"),
            ("bashrc", ".bashrc"),
            ("lldbinit", ".lldbinit"),
            ("gitconfig", ".gitconfig"),
            ("profile", ".profile"),
            ("vim", ".vim"),
            ("vimrc", ".vimrc"),
            ("tmux.conf", ".tmux.conf"),
            (os.path.join("fish", "config.fish"), os.path.join(".config", "fish", "config.fish")),
            (os.path.join("fish", "functions"), os.path.join(".config", "fish", "functions")),
        ]

        # make sure that we create the `.config/fish` directory since it won't be here on new machines
        _create_dirs_if_needed(os.path.join(dest_dir, ".config", "fish"))

        print("====> linking dot files")
        for f1, f2 in links:
            _force_symlink(os.path.join(orig_dir, f1), os.path.join(dest_dir, f2))
        
    return Manifest(cmd=cmd, priority=32, platform=ALL_PLATFORMS)

def setup_cmd_update_vim_plugins():
    # type: () -> Manifest
    def cmd():
        print("====> updating vim plugins")
        # update vim-plug itself
        subprocess.check_call(["vim", "+PlugUpgrade", "+qall"])
        # install or update all plugins
        subprocess.check_call(["vim", "+PlugUpdate", "+qall"])

    return Manifest(cmd=cmd, priority=33, platform=ALL_PLATFORMS)

def setup_cmd_install_pyenv():
    # type: () -> Manifest
    def cmd():
        if _is_cmd_installed("pyenv"):
            print("====> updating pyenv")
            _run_command_no_output(["pyenv", "update"])
        else:
            print("====> installing pyenv")
            script_path, _ = urllib.urlretrieve("https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer")
            subprocess.check_call(["bash", script_path])

    return Manifest(cmd=cmd, priority=34, platform=ALL_PLATFORMS)

def setup_cmd_install_rustup():
    # type: () -> Manifest
    def cmd():
        if _is_cmd_installed("rustup"):
            print("====> updating rustup")
            _run_command_no_output(["rustup", "update"])
        else:
            print("====> install rustup")
            script_path, _ = urllib.urlretrieve("https://sh.rustup.rs")
            subprocess.check_call(["sh", script_path])
        pass

    return Manifest(cmd=cmd, priority=35, platform=ALL_PLATFORMS)

def setup_cmd_update_library_visibility():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        print("====> updating ~/Library visibility")
        nohidden_flag = 1 << 15
        library_path = os.path.expanduser("~/Library")
        library_stat = os.stat(library_path)
        os.chflags(library_path, library_stat.st_flags & ~nohidden_flag)

    return Manifest(cmd=cmd, priority=36, platform=MACOS)

def setup_cmd_update_system_preferences():
    # type: () -> Manifest
    def update_global_domain(key, val):
        # type: (str, str) -> None
        _run_command_no_output(["defaults", "write", "NSGlobalDomain", key, val])

    def cmd():
        # type: () -> None
        print("====> updating system preferences")
        update_global_domain("NSShowAppCentricOpenPanelInsteadOfUntitledFile", "0")
        update_global_domain("NSQuitAlwaysKeepsWindows", "1")
        update_global_domain("NSAutomaticSpellingCorrectionEnabled", "0")
        update_global_domain("NSAutomaticCapitalizationEnabled", "0")
        update_global_domain("NSAutomaticDashSubstitutionEnabled", "0")
        update_global_domain("NSAutomaticPeriodSubstitutionEnabled", "0")
        update_global_domain("NSAutomaticQuoteSubstitutionEnabled", "0")
        update_global_domain("NSAutomaticTextCompletionEnabled", "0")
        update_global_domain("KeyRepeat", "1")
        update_global_domain("InitialKeyRepeat", "12")
        update_global_domain("ApplePressAndHoldEnabled", "0")

        print("====> updating login window preferences")
        _run_command_no_output(["defaults", "write", "com.apple.loginwindow", "TALLogoutSavesState", "1"])

    return Manifest(cmd=cmd, priority=37, platform=MACOS)

def setup_cmd_update_iterm_sync_folder_prefs():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        print("====> updating iterm preferences")
        _run_command_no_output(["defaults", "write", "com.googlecode.iterm2", "PrefsCustomFolder",
                                os.path.join(SCRIPTS_PATH, "macos", "iterm")])

    return Manifest(cmd=cmd, priority=38, platform=MACOS)

def setup_cmd_install_fonts():
    # type: () -> Manifest
    def cmd():
        print("====> installing fonts")
        fonts_path = os.path.join(SCRIPTS_PATH, "fonts")
        dest_path = os.path.join(os.path.expanduser("~"), "Library", "Fonts")
        _create_dirs_if_needed(dest_path)
        for folder in os.listdir(fonts_path):
            font_path = os.path.join(fonts_path, folder)
            if os.path.isdir(font_path) and not folder.startswith("."):
                _copy_file_if_needed(font_path, os.path.join(dest_path, folder), True)

    return Manifest(cmd=cmd, priority=39, platform=MACOS)

def setup_cmd_install_xcode_themes():
    # type: () -> Manifest
    def cmd():
        # type: () -> None
        print("====> installing xcode themes")
        themes_path = os.path.join(SCRIPTS_PATH, "macos", "xcode")
        dest_path = os.path.join(os.path.expanduser("~"), "Library", "Developer", "Xcode", "UserData",
                                 "FontAndColorThemes")
        _create_dirs_if_needed(dest_path)
        for theme in os.listdir(themes_path):
            theme_path = os.path.join(themes_path, theme)
            if not theme.startswith("."):
                _copy_file_if_needed(theme_path, os.path.join(dest_path, theme))

    return Manifest(cmd=cmd, priority=40, platform=MACOS)

# Private helpers

def _is_cmd_installed(cmd):
    # type: (str) -> bool
    try:
        path = subprocess.check_output(["which", cmd]).strip()
        return os.path.exists(path) and os.access(path, os.X_OK)
    except subprocess.CalledProcessError as e:
        return False

def _run_script_as_root(script):
    # type: (str) -> None
    with tempfile.NamedTemporaryFile() as fw:
        fw.write(script)
        fw.flush()
        subprocess.check_call(["sudo", "bash", "-e", fw.name])

def _run_command_no_output(cmd):
    # type: (str) -> None
    with open(os.devnull, "w") as f:
        subprocess.check_call(cmd, stderr=f, stdout=f)

def _force_symlink(path1, path2):
    # type: (str, str) -> None
    try:
        os.symlink(path1, path2)
    except OSError as e:
        if e.errno == errno.EEXIST:
            os.remove(path2)
            os.symlink(path1, path2)
        else:
            raise

def _create_dirs_if_needed(path):
    # type: (str) -> None
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def _copy_file_if_needed(orig, dest, isdir=False):
    # type: (str, str, bool) -> None
    try:
        if isdir:
            shutil.copytree(orig, dest)
        else:
            shutil.copyfile(orig, dest)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def _get_current_platform():
    # type: () -> str
    if "darwin" in sys.platform:
        return MACOS
    elif "linux" in sys.platform:
        return LINUX
    else:
        raise Exception("Platform not supported %s" % sys.platform)

# main

class Manifest(object):
    def __init__(self, cmd, priority, platform):
        self.cmd = cmd
        self.priority = priority
        self.platform = platform

def _run_all_commands():
    # type: () -> None
    plat = _get_current_platform()

    manifests = [func() for name, func in 
            inspect.getmembers(sys.modules[__name__], inspect.isfunction)
            if name.startswith("setup_cmd")]
    manifests = sorted([manifest for manifest in manifests if plat in manifest.platform],
            key=lambda manifest: manifest.priority)
    
    for manifest in manifests:
        func = manifest.cmd
        func()

if __name__ == "__main__":
    _run_all_commands()
