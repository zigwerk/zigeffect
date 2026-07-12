# ZigEffect System-Building Story Implementation Plan

Date: 2026-07-12
Design: `docs/superpowers/specs/2026-07-12-zigeffect-system-building-story.md`

## 1. Contract first

- Extend the route, prerender, sitemap, navigation, metadata, homepage, standard
  library, and durable workflow content tests.
- Run the focused test and record the expected failure before implementation.

## 2. Standard library chapter

- Add the route metadata and `StandardLibraryPage` implementation.
- Group public modules around practical system-building jobs.
- Include a public-facade example, agent boundary example, and honest adapter
  maturity explanation.

## 3. Durable workflows and homepage integration

- Expand the workflow chapter with durable primitives, statechart variants,
  actors, analysis, versioning, migration, storage, and recovery.
- Add a homepage system-building section with links to the two chapters.
- Add shared responsive styling using the existing slate/orange deep-page system.

## 4. Discovery and verification

- Update shared navigation, static prerender routes, and sitemap.
- Run the focused contracts, complete site tests, typecheck, production build,
  and browser checks for the new and expanded pages.
