# IDLE_RESEARCH: guidance for Caesar's Dilemma (idle)

Source tags: [KONG] = Kongregate "Math of Idle Games" I/II (gamedeveloper.com); [IDOL] = Idle Idol balancing postmortem (gamedeveloper.com); [DEV7] = dev.to "7 idle games in 30 days" (author heuristics, not measured); [UP] = Universal Paperclips analysis (if50.substack.com, Wikipedia); [ADR] = A Dark Room (Wikipedia, PocketGamer.biz, Townsend quotes second-hand); [4DA] = Four Divine Abidings devlog (itch.io); [GD] = Godot asset library; [GEN] = well-known genre convention / my own knowledge, NOT verified in this session (treat as hypotheses to test in the simulator). Web search was shallow on Antimatter Dimensions, Realm Grinder, NGU, Egg Inc and Trimps; those references are [GEN].

## 1. First 10 minutes
- Start with ONE number and ONE button. Paperclips opens with a single "Make Paperclip" button; options then unlock quickly and the player becomes a manager once an autoclipper exists [UP]. Matches design rung 0.
- Players judge in ~30 s. Targets: first purchase ~60 s, first automation ~3 min, a "decision point" inside 5 min, first prestige 10-15 min [DEV7]. For us: first Sprout at ~20 s (cost 10, gettable by tapping), see it working before 1 min.
- Phase change every 3-5 minutes of active play: manual, auto, multi, prestige [DEV7]. Each rung gets a small cinematic moment plus a glyph word learned (our ladder).
- A Dark Room: slow, tiny opening, and the first expansion teaches "this game will grow"; story told through environment, not exposition [ADR]. Use the garden itself as the narrator: a new tab fades in only after the world visibly changes.
- Show only the next 2-3 purchasable items; "spreadsheet syndrome" (all numbers at once) kills discovery [DEV7]. Resolve the tension with our rule: numbers are always plain for what is visible; the mystery is in WHAT is visible and in glyph names.
- Shifting bottlenecks keep early game fresh: wire, then trust/ops, then matter, then power [UP]. Introduce a second currency (Insight) when Sap income starts feeling flat, not before.
- New systems appear at milestones and bring a new DECISION, not just a bigger number [UP]. Gate each tab on a plain, visible condition ("Insight unlocks at 1e3 Sap/s", shown greyed with a glyph silhouette).
- Never show an empty tab; show a teaser silhouette of the next one (curiosity hook, [ADR] spirit).

