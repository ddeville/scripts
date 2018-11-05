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
    """Run all tasks that match the given config."""
    tasks = [manifest for _, manifest in get_tasks(config)]
    _run_tasks(tasks)

def get_tasks(config):
    # type: (Config) -> Generator[Tuple[str, Manifest]]
    """Yield tasks that match the given config."""
    for name, func in inspect.getmembers(sys.modules[config.module_name], inspect.isfunction):
        if name.startswith(TASK_PREFIX):
            name = name[len(TASK_PREFIX):]
            manifest = func()
            if config.platform in manifest.platform:
                yield name, manifest

def _run_tasks(tasks):
    # type: (List[Manifest]) -> None
    """Run the given tasks, making sure to respect dependencies."""
    tasks = sorted(tasks, key=lambda task: task[1].priority)
    for manifest in tasks:
        manifest.cmd()
