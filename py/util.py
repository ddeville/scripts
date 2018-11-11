import contextlib
import errno
import os
import shutil
import subprocess
import sys
import tempfile

MACOS = "macos"
LINUX = "linux"
FREEBSD = "freebsd"

def get_current_platform():
    # type: () -> str
    if "darwin" in sys.platform:
        return MACOS
    elif "linux" in sys.platform:
        return LINUX
    elif "freebsd" in sys.platform:
        return FREEBSD
    else:
        raise Exception("Platform not supported %s" % sys.platform)

def get_linux_distro_info():
    # type: () -> Dict[str, str]
    with open("/etc/os-release", "r") as f:
        return dict([entry.split("=") for entry in f.read().rstrip().split("\n")])

def is_cmd_installed(cmd):
    # type: (str) -> bool
    try:
        with open(os.devnull, "w") as f:
            path = subprocess.check_output(["which", cmd], stderr=f).strip()
            return os.path.exists(path) and os.access(path, os.X_OK)
    except subprocess.CalledProcessError as e:
        return False

def run_script_as_root(script):
    # type: (str) -> None
    with tempfile.NamedTemporaryFile() as fw:
        fw.write(script)
        fw.flush()
        subprocess.check_call(["sudo", "bash", "-e", fw.name])

def run_command(cmd):
    # type: (List[str]) -> None
    subprocess.check_call(cmd)

def run_command_no_output(cmd):
    # type: (List[str]) -> None
    with open(os.devnull, "w") as f:
        subprocess.check_call(cmd, stderr=f, stdout=f)

def force_symlink(path1, path2):
    # type: (str, str) -> None
    try:
        os.symlink(path1, path2)
    except OSError as e:
        if e.errno == errno.EEXIST:
            os.remove(path2)
            os.symlink(path1, path2)
        else:
            raise

def create_dirs_if_needed(path):
    # type: (str) -> None
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def copy_file_if_needed(orig, dest, isdir=False):
    # type: (str, str, bool) -> None
    try:
        if isdir:
            shutil.copytree(orig, dest)
        else:
            shutil.copyfile(orig, dest)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

@contextlib.contextmanager
def change_dir(path):
    original_path = os.getcwd()
    try:
        os.chdir(path)
        yield path
    finally:
        os.chdir(original_path)
