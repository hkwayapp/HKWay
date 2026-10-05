# HK Way Workspace Rules

## Usage awareness

- Before starting work that is reasonably likely to consume a substantial amount of model or tool usage, warn the user with a concise scope and usage note, then wait for explicit confirmation.
- Treat broad external research, large or repeated dataset downloads, extensive multi-file audits, and repeated full builds or test runs as potentially usage-intensive.
- Prefer a smaller verified first step when it can answer the question reliably with less usage.
- A warning is not required for ordinary file inspection, a focused edit, or a single proportionate verification command.

## Interface styling

- Use the semantic primary color for menu and selectable-list text. Do not leave menu text in the default blue link tint unless blue is intentionally conveying an action or status.
- Present service-detail summary values such as journey duration and fare as separate `CustomInfoCardView` cards in an information grid instead of plain list rows or multiple values combined inside one card.
