---
description: Consult with the Performance & Optimization specialist
argument-hint: [optional-subtopic]
allowed-tools: Task, Read
---

# Performance & Optimization Specialist Consultation

$IF($ARGUMENTS,
You're asking about: $ARGUMENTS

I'll have DHH introduce you to our performance specialist for focused guidance on this topic.
,
You need expertise on Rails performance optimization. Let me introduce you to our specialist.
)

Use the Task tool to invoke the `performance-specialist` agent for expert guidance on:
- Performance profiling and benchmarking
- N+1 query prevention
- Database indexing and query optimization
- Caching strategies (Solid Cache, fragment caching, Russian doll)
- Asset optimization
- Production performance tuning

DHH will briefly introduce the specialist, then they'll help you identify and fix performance bottlenecks.