## 2. Number curves
- Core: cost_n = base * r^owned; production = base_prod * owned * multipliers [KONG]. AdCap lemonade r = 1.07; Derivative Clicker r = 1.1; common default 1.15 [KONG][DEV7]. Cookie-Clicker-style is 1.15 for all tiers [GEN].
- Recommended: r = 1.15 for early tiers, 1.12-1.14 for later tiers (cheaper tail keeps late-tier buying relevant) [GEN]. Base cost of tier k ~ 12^k x tier-0 cost [GEN] (about 10, 120, 1.4K, 17K ...), base production ~ 8-10^k.
- Milestone multipliers: AdCap stacks x2 at 25, 50 owned, which temporarily pushes income above cost [KONG]. Our x2 at 25/50/100/200 (+x3 at 300/400 later [GEN]) is right; show "next milestone in N" bar on every row so the player sees the next jump.
- Exponential cost always beats polynomial production eventually [KONG]; that wall is what prestige resets. Plan the wall: design where generator tier T stalls (~ owned 150-250) and put the prestige offer there.
- Different multiplier tables per generator so different tiers dominate at different stages, not always the newest [KONG].
- Bulk buying: cost(n) = b*r^k*(r^n-1)/(r-1); max affordable = floor(log_r(c(r-1)/(b*r^k)+1)) [KONG]. Implement Max with this closed form, never a loop (BigNum friendly).
- Cost basis: price off PURCHASED count, not owned, if free/bonus units can be granted [KONG-adjacent search result].
- Pacing target (hypothesis [GEN]): time to afford next unit of the current best tier 5-30 s early, growing to ~2-5 min by the wall; time between milestones 1-3 min early. Any gap >3 min without a purchase, milestone, event or ability is dead time.
- Slow gradually: "neither too fast nor too slow", and tune with the exponent's growth rather than hand-set late costs, which failed in practice [IDOL].
- Soft caps (Antimatter-Dimensions style [GEN]): after threshold X, effect ^0.5 or log scaling; announce them in tooltips ("softcap at 1e12: exponent halves") so they read as design, not as a bug.
- Big numbers: Godot float64 overflows at ~1.8e308; build a mantissa x 10^exponent type early. The Godot asset "Idle Number Kit Lite" (MIT, pure GDScript RefCounted, 37 headless tests, add/sub/mul/div/pow, compare, parse, serialize) is a reference, and shoyguer's GDExtension BigNumber is the fast option [GD]. We use our own BigNum: normalise mantissa to [1,10) after every op, store as [m,e] in saves, avoid allocation in hot loops (cache results per tick, update display at 10 Hz).
- Notation: K/M/B/T then scientific "1.23e45" past ~1e33; engineering notation optional; glyph notation as a cosmetic toggle only. Always 3 significant digits, rates with /s.
- Universal Paperclips shows precision loss is hidden by scale ("graceful degradation") [UP]; do not over-engineer past 1e300 for layer 1.

## 3. Prestige
- First offer at 10-15 min [DEV7]; I'd shade to ~20-25 min for our richer game because the first hour must teach Research and Heroes first [GEN]. Offer only when the reward is already at least ~+100% of current speed (Memories give a big visible jump).
- Prestige must feel like acceleration: the next run visibly faster within 30 s [DEV7]. Keep one "head start" (start with N Sprouts) plus an auto-buyer retained after reset.
- Formulas: sqrt curve gives large early jumps and tapering later: floor(sqrt(points/1000)) with multiplier 1+bonus*0.1 [DEV7]; Cookie Clicker reportedly uses cube root of lifetime/1e12, with sources disagreeing on per-level bonus (1% vs 5%) [search result, low-quality sources]. Use memories = floor((lifetime_sap/1e9)^0.5) and a multiplier 1 + 0.1*memories (diminishing after 100 via log) [GEN].
- Decision value: "reset now vs wait" should be a real, readable choice; show "+X Memories if you return now", and the marginal gain per minute; players leave when optimal timing is opaque [GEN].
- Layers: each layer introduces a new meta-currency and new generators, not only a multiplier (Realm Grinder, AD infinity/eternity/reality [search summaries]). Pace: layer 2 only after ~5-10 layer-1 resets; layer 3 sketched only. Each layer needs a "challenge" or constraint run to stay engaging [GEN].
- Keep resets feeling good: retain codex, glyphs, achievements, hero levels, relics; reset garden, Sap, generators. Play a short, beautiful "return to Limbo" cinematic (skippable after the first). Never reset what the player collected for fun.
- Progress must always forward: no reset should leave the player slower than before.

## 4. Automation, research, crafting
- Automation is the key phase change from clicking to managing [UP][DEV7]: upgrades that change how you play (auto-buy managers) matter more than +x%.
- Staged automation: auto-buy one tier, then all tiers, then smart thresholds ("buy when cost < 5% of Sap"), each as a research node [GEN].
- Research tree: 3 branches max at first, each node shows effect, cost, time; glyph-named until decoded in the Codex (mystery without hiding maths: effect text is shown, only the name is glyphs).
- Gate research on a second resource (Insight) with a different production source (Thoth observing + decoding) so there is always a "something else" to optimise [UP trust-bottleneck pattern].
- Crafting: recipes combine 2-3 Essences; some recipes are "discoverable" through experiment UI with hints; relic slots start at 1 and grow with prestige. Crafted items are permanent multipliers, never consumed, to avoid inventory management.
- Keep each system's reward meaningfully different (speed, multiplier, unlock, cosmetic) so no system is a duplicate of Sap math [GEN].

