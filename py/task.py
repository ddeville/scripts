import inspect
import sys

TASK_PREFIX = "task_"

class Config(object):
    def __init__(self, module_name, platform):
        self.module_name = module_name
        self.platform = platform

class Manifest(object):
    def __init__(self, cmd, priority, platform):
        self.cmd = cmd
        self.priority = priority
        self.platform = platform

def run_tasks(config):
    # type: (Config) -> None
    tasks = [manifest for _, manifest in get_tasks(config)]
    _run_tasks(tasks)

def get_tasks(config):
    # type: (Config) -> List[Tuple[str, Manifest]]
    manifests = []
    for name, func in inspect.getmembers(sys.modules[config.module_name], inspect.isfunction):
        if name.startswith(TASK_PREFIX):
            manifest = func()
            if config.platform in manifest.platform:
                manifests.append((name[len(TASK_PREFIX):], manifest))
    return sorted(manifests, key=lambda task: task[1].priority)

def _run_tasks(tasks):
    # type: (List[Manifest]) -> None
    for manifest in tasks:
        manifest.cmd()
