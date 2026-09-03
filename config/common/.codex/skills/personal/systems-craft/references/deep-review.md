# Deep review

Use alongside [SKILL.md](../SKILL.md) for an explicitly requested broad or
persistent review. Scale the investigation to the system and the user's focus.
This applies to libraries, tools, applications, and services; a deployed system
is not required.

Treat a request to improve the system as an improvement review, not merely a
search for regressions in the latest diff. Investigate correctness, security,
scalability, efficiency, and maintainability deliberately. A worthwhile finding
can be avoidable repeated work, a fragile contract, misleading instrumentation,
or unnecessary coordination between components; it need not be a production
incident or a security exploit. Ground each recommendation in current behavior
and explain why its benefit warrants the change.

## Establish coverage before drawing conclusions

Establish the checkout, existing changes, scope, and any restrictions on edits. Identify
the major components and trace how users reach them. Map important operations,
trust boundaries, state owners, and resource bottlenecks. Recent changes are one
starting point, not a substitute for reviewing the system. Include mature,
less-exercised, and optional paths when they carry consequential behavior.

Keep brief working notes: area, assumption being checked, evidence, and remaining
questions. Distinguish code inspected from tests merely executed. Record starting
changes so later reviews can distinguish your work from pre-existing edits.
These notes guide the investigation; do not add an audit diary to product docs.
For a large codebase, a small recently changed subset cannot stand in for
the requested broad scope. Allocate attention across consequential subsystems
and the user's review criteria, then return to areas with unresolved questions.
If substantial scope remains, continue or report a partial review rather than
presenting the selected subset as a completed assessment.

## Follow operations across component boundaries

For high-impact operations, follow accepted input through authorization or
validation, side effects, publication of results, and cleanup. Then follow retry,
cancellation, and recovery. Check callers and implementations together: a helper
can be correct while its caller violates the assumptions that make it safe.

Pay particular attention to interactions. Individually tested features can fail
when combined: cancellation during shared work, authorization changes while data
is reused, a retry after an acknowledged or uncertain write, or a partial update
followed by restart. Select combinations suggested by actual code and supported
workflows, not an exhaustive matrix of imagined failures.

Check who owns decisions and transitions. Look for callers coordinating hidden
steps, multiple interpretations of one rule, and state that can change without
updating its dependents. Sketch a plausible feature change and follow the edits
it would require. An architecture finding should show a concrete maintenance
burden or an invariant that is hard to preserve, not just a long file or a
preferred pattern. Do not build the hypothetical feature.

## Design experiments that can reveal something new

Write down the expected behavior independently of the implementation, using the
public contract, supported clients, protocol specification, or a simple reference
model. Identify a reachable condition under which the code might violate it.
Choose a probe that could distinguish correct behavior from the suspected fault.

- Interrupt between a side effect and its acknowledgment; retry or restore from
  the resulting state. Check both the caller's result and durable side effects.
- Control concurrent scheduling at ownership transfers and shared updates.
  Check that one canceled or slow participant cannot corrupt or strand others.
- Compare implementations or exercise an actual caller on the same input.
  Include supported inputs that small synthetic fixtures omit.
- Vary size and concurrency together. Count dependency calls and transferred
  bytes as well as time, allocations, retained memory, and queue growth. Check
  repeated and idle work, not only the first successful operation.

Read the tests themselves. Does setup bypass the boundary being claimed? Does
the fake implement the dependency's failure and concurrency behavior? Is the
oracle independent, or does it repeat the same logic? Where useful, deliberately
break the invariant in an isolated copy to check that the test detects it.

Existing tests establish a baseline and protect fixes; they do not independently
validate their own assumptions. Fuzz execution counts, test counts, and elapsed
review time are not measures of coverage. Explain which new condition an
experiment exercised and what its result establishes. Benchmark allocations are
not peak memory, and a local timing is not a production latency guarantee.

## Validate behavior in representative environments

Choose runtime evidence for the software being reviewed. For a library, exercise
supported callers and implementations. For a CLI or application, check complete
user workflows and their observable effects. For a deployed service, investigate
live behavior unless the user excludes it. Read-only review permits observation;
it does not mean code-only review. Check available tools and access before declaring
runtime validation unavailable. Surface concrete blockers early, not only as a
qualification at the end.

