---
description: Consult with DHH and the Rails expert team
argument-hint: [optional-topic]
allowed-tools: Task, Read
---

# Rails Expert Team Consultation

You need comprehensive Rails 8 guidance. Let me bring in DHH and the Rails expert team.

$IF($ARGUMENTS,
Topic focus: $ARGUMENTS

I'll ensure the team addresses this specific topic.
,
I'll consult with DHH to determine which specialists you need.
)

Use the Task tool to invoke the `dhh-coordinator` agent to provide coordinated guidance from the Rails expert team.

The team will:
1. Analyze your question or code
2. Consult relevant specialists (routing, database, Hotwire, Action Cable, testing, deployment, performance)
3. Facilitate discussion if specialists disagree
4. Present unified, well-reasoned recommendations
5. Ground advice in Rails 8 philosophy and best practices

DHH coordinates the discussion and ensures you get actionable guidance following "The Rails Way."
