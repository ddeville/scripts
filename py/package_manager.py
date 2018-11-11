import urllib
import subprocess

from py.util import (
    FREEBSD,
    LINUX,
    MACOS,
    get_current_platform,
    get_linux_distro_info,
    is_cmd_installed,
    run_command,
    run_command_no_output,
)

def create_package_manager():
    # type: () -> BasePackageManager
    """Create a new package manager instance that is appropriate for the current platform."""
    plat = get_current_platform()

    if plat == MACOS:
        return BrewPackageManager()
    elif plat == LINUX:
        distro_info = get_linux_distro_info()
        distros = [distro_info.get("ID"), distro_info.get("ID_LIKE")]
        if "debian" in distros or is_cmd_installed("apt-get"):
            return AptPackageManager()
        elif "fedora" in distros or is_cmd_installed("dnf"):
            return DnfPackageManager()
        elif "centos" in distros or is_cmd_installed("yum"):
            return YumPackageManager()
    elif plat == FREEBSD:
        return PkgPackageManager()

    raise Exception("Platform not supported %s" % plat)

class BasePackageManager(object):
    """A package manager, that can be used to install packages on the current system."""

    def install(self):
        # type: () -> None
        """Install or update the package manager itself (if needed)."""
        raise NotImplementedError()

    def install_package(self, package):
        # type: (str) -> None
        """Install or update a given package."""
        raise NotImplementedError()

class BrewPackageManager(BasePackageManager):
    """The brew package manager for use on MacOS."""

    def install(self):
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
                run_command_no_output(["brew", "upgrade", "--cleanup", package])
            except subprocess.CalledProcessError:
                print("====> %s up to date" % package)
        except subprocess.CalledProcessError:
            # the package has never been installed, do that now
            print("====> installing %s" % package)
            try:
                run_command(["brew", "install", package])
            except subprocess.CalledProcessError:
                # brew install succeeds by returning a status code of 1...
                pass
        print("====> %s linking" % package)
        run_command_no_output(["brew", "link", package])


class AptPackageManager(BasePackageManager):
    """The APT package manager to use on Debian and derivatives."""

    def install(self):
        # type: () -> None
        pass

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "apt-get", "upgrade", package])

class DnfPackageManager(BasePackageManager):
    """The DNS package manager to use on Fedora and derivatives."""

    def install(self):
        # type: () -> None
        pass

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "dnf", "install", "--best", package])

class YumPackageManager(BasePackageManager):
    """The YUM package manager to use on CentOS."""

    def install(self):
        # type: () -> None
        pass

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)

class PkgPackageManager(BasePackageManager):
    """The PKG package manager to use on FreeBSD."""

    def install(self):
        # type: () -> None
        pass

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
