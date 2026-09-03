# Design influences

Optional public reading, not prerequisites or mandatory methods. The application
notes are our interpretations, not endorsements by the cited authors.

## Parallel implementations

[John Carmack, Parallel Implementations](https://www.gamedeveloper.com/programming/opinion-parallel-implementations)
argues for keeping working code available to make comparison and reversal easy.

For substantial replacements:

- Keep the baseline intact and the experiment separate, with a small comparison
  seam. Avoid interleaving both implementations through scattered flags.
- Compare deterministic inputs and event sequences. Investigate differences;
  known bugs need corrected expectations, not blind parity.
- Isolate side effects: do not duplicate external writes or assume stateful
  implementations can be switched mid-operation safely.
- Switch after behavior and performance checks pass. Use a runtime flag only
  when rollout needs it; test-only selection often suffices.
- Retire the superseded implementation and temporary switching machinery once
  no longer needed for rollback. Keep useful regression tests or a small oracle.

## John Ousterhout: reduce complexity for the reader

[A Philosophy of Software Design](https://web.stanford.edu/~ouster/cgi-bin/book.php)
judges design by how easily people can understand and change a system. Useful
warning signs are changes spreading across many places, too much context to
hold in mind, and dependencies a maintainer does not know to look for.
([Complexity notes](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=complexity))

The structural ideas work together:

- **Deep modules:** offer substantial functionality through a simple interface.
  Depth is not length; tiny classes can burden callers.
- **Information hiding:** keep each design decision with its owner. Private fields
  cannot hide a representation several components must understand. Decompose by
  knowledge, not execution order.
- **Pull complexity downward:** solve shared difficulties inside the module.
  Do not make callers coordinate them or administrators guess configuration values.
- **Somewhat general-purpose APIs:** use simple operations covering current needs,
  not special cases for each caller. Avoid speculative features and layers that
  merely forward calls.

Aim to reduce interface cost, not maximize module size or generality.
([Modular design notes](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=modularDesign))

- **Design it twice:** compare meaningfully different approaches before committing
  to an important interface; sketches are often sufficient.
  ([Design guidance](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=modularDesign))
- **Define errors out of existence:** choose contracts that eliminate needless
  exceptional cases, such as making removal of an absent item idempotent when
  that fits the operation. This means better semantics, not suppressing genuine
  failures or removing security checks.
  ([Exception handling notes](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=exceptions))
- **Comments are design tools:** describe contracts, units, ownership, and reasons
  that code cannot convey clearly. Draft the interface description early; an
  awkward explanation can expose an awkward abstraction. Do not narrate syntax.
  ([Comment guidance](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=comments))

Make small, continual design investments rather than accumulating shortcuts or
waiting for a rewrite. This is strategic work, not permission for endless cleanup.
([Strategic programming notes](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=working))

## Go Proverbs: clear code and small contracts

[Rob Pike's Go Proverbs](https://go-proverbs.github.io/) offer useful reminders
beyond Go. Apply the principles with judgment; the mechanisms remain language-specific.

- **“Clear is better than clever.”** Make control flow and ownership easy to
  follow. Prefer ordinary constructs to machinery that requires special knowledge.
- **“A little copying is better than a little dependency.”** A tiny independent
  helper may not justify coupling components or adding a package. This is not a
  reason to duplicate shared invariants or security decisions.
- **Keep interfaces focused and defaults useful.** In Go, favor small behavioral
  contracts and useful zero values. Avoid erasing useful type information with
  `any` or silently accepting missing configuration required for safety.
- **Concurrency needs coordination, not optimism.** Distinguish structuring
  concurrent work from actually executing in parallel. Use channels to coordinate
  and mutexes to protect shared state; neither is universally preferable.
- **Treat errors as part of the API.** Preserve information callers need to act;
  checking or logging an error is not necessarily handling it.
- **Write for users of the code.** Documentation should explain how to use a
  component and what it promises, not narrate its implementation.

## Operational evidence

[Google SRE, Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
distinguishes symptoms from causes and internal signals from user-visible
behavior. Build on that distinction: an operationally significant feature needs
enough evidence to tell whether it is working, what it costs, and where it fails.

- **Start with outcomes.** Distinguish successful completion from attempts, retries,
  partial work, cancellations, and expected rejections. Pair error rates with volume
  and latency distributions. A healthy process or successful intermediate step
  does not establish that a request or job delivered the correct result.
- **Explain the work.** Relate useful throughput to dependency calls, transferred
  bytes, repeated computation, and background activity. Where optimizations such as
  caching or batching matter, expose their effectiveness. Keep maintenance traffic
  separate from user activity so it cannot distort success rates.
- **Show capacity and pressure.** Relate resource use to limits, queued and in-flight
  work, waiting time, and rejected work. Inspect growth and churn, not only current
  utilization. Compare representative periods and individual workers or instances;
  averages can conceal an overloaded minority.
- **Report effective state.** Distinguish intended configuration, successful loading,
  and actual activation. Expose failed updates, progress, last successful checks,
  and lag or disagreement where replication exists. Distinguish no change from no
  progress. Pair health metrics with representative behavior checks when important
  guarantees cannot be inferred from counters.
- **Make failures traceable.** Use structured, component-owned logs with correlation
  across relevant boundaries. Preserve meaningful failure categories and context
  for diagnosis, including failures after work has partially completed. Keep secrets
  out of logs and retain appropriate audit evidence for privileged changes.
- **Treat telemetry as a tested contract.** Keep instrumentation with the component
  owning its meaning; share plumbing, not a central decision-making layer. Document
  metric meaning, units, labels, and counting rules in one catalog. Test successful,
  rejected, failed, and canceled paths as applicable. Diagnostic labels must not
  substitute for explicit application state.
- **Bound observability's own cost.** Budget label combinations and histogram buckets,
  not just individual label values. Keep request IDs, raw paths, and arbitrary input
  out of metric labels. Log only diagnostic context that is needed, with appropriate
  redaction and access controls. Avoid duplicate high-volume logs and expensive
  per-request instrumentation.
- **Keep dashboards usable.** Link a lightweight overview to focused component and
  cross-system views. Explain how to read each view and separate current state from
  history. Missing data must not look like healthy inactivity. Use consistent health
  colors and useful default windows; keep query and browser costs low. Alerts need
  an actionable symptom, owner, and investigation path, not merely a nonzero counter.
