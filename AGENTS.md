# Agent Instructions

## Philosophy

- **Keep It Simple.** Do the simplest thing that works.
- **Don't overthink.** Don't investigate alternatives, other projects, or add speculative features.
- **Match existing code style.** Follow the conventions already in the codebase.
- **Respect the user's intelligence.** Don't second-guess their explicit choices.

## Workflow

- **Show the diff before committing.** Never commit without explicit user approval.
- Wait for user to say "commit it", "looks good", or similar before running `git commit`.
- Test changes and show results to the user before asking to commit.

## Code Style

- Match the indentation and formatting already used in the project.
- Don't reformat files unless the user asks or it's part of the requested change.
- If adding config files (`.editorconfig`, formatter configs), ask first.

## What NOT To Do

- Don't add compatibility shims, fallbacks, or defensive checks unless asked.
- Don't investigate how other projects solve the same problem.
- Don't change working code for "cleaner" architecture unless asked.
- Don't commit without asking first.
- Don't add abstractions or indirection the user didn't ask for.
