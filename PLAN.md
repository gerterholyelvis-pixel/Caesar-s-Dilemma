# Caesar's Dilemma: build plan (living document)

Rules: tight agent briefs, short reports, headless tests first, <=1 screenshot per check, off-screen windows only
(`--position -32000,-32000`), commit + push after each stage. Design source of truth: CONTRACT_GAME.md. Research: RESEARCH.md.

| Stage | What | Status |
|-------|------|--------|
| 0 | Start screen, Limbo + angel, garden fly-through + title | DONE |
| 1 | Logic: items, backpack, combat, enemies, dilemmas, meta, glyph gen, lexicon (tested) | DONE, pushed |
| 2 | Art + audio + cinematic tool: item icons, creature/fractal body, sfx+music, Cutscene runner | IN PROGRESS (4 agents) |
| 3 | Screens + flow: BackpackUI, Battle, RouteMap, Run, Loot/Dilemma/Shrine/HeroSelect | NEXT (5 agents, parallel against the APIs in CONTRACT_GAME.md) |
| 4 | Integration: wire Limbo -> hero select -> garden -> Run; art/audio plugged into screens; end-to-end headless run | after 2+3 |
| 5 | Audio theory pass (just intonation, Euclidean rhythm, voice leading; see AUDIO THEORY DIRECTIVE) | after 2 |
| 6 | Cinematics x5 (hero reveal, boss intros, first glyph, death, ending) using Cutscene | after 4 |
| 7 | Content + balance: more items/enemies/dilemmas/origins, Thoth unlock, glyph codex UI, difficulty tuning via simulated runs | after 4 |
| 8 | Polish for beauty/oneness: shared UI style pass, juice, post-processing, perf pass (60 fps at 1080p), saves, settings | continuous, final pass |

Critical path: 2 -> 4 -> 6/7 -> 8. Stage 3 and 5 run in parallel with stage 2. Each stage ends with: run tests, one visual check,
commit, push. Risks: UI drag/drop feel (mitigate with research top-10 #1), audio quality without listening (mitigate: numbers + user listens to
audio_preview/), integration mismatches (stage 4 integration agent + end-to-end test).
