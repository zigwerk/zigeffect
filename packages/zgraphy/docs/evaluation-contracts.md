# zgraphy evaluation contracts

Status: M0 schema foundation

Version: zgraphy.evaluation-contracts.v1

zgraphy separates five evidence categories so extraction quality, retrieval
quality, agent outcomes, performance, and resource use cannot be substituted
for one another.

## Extraction

zgraphy.differential-receipt.v1 compares Graphify, native zgraphy, or the
lexical floor against reviewed canonical entities, relations, facts,
hyperedges, supernodes, evidence, and provenance. Missing, unexpected,
synthesized, and unmappable results retain their stable semantic IDs.

## Retrieval

zgraphy.retrieval-receipt.v1 binds held-out task and corpus identity, graph
generation, schema/ontology/index/embedder fingerprints, query plan and budgets,
relevance judgements, returned identities, proof paths, omissions, stale or
partial dimensions, and bound exhaustion.

The required scorecard includes recall@k, MRR, nDCG, evidence precision, proof
faithfulness, completeness, context bytes, and latency. This schema is defined
but no retrieval baseline is claimed in M0.

## Agent tasks

zgraphy.agent-task-receipt.v1 compares baseline and graph-assisted arms using
the same fixed agent/model, prompt, tool policy, repository state, task rubric,
and resource limits. Every trial records task success, rubric assertions,
evidence citations, unsupported claims, edits, test outcomes, tool calls, file
reads, context bytes, tokens, wall time, and spend.

An assisted arm cannot claim improvement without a baseline arm, held-out tasks,
declared trials, complete cost accounting, and no unsupported claims. This
schema is defined but no agent-task improvement is claimed in M0.

## Performance and resources

zgraphy.performance-receipt.v1 requires correctness before latency, throughput,
allocations, CPU, RSS, or storage measurements can support a claim. It binds
machine, OS/target, toolchain, optimization, source, corpus, adapter,
configuration, warmups, repetitions, retained samples, and limitations.

zgraphy.resource-matrix.v1 is the active M0 paired-process baseline. Its integer
observations and quantiles remain separate from quality, and its claims array
remains empty.

## Claim policy

M0 permits baseline recording only. Schema-only retrieval, agent-task, and
performance definitions are not measured evidence. Comparative claims require
held-out extraction/retrieval/tasks, paired resource evidence, complete
identity, a non-cherry-picked matrix, and zero unsupported claims.

Inspect with zgraphy evaluation --json or zgraphy evaluation agent_task --json.
