### Prompt — Full Code Audit, Fix & Pre-Commit Readiness

Mục tiêu: Yêu cầu agent audit toàn bộ code và asset mới, tìm lỗi, sửa triệt để, hoàn thiện integration trước khi `add + commit + push`. Không chạy test hoặc Godot để tiết kiệm thời gian.

```

You are a Senior Godot 4.7.2 Engineer, Technical Lead,
Gameplay Architect, and Code Reviewer.

Repository:
https://github.com/thanh-pham2k/3d-asset-demo

MISSION
Perform a comprehensive pre-commit audit of the entire
current workspace, fix confirmed issues, and prepare the
project for a clean Git commit and push.

IMPORTANT
Do not stop at analysis or recommendations.
Inspect the actual code, implement necessary fixes,
and complete the static review.

Read AGENTS.md before making any changes.

1. REPOSITORY & CHANGE AUDIT

- Inspect the current branch, working tree, and Git diff.
- Review all staged, unstaged, and newly created files.
- Identify changes introduced by parallel agents.
- Check overlapping implementations and merge conflicts.
- Preserve all legitimate existing changes.
- Never reset, discard, or overwrite unrelated work.
- Compare against the current branch baseline.
- Do not assume that previous agent reports are accurate.

2. GAMEPLAY SYSTEM AUDIT

Review all implemented systems:

- Boy/Girl character selection and movement
- Motorcycle riding, parking, and navigation
- Motorcycle repair business
- Hu Tieu business and customer lifecycle
- Daily Gameplay Loop
- NPC simulation
- Shopping UI and kiosks
- Household wallet and transactions
- Inventory management
- Business and house upgrades
- Furniture placement and interactions
- Pet System
- Farming System
- Home activities
- Minimap and navigation
- Local co-op and shared progression

For every system, verify statically:
- Valid state transitions
- Correct dependencies and references
- Correct interaction flow
- No duplicate rewards or purchases
- No unreachable gameplay actions
- No accidental regressions
- No conflicting input mappings
- No invalid scene or node assumptions

3. ECONOMY & PERSISTENCE AUDIT

Pay special attention to financial and save correctness.

- Every purchase deducts money exactly once.
- Every completed order rewards money exactly once.
- Failed/cancelled orders never generate revenue.
- Tips and bonuses are calculated consistently.
- Inventory consumption matches gameplay actions.
- Purchased furniture and upgrades persist.
- Pet ownership, needs, and affection persist.
- Farming plots, crops, and growth persist.
- Daily progression persists across reloads.
- Existing save files remain backward-compatible.
- Test environments cannot overwrite real player saves.
- Failed saves must preserve the last valid save.
- Avoid unsafe overwrite, rename, and backup fallbacks.

Fix any confirmed inconsistencies.

4. LOW-POLY ASSET AUDIT

Inspect:
- assets/
- scenes/
- scripts referencing assets
- Asset definitions and catalogs

Check:
- Missing GLB, OBJ, textures, materials, or animations
- Invalid resource paths and scene references
- Broken asset dependencies
- Incorrect pivots, transforms, and scale assumptions
- Missing or inconsistent collision definitions
- Duplicate or unused assets
- Placeholder assets presented as finished
- Missing asset integration
- Inconsistent visual style

Ensure all newly implemented gameplay features
reference assets that actually exist.

Do not replace working assets unnecessarily.

If a required external asset cannot be created with
available tools, report it as a remaining blocker.
Do not fabricate completion.

5. PET & FARMING AUDIT

Pet System:
- Adoption and ownership
- Navigation and following
- Feeding and item consumption
- Happiness and affection
- Sleeping and playing
- Furniture and doorway avoidance
- Save/load
- Animation and pet prop references

Farming System:
- Seed purchases
- Planting and seed consumption
- Watering
- Growth stages
- Day transitions
- Harvesting
- Selling or using crops
- Inventory integration
- Save/load

Check for duplicate updates, lost inventory,
invalid states, and missing visual resources.

6. UI / UX AUDIT

Review:
- Shopping UI
- Inventory UI
- Interaction prompts
- Daily objectives
- Daily summary
- Minimap
- Pet feedback
- Farming feedback
- Furniture placement

Fix:
- Incorrect labels or prices
- Missing interaction feedback
- Conflicting keyboard controls
- Incorrect UI state transitions
- Duplicate signals
- Unclosable dialogs
- Input leaking into gameplay while a modal is open
- Missing product or asset references

Preserve the existing cozy low-poly visual direction.

7. ARCHITECTURE & CODE QUALITY

Apply:
- SOLID where useful
- DRY
- KISS
- YAGNI
- Separation of concerns
- Clear ownership of persistent state

Fix:
- Duplicated business logic
- Invalid method/property references
- Circular dependencies
- Unsafe signal connections
- Invalid node access
- Unhandled null values
- Resource leaks
- Conflicting state ownership
- Fragile hardcoded assumptions
- Unnecessary per-frame allocations

Do not refactor working code solely for style.
Prefer minimal, high-impact changes.

8. DOCUMENTATION

Update only when necessary:
- README.md
- docs/neighborhood.md
- docs/asset-inventory.md

Document actual implemented functionality.
Clearly distinguish:
- Implemented
- Partially implemented
- Placeholder
- Not implemented
- Not validated

Do not claim that a feature works merely because
its source files exist.

9. PRE-COMMIT HYGIENE

Inspect Git status and diff.

Check for:
- Generated cache files
- Temporary files
- Debug artifacts
- Duplicate assets
- Large unintended binaries
- Missing source assets
- Broken references
- Secrets or machine-specific paths
- Unnecessary formatting changes

Preserve intentional GIFs and other artifacts.
Do not delete user files without clear justification.

Ensure the working tree contains only intended changes.

10. EXECUTION POLICY — SKIP TESTS

To optimize development speed:

DO NOT:
- Run automated tests
- Run Godot headless
- Launch Godot
- Execute gameplay scenarios
- Generate GIF evidence
- Run performance benchmarks
- Regenerate all assets unnecessarily

Perform static source inspection only.

Do not claim runtime correctness or test success.

11. COMPLETION CRITERIA

Before finishing:

- Resolve all confirmed P0 issues.
- Resolve all feasible P1 issues introduced by current changes.
- Verify references and dependencies statically.
- Ensure new gameplay is integrated into the actual game flow.
- Ensure economy and persistence have consistent ownership.
- Ensure no unresolved merge conflict markers remain.
- Review the final diff for accidental changes.
- Document unresolved blockers honestly.

Do not silently skip incomplete features.
Do not replace missing functionality with fake placeholders
and claim it is complete.

12. GIT POLICY

- Do not execute git add.
- Do not execute git commit.
- Do not execute git push.
- Do not merge branches.
- Do not modify remote branches.

Leave all reviewed changes in the current working tree
for my final approval.

13. FINAL REPORT

Provide a concise, evidence-based report:

A. CURRENT BRANCH
- Branch name
- Changed files summary

B. ISSUES FOUND
- P0 / P1 / P2
- Root cause
- Affected files

C. FIXES IMPLEMENTED
- Issue
- Solution
- Modified files

D. FEATURE READINESS
For each gameplay system:
- READY (static review only)
- PARTIAL
- BLOCKED

E. ASSET READINESS
- Available assets
- Missing assets
- Remaining placeholders

F. REMAINING RISKS
- Unresolved issues
- Runtime verification still required

G. GIT READINESS
Return one of:
- READY FOR REVIEW AND COMMIT
- NOT READY — BLOCKERS REMAIN

H. EXECUTION STATUS
Tests: NOT RUN (explicitly requested)
Godot: NOT LAUNCHED
Commit: NOT PERFORMED
Push: NOT PERFORMED

FINAL INSTRUCTION
Audit thoroughly, fix confirmed issues directly,
preserve existing work, and prepare a clean,
reviewable implementation.

Do not commit or push automatically.

```

Khuyến nghị: Sau khi agent hoàn thành, chỉ `add + commit + push` nếu báo cáo ghi READY FOR REVIEW AND COMMIT và không còn P0 blocker. Trạng thái đó chỉ xác nhận mức sẵn sàng qua static review, không thay thế kiểm thử runtime.