## 5. Active vs passive
- Rule: active play should be ~1.5-2x passive efficiency, never 10x; idle must feel fine. 4DA: click cooldowns make non-stop clicking impossible so balance holds for any playstyle; idle bonus also applies offline [4DA].
- Hero abilities: 30-90 s cooldowns for "frequent" abilities, 5-10 min for "big" ones; vary cooldowns deliberately because equal cooldowns balance on paper but feel bland [IDOL]. Weight effect strength and trigger conditions separately and multiply to balance categories [IDOL].
- Events: random garden events every 2-5 min with a short lifetime (golden-cookie style [GEN]); Caesar's Dilemmas rarer (every 20-30 min), with a cryptic prompt and visible trade-offs; always skippable and auto-resolved offline.
- Offline: pay ~50% of active rate as a "welcome back" gift [DEV7]; cap hours (4DA caps 52 h; Melvor Idle treats offline as equivalent to idling [community comment]). Our plan: 100% of rate up to 2 h, 50% to 12 h, 25% to 24 h, hard cap 48 h [GEN]. Warn: fast accumulation lets a returning player unlock a lot at once, so gate unlocks on events, not just wealth [dev.to devlog].
- Offline must be computed by the same deterministic simulation (closed-form per segment, not a tick loop for 48 h) and never fire events that need a decision.

## 6. UI clarity and modern look
- Layout: left or bottom tab rail (icons + short label, glow on new content with a dot badge), top resource bar with Sap, rate/s, Insight; centre = actions; right = the living garden view [GEN].
- One-click buy amount toggle x1/x10/x100/Max persistent across tabs; affordable button glows, unaffordable greys with a "time to afford" line [GEN].
- Tooltip rule: every number can be hovered to show the exact formula and contributions (base x milestones x research x memories). This is the clarity pillar [IDOL: first check UI before changing numbers; players missed the passive skills screen].
- Check UI/tutorial before retuning numbers: a pacing complaint was a discoverability bug [IDOL].
- Juice: number popups from the tapped Seed (pooled labels, rise and fade 0.6 s), purchase "pop" with scale 1.0 to 1.08 over 0.12 s, milestone flash and glyph reveal, bloom pulse on unlock, haptic-feeling sfx pitch rising per consecutive buy [GEN].
- World reflects progress: tie 5-8 world "layers" to thresholds (generator counts, hero levels, Memories): ground light, trees, waterfall, spores, sky; each appears with a 3 s fade, with the audio stem added in sync. Mirror every generator tier with a visible garden object so ownership is seen not read.
- Palette discipline: dark ink background, teal/emerald for growth, gold for currency and CTA, violet for mystery/glyph, cyan for active; only gold buttons are "buy". Keep text contrast high; mystery goes in glyph art not low-contrast text.
- Performance: cap particles, update HUD at 10 Hz, tween only changed labels, 60 fps target; the simulation is fixed-step and decoupled from rendering.

## 7. Achievements, collections, secrets
- Achievements give direction: "reach 1 million" style goals prevent the no-goal drop-off [DEV7]. Show 3 visible "next goals" and many hidden ones with "???" and a glyph.
- Each achievement gives a tiny permanent bonus (+1% Sap) or cosmetic so they are felt, not just counted [GEN].
- Collections: Codex glyphs (decoding gives research discounts), Flora catalogue, Relics; each has a completion % and a milestone reward at 25/50/100%.
- Secrets: hidden hotspots in the garden (tap a firefly 7 times, wait 3 minutes at the Mirror Lake). Keep them rewarding but never required for progress; all required info is plain. A Dark Room lets the player "construct the narrative" by discovering it [ADR].
- Cryptic lore via glyph words, fragments shown on each unlock; a "journal" tab restates every clue plainly after discovery (mystery first, clarity after).

