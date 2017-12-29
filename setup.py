#!/usr/bin/env python

import os
import subprocess
import sys
import tempfile
import urllib

# first check (`xcode-select --version`) and install (`xcode-select --install`)

BREW_INSTALL_SCRIPT = "https://raw.githubusercontent.com/Homebrew/install/master/install"

BREW_FORMULAS = [
    "fish",
    "ag",
]

FNULL = open(os.devnull, 'w')

def _is_cmd_installed(cmd):
    # type: () -> bool
    try:
        path = subprocess.check_output(["which", cmd]).strip()
        return os.path.exists(path) and os.access(path, os.X_OK)
    except subprocess.CalledProcessError as e:
        return False

def _install_or_upgrade_brew_formula(formula):
    # type: (str) -> None
    try:
        print("====> checking status of %s" % formula)
        subprocess.check_call(["brew", "ls", "--versions", formula])
        # if the previous call succeeded, the formula is installed so let's upgrade
        print("====> %s installed, upgrading" % formula)
        try:
            subprocess.check_call(["brew", "upgrade", formula], stderr=FNULL)
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
    # type: (str) -> None
    with tempfile.NamedTemporaryFile() as fw:
        fw.write(script)
        fw.flush()
        subprocess.check_call(["sudo", "bash", "-e", fw.name])

def install_brew_if_needed():
    # type: () -> None
    if _is_cmd_installed("brew"):
        print("====> brew already installed")
    else:
        script_path, _ = urllib.urlretrieve(BREW_INSTALL_SCRIPT)
        subprocess.check_call(["/usr/bin/ruby", script_path])
        print("====> brew was installed installed")

def install_brew_formulas_if_needed():
    # type: () -> None
    for formula in BREW_FORMULAS:
        _install_or_upgrade_brew_formula(formula)

def update_shell_if_needed():
    # type: () -> None
    # first link the new shell
    subprocess.check_call(["brew", "link", "fish"], stderr=FNULL, stdout=FNULL)
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

# Let's first make sure that a few things are installed

install_brew_if_needed()
install_brew_formulas_if_needed()
update_shell_if_needed()

#print("DOG %r" % is_cmd_installed("brew"))
