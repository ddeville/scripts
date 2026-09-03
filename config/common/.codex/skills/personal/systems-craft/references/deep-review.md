# Deep review

Use alongside [SKILL.md](../SKILL.md) for an explicitly requested broad or
persistent review. Scale the investigation to the system and the user's focus.
This applies to libraries, tools, applications, and services; a deployed system
is not required.

## Follow complete operations

Establish the checkout, existing changes, scope, and permission to edit. Identify
important contracts, state owners, expensive paths, and trust boundaries. Start
with consequential or underexamined areas, not arbitrary file traversal.
Record the starting changes so later reviews can distinguish your work from
pre-existing edits without reverting or rewriting them.

Keep brief working notes of hypotheses, evidence, and remaining areas. Do not
turn them into unsolicited product documentation.

## Try to disprove the design's assumptions

For each concern, identify the contract at risk and an experiment that could
confirm or refute it. Useful approaches include:

- Compare implementations, exercise real callers, or compare optimized and
  reference paths.
- Interrupt between a side effect and its acknowledgment, then retry or restart.
- Exercise event sequences with controlled scheduling or a small reference model.
- Vary input size and concurrency; measure work, allocations, and retained memory.
- Sketch a plausible feature change and check which unrelated components must change.

These are options, not a required matrix. Architecture findings need a concrete
maintenance burden or invariant, not a preference for a particular pattern.

## Connect code reasoning with runtime evidence

When runtime observation is available and authorized, establish the version,
inputs, and configuration in use. Relate outcomes and completion times to
resource use and work performed. Check denominators and workload differences
before trusting aggregates. Choose evidence appropriate to the system: local
profiles, representative benchmarks, execution traces, or production metrics.

Keep queries bounded and low impact. Use sanitized fixtures, not production
secrets. Production faults, load tests, restarts, or configuration changes need
specific authorization. Distinguish local experiments from production evidence;
missing runtime access need not stop useful code investigation.

## Fix, verify, and challenge the result

Separate confirmed defects, credible risks, design improvements, and preferences.
Prioritize impact, reachability, confidence, and fix cost. A reachable security
failure can matter without a production incident; speculation is not proof.

When fixes are authorized, edit the code in place in the working tree, preserving
existing work. Do not commit or push unless requested. Group changes by a coherent
problem or responsibility rather than accumulating an unreviewed rewrite.

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

Continue while consequential requested areas remain unexplored or actionable
findings remain within scope. Use a new evidence-based angle each pass; repeating
an unchanged review solely to get a different verdict is not progress. Finish
review-only work with findings; finish improvement work after verification and
a final review finds no further justified in-scope changes. Report unresolved
risks and blocked checks, honor explicit stopping conditions, and do not invent
nits or promise perfection.
