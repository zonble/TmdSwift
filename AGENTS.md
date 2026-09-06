# Project Guidelines for AI Agents

## Development Philosophy: Test-Driven Development (TDD)

All AI agents contributing to `TmdSwift` must strictly follow Test-Driven Development (TDD):

1. **Write Tests First (Red)**:
   - Before writing or modifying any implementation code, write a comprehensive test in `Tests/TmdSwiftTests/` that asserts the expected behavior.
   - Run the test to ensure it fails as expected for the right reason.
   - Do not settle for superficial tests (e.g. merely checking `!data.isEmpty`); verify domain invariants such as rendered duration, timeline positions, event sequencing, or exact pitch/tick offsets.

2. **Implement Minimal Code (Green)**:
   - Implement only the minimal production code necessary to make the failing test pass.
   - Run the test suite and verify that the test now succeeds.

3. **Refactor Cleanly (Refactor)**:
   - Clean up code, remove duplication, optimize resource allocation (such as CoreAudio buffer re-use), and preserve comments/documentation.
   - Re-run all relevant unit tests to guarantee no regressions occurred.

## Musical Accuracy & Audio Rendering Invariants

- **Timeline & Tempo**:
  - Never hardcode BPM assumptions (e.g., assuming 120 BPM). Always resolve actual durations through the score's timeline or CoreAudio's `MusicSequenceGetSecondsForBeats`.
  - Account for dynamic tempo changes, relative tempo directives (`{!+10}`), and time signature changes across the conductor track.
  - Provide adequate release tails (e.g. 2.5s) on audio rendering so note decays and reverb tails are never clipped.

- **DSL Standards**:
  - Keep TMD notation AST parsers, formatters, and exporters compliant with the specifications outlined in `docs/TMD-Language-Specification.zh-TW.md` and `docs/TMD-Language-Specification.en.md`.
  - Skill documentation bundled with `TmdSkill` must remain in English for universal compatibility with AI tools and LLMs.
