import errno
import os
import shutil
import subprocess
import tempfile

try:
    from urllib.request import urlretrieve
except ImportError:
    from urllib import urlretrieve  # type: ignore  # py2

from py.typing import *

def command_path(cmd):
    # type: (str) -> Optional[str]
    try:
        with open(os.devnull, "w") as f:
            path = subprocess.check_output(["which", cmd], stderr=f).strip().decode()
            return path if os.path.exists(path) and os.access(path, os.X_OK) else None
    except subprocess.CalledProcessError:
        return None

def is_cmd_installed(cmd):
    # type: (str) -> bool
    return command_path(cmd) is not None

def run_command(cmd, env=None):
    # type: (List[str], Optional[Dict[str, str]]) -> None
    environ = os.environ if env is None else env
    subprocess.check_call(cmd, env=environ)

def run_command_no_output(cmd, env=None):
    # type: (List[str], Optional[Dict[str, str]]) -> None
    with open(os.devnull, "w") as f:
        environ = os.environ if env is None else env
        subprocess.check_call(cmd, env=environ, stderr=f, stdout=f)

def run_script_as_root(script):
    # type: (str) -> None
    with tempfile.NamedTemporaryFile() as fw:
        fw.write(script.encode("utf-8"))
        fw.flush()
        subprocess.check_call(["sudo", "sh", "-e", fw.name])

def force_symlink(path1, path2):
    # type: (str, str) -> None
    try:
        os.symlink(path1, path2)
    except OSError as e:
        if e.errno == errno.EEXIST:
            if not os.path.islink(path2) and os.path.isdir(path2):
                shutil.rmtree(path2)
            else:
                os.remove(path2)
            os.symlink(path1, path2)
        else:
            raise

def create_dirs(path):
    # type: (str) -> None
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def copy_file(orig, dest, isdir=False):
    # type: (str, str, bool) -> None
    try:
        if isdir:
            shutil.copytree(orig, dest)
        else:
            shutil.copyfile(orig, dest)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def download_file(url, filename=None):
    # type: (str, Optional[str]) -> str
    return urlretrieve(url, filename)[0]
