import subprocess

from py.platform import (
    FREEBSD,
    LINUX,
    MACOS,
    get_current_platform,
    is_linux_distro,
)
from py.typing import *
from py.util import (
    command_path,
    download_file,
    is_cmd_installed,
    run_command,
    run_command_no_output,
)

class PackageName(object):
    def __init__(self, name):
        # type: (str) -> None
        self.name = name

class PackageType(object):
    """An "enum" of package types."""
    DEB = PackageName("deb")
    RPM = PackageName("rpm")
    BREW = PackageName("brew")
    PACMAN = PackageName("pacman")
    PKG = PackageName("pkg")

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

    @property
    def package_type(self):
        # type: () -> PackageName
        """The package type."""
        raise NotImplementedError()

    def install_packages(self, packages):
        # type: (List[Union[str, Dict[PackageName, str]]]) -> None
        for package in _filter_packages(packages, self.package_type):
            self.install_package(package)

def create_package_manager():
    # type: () -> BasePackageManager
    """Create a new package manager instance that is appropriate for the current platform."""
    plat = get_current_platform()

    if plat == MACOS:
        return BrewPackageManager()
    elif plat == LINUX:
        if is_linux_distro("debian") or is_cmd_installed("apt-get"):
            return AptPackageManager()
        elif is_linux_distro("fedora") or is_cmd_installed("dnf"):
            return DnfPackageManager()
        elif is_linux_distro("arch") or is_cmd_installed("pacman"):
            return PacmanPackageManager()
    elif plat == FREEBSD:
        return PkgPackageManager()

    raise Exception("Platform not supported %s" % plat)

class BrewPackageManager(BasePackageManager):
    """The brew package manager for use on MacOS."""

    def install(self):
        # type: () -> None
        if is_cmd_installed("brew"):
            print("====> updating brew")
            run_command(["brew", "update"])
        else:
            print("====> installing brew")
            script_path = download_file("https://raw.githubusercontent.com/Homebrew/install/master/install")
            run_command(["/usr/bin/ruby", script_path])

    def install_package(self, package):
        # type: (str) -> None
        try:
            print("====> checking status of %s" % package)
            run_command(["brew", "ls", "--versions", package])
            # if the previous call succeeded, the package is installed so upgrade
            try:
                print("====> upgrading %s" % package)
                brew_path = command_path("brew")
                assert brew_path is not None
                # NOTE: Apple Silicon support
                if "/opt/homebrew" in brew_path:
                    run_command(["arch", "-arm64", "brew", "upgrade", package])
                else:
                    run_command(["brew", "upgrade", package])
            except subprocess.CalledProcessError:
                pass
        except subprocess.CalledProcessError:
            # the package has never been installed, do that now
            print("====> installing %s" % package)
            run_command(["brew", "install", package])
        run_command_no_output(["brew", "link", package])

    @property
    def package_type(self):
        # type: () -> PackageName
        return PackageType.BREW

class AptPackageManager(BasePackageManager):
    """The APT package manager to use on Debian and derivatives."""

    def install(self):
        # type: () -> None
        print("====> updating apt")
        run_command(["sudo", "apt-get", "update"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "apt-get", "upgrade", "--yes", package])

    @property
    def package_type(self):
        # type: () -> PackageName
        return PackageType.DEB

class DnfPackageManager(BasePackageManager):
    """The DNF package manager to use on Fedora and derivatives."""

    def install(self):
        # type: () -> None
        pass

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "dnf", "install", "--best", "--assumeyes", package])

    @property
    def package_type(self):
        # type: () -> PackageName
        return PackageType.RPM

class PacmanPackageManager(BasePackageManager):
    """The Pacman package manager to use on Arch."""

    def install(self):
        # type: () -> None
        print("====> updating pacman")
        run_command(["sudo", "pacman", "-Syy"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "pacman", "-S", package, "--noconfirm", "--needed"])

    @property
    def package_type(self):
        # type: () -> PackageName
        return PackageType.PACMAN

class PkgPackageManager(BasePackageManager):
    """The PKG package manager to use on FreeBSD."""

    def install(self):
        # type: () -> None
        print("====> updating pkg")
        run_command(["sudo", "pkg", "update"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "pkg", "install", "--yes", package])

    @property
    def package_type(self):
        # type: () -> PackageName
        return PackageType.PKG

def _filter_packages(packages, name):
    # type: (List[Union[str, Dict[PackageName, str]]], PackageName) -> List[str]
    ret = []
    for package in packages:
        if isinstance(package, dict):
            package = package.get(name)
        if package:
            ret.append(package)
    return ret
