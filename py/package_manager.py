import urllib
import subprocess
import sys

from py.util import (
    is_cmd_installed,
    run_command,
    run_command_no_output,
)

class BasePackageManager(object):
    """A package manager, that can be used to install packages on the current system."""

    def update(self):
        # type: () -> None
        """Update the package manager itself, usually refreshing its package definitions."""
        raise NotImplementedError()

    def install_package(self, package):
        # type: (str) -> None
        """Install or update a given package."""
        raise NotImplementedError()

def create_package_manager():
    # type: () -> BasePackageManager
    """Create a new package manager instance that is appropriate for the current platform."""
    if "darwin" in sys.platform:
        return BrewPackageManager()
    elif "linux" in sys.platform:
        return None
    else:
        raise Exception("Platform not supported %s" % sys.platform)

class BrewPackageManager(BasePackageManager):
    """The brew package manager for use on MacOS."""

    def update(self):
        # type: () -> None
        if is_cmd_installed("brew"):
            print("====> updating brew")
            run_command(["brew", "update"])
        else:
            print("====> installing brew")
            script_path, _ = urllib.urlretrieve("https://raw.githubusercontent.com/Homebrew/install/master/install")
            run_command(["/usr/bin/ruby", script_path])

    def install_package(self, package):
        # type: (str) -> None
        try:
            print("====> checking status of %s" % package)
            run_command(["brew", "ls", "--versions", package])
            # if the previous call succeeded, the package is installed so upgrade
            print("====> %s installed, upgrading" % package)
            try:
                run_command_no_output(["brew", "upgrade", "--display-times", "--cleanup", package])
            except subprocess.CalledProcessError:
                print("====> %s up to date" % package)
        except subprocess.CalledProcessError:
            # the package has never been installed, do that now
            print("====> installing %s" % package)
            try:
                run_command(["brew", "install", "--display-times", package])
            except subprocess.CalledProcessError:
                # brew install succeeds by returning a status code of 1...
                pass
        print("====> %s linking" % package)
        run_command_no_output(["brew", "link", package])


class AptPackageManager(BasePackageManager):
    """The APT package manager to use on Debian and derivatives."""

    def update(self):
        # type: () -> None
        print("====> updating APT package manager")
        run_command(["sudo", "apt-get", "update", "--fix-missing"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "apt-get", "upgrade", package])
