---
name: systems-craft
description: Design, implement, refactor, and review software with pragmatic attention to correctness, security, scalability, efficiency, and maintainability. Use for substantive engineering work or code and architecture reviews; keep small tasks small.
---

# Systems craft

Build systems that remain correct, secure, scalable, and efficient as they
change. Prefer the smallest coherent solution. Additional complexity needs a
concrete benefit, and tradeoffs should be explicit.

Follow repository conventions and the user's scope. Ordinary code reviews are
findings-only unless fixes are requested. Deep reviews include fixing justified
issues in the working tree unless the user requests findings only. Neither mode
authorizes commits, pushes, deployments, or production changes.

For a requested deep, broad, or persistent review, read
[Deep review](references/deep-review.md); ordinary coding does not need the full
process.

## Start with required behavior and resource costs

Identify the required behavior, supported inputs, security guarantees, and
expected scale before choosing or changing the design.

Trace the whole operation, including cached responses, alternate routes,
fallbacks, and retries. An integrity or authorization failure must not become
success through a weaker path. Preserve supported client behavior; surprising
but valid input is not automatically malformed.

Consider how CPU, memory, I/O, and contention grow with workload and concurrency,
including retries and background work. Keep expensive or failing operations from
unnecessarily slowing unrelated work. When a change could affect performance,
compare against a representative baseline, covering normal operation and relevant
failure conditions. Cleaner code is not automatically faster or cheaper.

## Give components a clear job

Split code when the new component can take responsibility for a decision or
operation and simplify its callers. Do not split a file just because it is long,
or scatter a sequence of steps so that their required order becomes hard to see.
Keep state close to the code that changes it.

Separate calculations from I/O where that makes them easier to understand and
test. Do not add frameworks or large copies merely to achieve purity.

Use existing primitives and focused APIs; do not build plugin systems for
hypothetical second users. Ask what callers no longer have to understand or
coordinate after adding an abstraction.

**A little copying is better than a little dependency.** Prefer copying a small,
stable helper to coupling otherwise independent components or adding a package
solely to remove duplication. Share rules that must evolve consistently; do not
confuse identical-looking code with a shared responsibility.

## Make it clear who decides and who updates

When components interpret the same configuration, share the parser and rules
instead of maintaining independent versions. They should agree on what the input
means, but each must still validate untrusted input it receives.

Keep shared updates and resource cleanup under a clear owner. A configuration
reloader, for example, should validate before activation and own failure handling.
Decide whether retaining old configuration is safe for that system; its callers
should not have to coordinate those steps themselves.

Pass explicit results. Decide whether to retry from an operation's result or error
type, not its log message. Changing logging or metrics should not change
application behavior.

## Give tests the same care as production code

Test what callers rely on, using readable, realistic inputs and expected results.
A regression should fail on the old behavior when practical. Use controlled
clocks and synchronization instead of elapsed sleeps; speed tests up without
removing the behavior they protect.

Run the same behavioral tests against interchangeable implementations, such as
storage backends. Reuse production configuration in integration tests where
feasible. Use real dependencies or actual callers when a mock would hide relevant
behavior. Keep setup helpers small and assertions specific to each scenario.

For stateful logic, test sequences as well as isolated cases: duplicate, reorder,
interrupt, retry, and restore. A small independent reference model can expose
interactions that another happy-path example will miss.

## Work in reviewable increments

Trace the current behavior before editing. Explain consequential choices early;
ask before materially expanding scope. Preserve behavior during refactoring
unless a behavior change is intentional and verified.

For a risky replacement, keep the old implementation available for comparison.
Capture its behavior, compare both paths on the same inputs, and measure costs
before switching. Use [parallel implementations](references/design-influences.md#parallel-implementations)
selectively; routine edits do not need a second implementation.

After meaningful changes, inspect the combined diff and run checks that could
catch mistakes in the changed behavior. Green CI does not cover a missing
scenario, but rerunning unchanged tests without a question is not investigation.
Report evidence and limitations honestly.

For changes with operational impact, decide how to observe success, failure, and
resource cost. Read [Operational evidence](references/design-influences.md#operational-evidence)
when designing telemetry or health checks. The other
[design influences](references/design-influences.md) are optional guidance, not
mandatory patterns.
