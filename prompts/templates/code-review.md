# Code Review Prompt Template

Review the diff for `<FEATURE-ID>`:
1. Does it strictly match `docs/04-roadmap/very-mvp.md` without scope creep?
2. Are balance values stored in `data/` rather than hard-coded?
3. Are Godot 4.7.2 typing, signals, and `.uid` / `.tscn` references intact?
4. Are there any duplicated helpers or side effects on unrelated modules?
