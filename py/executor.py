import inspect
import sys

TASK_PREFIX = "task_"

class ExecutorConfig(object):
    """The configuration to use when running tasks."""
    def __init__(self, module_name, platform):
        # type: (str, str): -> None
        self.module_name = module_name
        self.platform = platform

class TaskManifest(object):
    """Each task should return an instance of this class."""
    def __init__(self, cmd, platform, dependencies):
        # type: (Callable[[], None], str, List[str]) -> None
        self.cmd = cmd
        self.platform = platform
        self.dependencies = dependencies

def retrieve_task_names_for_config(config):
    # type: (ExecutorConfig) -> List[str]
    """Returns the name of the tasks that would be run for a given config."""
    return [task.name for task in _get_all_tasks_for_config(config)]

def run_tasks_for_config(config):
    # type: (ExecutorConfig) -> None
    """Run all tasks that match the given config."""
    _run_tasks(_get_all_tasks_for_config(config))

# Private

class _Task(object):
    """A concrete instance of a task, ready to be run."""
    def __init__(self, name, cmd, dependencies):
        # type: (str, Callable[[], None], List[str]) -> None
        self.name = name
        self.cmd = cmd
        self.dependencies = dependencies

def _get_all_tasks_for_config(config):
    # type: (ExecutorConfig) -> Generator[_Task]
    """Yield tasks that match the given config."""
    for name, func in list(inspect.getmembers(sys.modules[config.module_name], inspect.isfunction)):
        if name.startswith(TASK_PREFIX):
            manifest = func()
            assert isinstance(manifest, TaskManifest), ("`%s` should return an instance of `TaskManifest`, not %r" %
                    (name, type(manifest)))
            if config.platform in manifest.platform:
                yield _Task(name[len(TASK_PREFIX):], manifest.cmd, manifest.dependencies)

def _run_tasks(tasks):
    # type: (Sequence[_Task]) -> None
    """Run the given tasks, making sure to respect dependencies."""
    # keep track of the remaining tasks, as a dictionary for fast lookup by name
    remaining_tasks = {task.name: task for task in tasks}

    def _inner_run_tasks(inner_tasks):
        # type: (List[Manifest]) -> None
        for task in inner_tasks:
            # check whether the dependencies of this task have already been run
            for name in task.dependencies:
                # if we can find it in the list, it hasn't been run yet
                if name in remaining_tasks:
                    _inner_run_tasks([remaining_tasks[name]])

            # make sure that the task is still in the array (otherwise it has already run)
            if task.name in remaining_tasks:
                # we can now run the task!
                task.cmd()
                del remaining_tasks[task.name]

    _inner_run_tasks(list(remaining_tasks.values()))

    # if we still have a task in there, something went terribly wrong...
    assert not remaining_tasks
