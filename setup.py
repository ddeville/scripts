#!/usr/bin/env python

import errno
import os
import subprocess
import sys
import tempfile
import urllib

# Commands

def cmd_update_library_visibility():
    nohidden_flag = 1 << 15
    library_path = os.path.expanduser("~/Library")
    library_stat = os.stat(library_path)
    os.chflags(library_path, library_stat.st_flags & ~nohidden_flag)
    print("====> updated ~/Library visibility")

def cmd_update_open_panel_behavior():
    _run_command_no_output(["defaults", "write", "NSGlobalDomain",
        "NSShowAppCentricOpenPanelInsteadOfUntitledFile", "-bool", "false"])
    print("====> updated open panel behavior")

def cmd_install_brew_if_needed():
    url = "https://raw.githubusercontent.com/Homebrew/install/master/install"
    if _is_cmd_installed("brew"):
        print("====> brew already installed")
    else:
        script_path, _ = urllib.urlretrieve(url)
        subprocess.check_call(["/usr/bin/ruby", script_path])
        print("====> brew was installed installed")

def cmd_install_brew_formulas_if_needed():
    brew_formulas = [
       "fish",
        "ag",
    ]
    for formula in brew_formulas:
        print("====> installing %s" % formula)
        _install_or_upgrade_brew_formula(formula)

def cmd_update_shell_if_needed():
    # first link the new shell
    _run_command_no_output(["brew", "link", "fish"])
    # next let's check whether fish was added to /etc/shells
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
        print("====> chaning shell to fish")
        subprocess.check_call(["chsh", "-s", "/usr/local/bin/fish"])
    else:
        print("====> fish is already default shell")

def cmd_update_dot_files():
    scripts_path = os.path.dirname(os.path.realpath(__file__))
    
    # regular dot files
    orig_dir = os.path.join(scripts_path, "dotfiles")
    dest_dir = os.path.expanduser("~")

    links = [
        (".hushlogin", ".hushlogin"),
        (".bash_profile", ".bash_profile"),
        (".bashrc", ".bashrc"),
        (".lldbinit", ".lldbinit"),
        (".gitconfig", ".gitconfig"),
        (".vim", ".vim"),
        (".vimrc", ".vimrc"),
    ]

    print("====> linking dot files")
    for f1, f2 in links:
        _force_symlink(os.path.join(orig_dir, f1), os.path.join(dest_dir, f2))
    print("====> linked dot files")
    
    # fish
    orig_dir = os.path.join(scripts_path, "fish")
    dest_dir = os.path.join(os.path.expanduser("~"), ".config", "fish")
    
    links = [
        ("config.fish", "config.fish"),
        ("functions", "functions"),
    ]

    print("====> linking fish config files")
    _create_dirs_if_needed(dest_dir)
    for f1, f2 in links:
        _force_symlink(os.path.join(orig_dir, f1), os.path.join(dest_dir, f2))
    print("====> linked fish config files")

# Private helpers

def _is_cmd_installed(cmd):
    try:
        path = subprocess.check_output(["which", cmd]).strip()
        return os.path.exists(path) and os.access(path, os.X_OK)
    except subprocess.CalledProcessError as e:
        return False

def _install_or_upgrade_brew_formula(formula):
    try:
        print("====> checking status of %s" % formula)
        subprocess.check_call(["brew", "ls", "--versions", formula])
        # if the previous call succeeded, the formula is installed so upgrade
        print("====> %s installed, upgrading" % formula)
        try:
            _run_command_no_output(["brew", "upgrade", formula])
        except subprocess.CalledProcessError:
            print("====> %s up to date" % formula)
    except subprocess.CalledProcessError:
        # the formula has never been installed, do that now
        print("====> installing %s" % formula)
        try:
            subprocess.check_call(["brew", "install", formula])
        except subprocess.CalledProcessError:
            # brew install succeeds by returning a status code of 1...
            pass
        print("====> %s installed" % formula)

def _run_script_as_root(script):
    with tempfile.NamedTemporaryFile() as fw:
        fw.write(script)
        fw.flush()
        subprocess.check_call(["sudo", "bash", "-e", fw.name])

def _run_command_no_output(cmd):
    with open(os.devnull, 'w') as f:
        subprocess.check_call(cmd, stderr=f, stdout=f)

def _force_symlink(path1, path2):
    try:
        os.symlink(path1, path2)
    except OSError as e:
        if e.errno == errno.EEXIST:
            os.remove(path2)
            os.symlink(path1, path2)

def _create_dirs_if_needed(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno == errno.EEXIST:
            pass

# main

CMDS = [
    cmd_update_library_visibility,
    cmd_update_open_panel_behavior,
    cmd_install_brew_if_needed,
    cmd_install_brew_formulas_if_needed,
    cmd_update_shell_if_needed,
    cmd_update_dot_files,
]

if __name__ == '__main__':
    [cmd() for cmd in CMDS]
