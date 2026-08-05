# Feel → Parameters

Resolve feel adjectives into concrete easing, duration, and spring values. These are defaults — project tokens/conventions override them.

## Adjective mapping

| The user says | Resolve to |
|---|---|
| snappy, responsive, instant | ease-out expo, 150–250ms |
| smooth, calm, gentle, soft | ease-in-out sine, 300–500ms |
| bouncy, springy, playful | spring with visible overshoot (stiffness ~300, damping ~15) or `back.out(1.7)` |
| alive, with personality (but restrained) | slight overshoot: `back.out(1.1–1.3)` or spring stiffness ~300, damping ~22–26 |
| elegant, premium, editorial | ease-out quart/expo, 500–800ms, small distances (8–24px), often paired with blur-in |
| mechanical, precise, technical | linear or `steps()`, short durations |
| heavy, weighty, substantial | ease-out with longer duration (400–600ms) and slight anticipation |
| natural, physical, iOS-like | springs everywhere, velocity-aware, interruptible; no fixed-duration tweens |
| dramatic, cinematic | 600–1200ms, expo curves, orchestrated multi-element sequence |

## Duration bands

| Context | Duration |
|---|---|
| Micro-feedback (press, toggle, hover) | 100–200ms |
| Standard UI transition (dropdown, tooltip, tab) | 200–300ms |
| Entrances / overlays (modal, sheet, cards) | 300–500ms |
| Large-surface or spatial transitions (page, container transform) | 400–600ms |
| Hero / marketing / scroll moments | 600–1200ms |
| Scroll-scrubbed | no duration — progress mapping to scroll range |

Rules of thumb:

- **Exits run ~0.8× the entrance duration** with ease-in (or plain fade) — leaving should be quicker than arriving.
- **Scale duration with distance/size**: an element crossing the screen or a full-surface transition sits at the top of its band; a 16px nudge at the bottom.
- **Frequency discount**: the more often a user sees it, the shorter and quieter it must be. Delight belongs to rare moments.

## Stagger

| Context | Gap |
|---|---|
| Tight cluster (menu items, tags) | 20–40ms |
| Cards / list items | 50–80ms |
| Large sections / hero elements | 80–150ms |

Cap total stagger spread at ~600ms — beyond that the tail feels laggy. With many items, shrink the gap or stagger groups instead of items. Default order is DOM order; name it explicitly if reversed, from-center, or random.

## Spring cheat sheet

| Feel | stiffness / damping (motion, react-spring) | GSAP equivalent |
|---|---|---|
| Stiff & settled (default UI) | 400 / 30 | `power3.out` |
| Slight overshoot | 300 / 22 | `back.out(1.2)` |
| Visibly bouncy | 300 / 15 | `back.out(1.7)` |
| Wobbly / cartoon | 200 / 8 | `elastic.out(1, 0.4)` |

Springs have no duration — quote stiffness/damping (add mass only when deviating from 1). Pure CSS needs `linear()` approximations or a tween fallback; flag that in the brief's Constraints.

## Reduced motion mapping

| Full-motion effect | `prefers-reduced-motion` fallback |
|---|---|
| Slide / scale / pop entrances | opacity fade, 150–200ms |
| Parallax, scrubbed, pinned scenes | static layout, content simply present |
| Loops (float, pulse, marquee) | first frame, frozen |
| Shared element / container transform | crossfade |
| Attention shakes/bounces | border or color change |