Establish the version, effective configuration, workload, and environment behind
each observation. Unreleased code cannot be validated by observing an older
version, but operational evidence can expose assumptions to test locally. Trace
user-visible outcomes through their dependencies. Inspect failure patterns,
completion times, repeated work, and resource pressure; process health and low
aggregate error rates do not establish correct behavior. Compare relevant users,
workloads, or environments when averages could conceal a problem.

Relate outcomes and completion times to resource use and work performed. Check
denominators and workload differences before trusting aggregates. Use anomalies
to choose code investigations, and use code assumptions to choose runtime queries.

Find and exercise relevant integration and end-to-end tests. Where correctness
depends on another component's behavior, test against that implementation rather
than relying solely on a substitute that may omit the behavior under review.
Use supported local or isolated test environments; live checks that intentionally
create or mutate application data need specific authorization. Run the broader
suite when interactions or change scope warrant it. Existing CI results can
supply baseline evidence, but record their revision and coverage and distinguish
them from checks run during this review. Do not silently substitute focused unit
tests for end-to-end validation.

Keep queries bounded and low impact. Use sanitized fixtures, not production
secrets. Production faults, load tests, restarts, or configuration changes need
specific authorization. Distinguish local experiments from production evidence;
missing runtime access need not stop useful code investigation, but it leaves
that part of the review incomplete.

## Fix, verify, and challenge the result

Separate confirmed defects, credible risks, design improvements, and preferences.
Prioritize impact, reachability, confidence, and fix cost. A reachable security
failure can matter without a production incident; speculation is not proof.

For broad multi-component reviews, use independent subagents when delegation is
available and permitted. Give them bounded areas or distinct questions while you
investigate cross-component behavior. Supply contracts and raw evidence without
steering them toward your verdict. Inspect and reproduce their findings; neither
a delegated finding nor a clean verdict is proof on its own. Independent discovery
is useful before edits, not only when reviewing a patch afterward.

Unless the user requests findings only, fix justified issues in place in the
working tree, preserving existing work. Group changes by a coherent problem or
responsibility rather than accumulating an unreviewed rewrite. Follow the scope
and external-action limits in SKILL.md; working-tree fixes do not authorize
production changes.

After each logically related set of changes:

1. Add appropriate regression protection and run checks for the changed behavior
   and adjacent contracts.
2. Invoke `/review` on the actual changes, including relevant surrounding code,
   and wait for it to finish. Make the intended scope clear to the reviewer.
   The fixes themselves need scrutiny for correctness, security, scalability,
   efficiency, and design quality; finding the original problem is not enough.
3. Verify the findings, fix valid issues, rerun affected checks, and invoke
   `/review` again. Repeat until a completed review leaves no unresolved, justified
   implementation findings. Explain rejected findings; do not change correct code
   merely to appease a reviewer. A failed or interrupted review is not a clean result.

Stabilize each set before moving on, then review the final combined diff for
interactions between changes. Do not leave the last round of fixes unreviewed.
If `/review` is unavailable, use another independent reviewer when available and
authorized. If only self-review is possible, perform a separate critical pass and
report that limitation; never claim to have invoked a tool that was unavailable.

## Decide whether the review is actually complete

If the first pass finds nothing, challenge the search strategy before concluding
the system is sound. Move beyond recent changes and familiar code, inspect an
unexamined boundary, question a test fixture's assumptions, or combine related
behaviors that are only tested separately. Choose the next angle from remaining
risk; do not just rerun the same suite or ask for another identical verdict.

Continue while consequential requested areas remain unexplored or credible
questions can still be resolved within scope. Lack of an immediately reproducible
bug does not close the efficiency, test-quality, or architecture parts of the
review. A clean patch review closes that patch, not the broader investigation.
Stabilize fixes without losing track of the areas you had not yet reviewed.

Finish when the high-risk scope has evidence behind it, findings have been
resolved or reported, and further work is unlikely to change the assessment.
Honor explicit stopping conditions. A review may legitimately find no defects;
never manufacture nits to satisfy a quota or promise perfection.

Report findings first, with the affected behavior, triggering condition, impact,
and evidence. For design improvements, explain what callers would no longer need
to know or coordinate. Summarize coverage and meaningful experiments separately
from existing checks, and identify important areas not examined or blocked.
Qualify a clean result by its coverage; do not turn it into a general claim of
correctness. Finish improvement work with the final combined changes reviewed
and verified.
