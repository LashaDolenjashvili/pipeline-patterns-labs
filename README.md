# Pipeline Patterns Labs

Runnable SQL and analytics verification labs from
[Pipeline Patterns](https://pipelinepatterns.co).

These labs reproduce analytical failure modes, explain why they occur,
and provide verification queries that can be used during development
and review.

Each lab includes:

- a minimal reproducible dataset
- the incorrect query
- exact observed results
- an explanation of the failure mechanism
- one or more valid corrections
- verification checks
- the engine and version used for validation

## Labs

| Lab | Topic | Engine |
|---|---|---|
| [Declare the grain](labs/001-declare-the-grain/) | Join fan-out and repeated measures | DuckDB 1.5.4 |

## Verification standard

Every lab should answer three questions:

1. Under what exact condition does the failure occur?
2. How can the failure be reproduced?
3. Which check prevents it from reaching production?

## About Pipeline Patterns

Pipeline Patterns is about efficient analytics people can trust.

Weekly Newsletter: https://pipelinepatterns.substack.com  
YouTube: https://www.youtube.com/@PipelinePatterns  
Author Profile: https://www.linkedin.com/in/lasha-dolenjashvili/
