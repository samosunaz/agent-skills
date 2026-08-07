# Motion Vocabulary

Canonical terms for naming animation and transition effects. Quote terms verbatim in briefs. When two terms compete, contrast them so the reader can pick.

## Contents

1. [Entrances & exits](#entrances--exits)
2. [Sequencing & timing](#sequencing--timing)
3. [Movement & transforms](#movement--transforms)
4. [State & view transitions](#state--view-transitions)
5. [Physics & feel](#physics--feel)
6. [Easing](#easing)
7. [Scroll-driven](#scroll-driven)
8. [Gestures & pointer](#gestures--pointer)
9. [Feedback & micro-interactions](#feedback--micro-interactions)
10. [Text & drawing](#text--drawing)
11. [Ambient & continuous](#ambient--continuous)
12. [Accessibility & performance](#accessibility--performance)

## Entrances & exits

- **Fade in / Fade out** — appear or disappear by animating opacity only.
- **Slide in / Slide out** — enter or leave by translating from/to off-screen or off-position (specify edge and distance).
- **Scale in / Scale out** — grow from smaller (typically 0.9–0.95) to full size on entry, or shrink on exit; usually paired with a fade.
- **Pop in** — scale-in with a slight overshoot past 1.0 before settling, so the element "snaps" into place.
- **Origin-aware animation** — the element animates from its trigger's position (a popover growing out of the button that opened it) instead of from its own center; set `transform-origin` accordingly.
- **Reveal** — content is progressively uncovered by animating a clip-path or mask rather than moving the element itself.
- **Wipe** — a reveal that sweeps across in one direction, like a curtain.
- **Blur in / Blur out** — entrance/exit that animates a blur filter alongside opacity, giving a focus-pull feel.
- **Enter / Exit** — generic names for the animations played when an element mounts or unmounts.

## Sequencing & timing

- **Duration** — how long one animation takes.
- **Delay** — time before an animation starts.
- **Stagger** — several items animate one after another with a small fixed gap, creating a cascade. Specify gap and order (DOM order, reverse, from-center, random).
- **Sequence** — animations that run strictly one after the other (B starts when A ends), unlike a stagger's overlap.
- **Orchestration / Choreography** — deliberate coordination of multiple animations so they read as one composed motion.
- **Keyframes** — explicit waypoints (0%, 50%, 100%) the engine interpolates between.
- **Tween / Interpolation** — generating the in-between frames from a start value to an end value.
- **Stepped animation** — motion quantized into discrete jumps (`steps()`), like a ticking countdown or sprite animation.
- **Fill mode** — whether the element holds the first/last keyframe's styles outside the animation window (`forwards`, `backwards`).
- **Timeline** — a master clock several animations attach to at offsets, enabling scrubbing and pausing as a unit.

## Movement & transforms

- **Translate** — move along X/Y (or Z) without affecting layout.
- **Scale** — resize proportionally (or per-axis) around the transform origin.
- **Rotate** — spin around the transform origin; 3D variants rotate around X/Y axes (card tilt, flip).
- **Skew** — shear distortion, often used subtly during fast motion to suggest velocity.
- **Transform origin** — the anchor point transforms happen around; the difference between "grows from center" and "grows from the corner".
- **Parallax** — layers translate at different rates, creating depth (see also *Parallax scrolling*).
- **Path animation** — an element travels along a defined curve (`offset-path`/motion path) instead of a straight line.

## State & view transitions

- **Crossfade** — two elements fade over each other in the same spot; no movement.
- **Morph** — one shape smoothly becomes another shape (Dynamic Island). Geometry changes, identity persists.
- **Shared element transition** — an element travels and transforms from its place in view A to its place in view B, carrying continuity across the change.
- **Container transform** — a card/button expands into the full surface it opens (list item → detail page); the container itself is the shared element.
- **Layout animation / FLIP** — elements animate smoothly to their new layout positions after a reflow (item added, list reordered), instead of jumping. FLIP is the measure-invert-play technique behind it.
- **View transition** — document-level snapshot transition between UI states or pages (View Transitions API).
- **Page transition** — any animated handoff between routes: crossfade, slide, or shared elements.
- **Expand / Collapse** — height (or size) animates open/closed, accordion-style.
- **Flip (3D)** — element rotates around its Y/X axis to show a back face — distinct from FLIP-the-technique.
- **Skeleton swap** — placeholder skeleton crossfades into loaded content.

## Physics & feel

- **Spring** — motion driven by stiffness/damping physics instead of a fixed duration; velocity-aware and naturally interruptible.
- **Bounce** — overshoots the target and oscillates a few times before settling.
- **Overshoot** — passes the target once and settles back; a single, restrained bounce.
- **Anticipation** — a small counter-movement before the main motion (pull back before launching forward).
- **Rubber-banding** — elastic resistance and snap-back when dragging past a boundary (iOS overscroll).
- **Inertia / Momentum** — motion continues after release, decelerating with friction (fling, momentum scroll).
- **Damping** — how quickly spring oscillation dies down; low damping = bouncy, high = settles quickly.
- **Stiffness** — how strongly a spring pulls toward its target; higher = faster, snappier.
- **Velocity transfer** — a gesture's release velocity feeds into the follow-up animation so the handoff feels continuous.

## Easing

- **Linear** — constant speed; reads mechanical. Right for marquees, spinners, scrub mappings.
- **Ease-out** — starts fast, decelerates into place. Default for entrances and user-triggered responses.
- **Ease-in** — starts slow, accelerates away. For exits only; feels sluggish on entrances.
- **Ease-in-out** — slow-fast-slow. For elements that move from one on-screen position to another.
- **Cubic-bezier / custom curve** — hand-tuned curve when the standard families don't hit the feel.
- **Expo / Quart / Sine (curve strength)** — how aggressive the deceleration is: sine = gentle, quart = pronounced, expo = dramatic.
- **Back easing** — built-in overshoot (`back.out(1.2)`-style): passes the target slightly and returns.
- **Elastic easing** — pronounced oscillating settle; the caricature end of bounce.

## Scroll-driven

- **Scroll-triggered** — fires once when an element crosses a viewport threshold; plays with its own duration.
- **Scroll-scrubbed** — animation progress is bound to scroll position; scrolling back reverses it. No duration — a progress mapping.
- **Reveal on scroll** — entrance (fade/slide/scale) triggered as content enters the viewport.
- **Pin / Sticky** — a section stays fixed while scroll continues, usually while a scrubbed animation plays out.
- **Parallax scrolling** — background/foreground layers scroll at different speeds for depth.
- **Scroll snap** — scrolling settles onto defined stops (carousels, full-page sections).
- **Progress indicator** — a bar/ring mapped to reading or task progress.
- **Sticky header transition** — header morphs (shrinks, gains background) as scroll passes a threshold.

## Gestures & pointer

- **Drag** — element follows the pointer/finger; specify constraints (axis, bounds) and release behavior.
- **Swipe** — quick directional flick that commits an action (dismiss, paginate).
- **Pull-to-refresh** — drag down past a threshold with rubber-banding, release to trigger.
- **Snap points** — positions a draggable settles to on release (bottom sheet half/full open).
- **Hover state** — pointer-over feedback: lift, tint, underline slide. Needs a touch-device fallback decision.
- **Press / Active state** — feedback while pressing, commonly scale down to ~0.97.
- **Magnetic / Cursor-follow** — element attracts toward or trails the cursor.
- **Tilt** — 3D perspective rotation tracking pointer position over a card.

## Feedback & micro-interactions

- **Micro-interaction** — a small single-purpose feedback animation (toggle flip, like burst, checkbox tick).
- **Ripple** — circular wave expanding from the tap/click point.
- **Shake** — quick horizontal oscillation signaling error or rejection.
- **Pulse** — rhythmic scale/opacity throb drawing attention or signaling live status.
- **Shimmer** — a highlight sweep across a skeleton placeholder while loading.
- **Toast entrance** — notification slides/pops in from an edge, auto-dismisses with an exit.
- **Success draw** — a checkmark or confirmation stroke draws itself in (see *Line draw*).
- **Confetti / Burst** — celebratory particle explosion for milestone moments.
- **Optimistic update** — UI animates to the success state immediately, before the server confirms.

## Text & drawing

- **Typewriter** — characters appear one by one.
- **Text scramble** — characters cycle through random glyphs before resolving.
- **Split-text stagger** — text split into chars/words/lines, each entering with a stagger.
- **Counter / Count-up** — a number tweens from 0 (or previous value) to its target.
- **Line draw** — an SVG stroke draws itself via dash-offset animation.
- **Marquee** — continuous horizontal loop of content, constant speed.
- **Text mask reveal** — lines rise into view from behind a clipping edge, typographic-editorial feel.

## Ambient & continuous

- **Idle / Ambient loop** — subtle perpetual motion (float, gradient drift) giving a scene life without a trigger.
- **Float** — slow vertical bobbing loop.
- **Breathe** — slow scale/opacity loop, calmer than a pulse.
- **Gradient shift** — background gradient slowly moves or rotates.
- **Ken Burns** — slow zoom/pan across a static image.

## Accessibility & performance

- **Reduced motion** — the `prefers-reduced-motion` fallback: replace movement with opacity, shorten or remove loops. Every brief must specify it.
- **Compositor-friendly properties** — `transform` and `opacity` animate on the GPU without reflow; anything touching layout (width, height, top/left) risks jank.
- **Jank** — visible stutter from dropped frames; the failure mode briefs guard against.
- **Layout thrash** — interleaved reads/writes of layout properties forcing repeated reflows.
- **FOUC / Flash of unstyled motion** — elements visibly render in their pre-animation state before the entrance kicks in; guard initial state in CSS, not JS.
