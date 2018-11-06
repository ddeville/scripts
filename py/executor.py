import inspect
import sys

TASK_PREFIX = "task_"

class ExecutorConfig(object):
    """The configuration to use when running tasks."""
    def __init__(self, module_name, tags):
        # type: (str, List[str]): -> None
        self.module_name = module_name
        self.tags = tags

class TaskManifest(object):
    """Each task should return an instance of this class."""
    def __init__(self, cmd, tags, dependencies):
        # type: (Callable[[], None], List[str], List[str]) -> None
        self.cmd = cmd
        self.tags = tags
        self.dependencies = dependencies

def print_all_tasks_for_config(config):
    # type: (ExecutorConfig) -> None
    """Print the name of the tasks that would be run for a given config."""
    for task in _get_tasks(config):
        sys.stdout.write("%s\n" % task.name)

def run_all_tasks_for_config(config):
    # type: (ExecutorConfig) -> None
    """Run all tasks that match the given config."""
    for task in _get_tasks(config):
        task.cmd()

# Private

class _Task(object):
    """A concrete instance of a task, ready to be run."""
    def __init__(self, name, cmd, dependencies):
        # type: (str, Callable[[], None], List[str]) -> None
        self.name = name
        self.cmd = cmd
        self.dependencies = dependencies

def _get_tasks(config):
    # type: (ExecutorConfig) -> Generator[_Task]
    """Retrieve all tasks that match the given config and order them based on dependencies."""
    def _extract_tasks():
        # type: () -> Generator[_Task]
        for name, func in list(inspect.getmembers(sys.modules[config.module_name], inspect.isfunction)):
            if name.startswith(TASK_PREFIX):
                manifest = func()
                assert isinstance(manifest, TaskManifest), ("`%s` should return an instance of `TaskManifest`, not %r"
                        % (name, type(manifest)))
                if set(config.tags).issubset(manifest.tags):
                    yield _Task(name[len(TASK_PREFIX):], manifest.cmd, manifest.dependencies)

    # keep track of the remaining tasks, as a dictionary for fast lookup by name
    tasks = {task.name: task for task in _extract_tasks()}

    def _inner_run_tasks(inner_tasks):
        # type: (List[Manifest]) -> Generator[_Task]
        for task in inner_tasks:
            # check whether the dependencies of this task have already been run
            for name in task.dependencies:
                # if we can find it in the list, it hasn't been run yet so run it
                if name in tasks:
                    for inner_task in _inner_run_tasks([tasks[name]]):
                        yield inner_task

            # if the task is still in the array, it means that it hasn't been run yet
            if task.name in tasks:
                yield task
                del tasks[task.name]

    for task in _inner_run_tasks(list(tasks.values())):
        yield task

    # if we still have a task in there, something went terribly wrong...
    assert not tasks