## 8. Pitfalls and balance testing
- Linear costs create glacial stretches; use exponentials [DEV7]. Overly slow early game loses players in 30 s [DEV7].
- Balance flips between too slow and too fast as more systems alter the math (Idle Idol); lock a core curve first and add systems as multipliers on top [IDOL].
- Tune tiny increments: small changes in the exponent compound hugely by upgrade 20 [IDOL].
- Keep one master data table (costs, caps, multipliers) driving everything so one change updates 40+ items [IDOL]. Our JSON/dictionary data-driven plan fits.
- Simulator (headless GDScript): bot policies (a) greedy best income-per-cost, (b) buy-cheapest, (c) lazy: logs in every 30 min; outputs time-to-milestone, time-to-first-prestige, longest gap between purchases, and income curve per policy. Pass criteria: no dead gap >3 min before the first prestige; policy (c) reaches prestige within 2x of (a); automation bought before minute 12.
- Run sims on every data change in CI; alert if first-prestige time drifts >15%.
- Save safety: versioned saves, migration functions, export/import string, clamp offline time against clock tampering [GEN].
- Avoid: too many currencies before minute 30, hiding costs, forced waiting with nothing to do, prestige that resets things players loved.

## Top 10 recommendations for this project
1. Build BigNum first with unit tests (normalisation, pow, compare, log, serialise), loosely modelled on Idle Number Kit Lite [GD]; expose closed-form bulk-buy/Max [KONG].
2. Keep r = 1.15 (1.12-1.14 for the late tiers), x2 milestones at 25/50/100/200 with a visible "next milestone" bar.
3. Make the first purchase within ~20-60 s, first automation ~3 min [DEV7]; only Sap and the Seed are visible until then.
4. Unlock one new thing every 3-5 minutes in the first hour, each as a small garden cinematic plus a glyph word [UP][ADR].
5. Offer Prestige 1 at roughly 20-25 min with a clear "+X Memories" preview and a visibly faster next run [DEV7].
6. Use sqrt-style memory gains and keep codex/hero/relic progress through resets.
7. Hero abilities with deliberately varied cooldowns for the active layer; idle play remains within ~2x of active [IDOL][4DA].
8. Offline: 100% to 2 h, 50% to 12 h, 25% to 24 h, cap 48 h, computed in closed form; welcome-back summary.
9. Write the balance simulator before content expansion; budget no dead gaps >3 min before prestige [IDOL].
10. Tooltips with exact maths everywhere; mystery only in names, secrets and events; the garden mirrors every tier visually.

## Proposed first-hour unlock timeline
- 0:00 Seed + Sap only; tap.
- 0:20 first Sprout (10 Sap); first glyph word learned.
- 1:30 Upgrades tab (click power, Sprout x2); Buy x1/x10 toggle.
- 3:00 Fern + first auto-buyer ("Gardener"); garden gets a faint light.
- 5:00 Fractal Tree; 25-owned milestone bar visible; Buy x100/Max appears.
- 8:00 Research tab with Insight; Thoth appears (cinematic); first glyph-named nodes.
- 12:00 Crystal Bloom + automation research completes (auto-buy all); waterfall wakes.
- 16:00 Seshat hero + first active ability; first random garden event.
- 20:00 Codex/collections tab; first achievements, hidden ones teased.
- 24:00 Spore Engine; first Caesar's Dilemma.
- 28:00 Prestige 1 teaser: the angel appears (greyed button, plain preview).
- 32:00 Expeditions tab (Glade); first Essences.
- 38:00 Waterfall Mill; second expedition zone; offline summary demo.
- 44:00 Crafting tab, first relic recipe (one secret recipe hinted).
- 50:00 Return to Limbo becomes recommended (+100% or more); Memory tree.
- 55-60:00 Reset cinematic, faster second run (head start + retained auto-buy); Eclipse hinted as a distant glyph.
