# STE rewrite guide

Spoke of `/samuel:tldr`. Operational rules for rewriting prose to the Simplified Technical English standard.

Table of contents:

1. Jargon: keep vs replace
2. Deletion patterns
3. Sentence surgery
4. Before/after pairs
5. Self-check

## 1. Jargon: keep vs replace

"Tech jargon" is two different problems. One list stays. The other goes.

### Keep, in English, unexpanded

These name exactly one thing. A translation invents a second name for it, which is the failure this standard exists to prevent.

`PR` · `issue` · `branch` · `worktree` · `commit` · `squash` · `rebase` · `merge` · `rollback` · `deploy` · `CI` · `lint` · `gate` · `hook` · `endpoint` · `payload` · `schema` · `migration` · `cache` · `race condition` · `timeout` · `prompt` · `subagent` · `diff` · `stack trace`

Never write "solicitud de extracción", "rama", or "punto final".

### Replace or delete

These name nothing. Each one hides the fact the reader wants.

| Jargon | Use instead |
|---|---|
| leverage, utilize | usar |
| surface (verbo) | mostrar |
| streamline | simplificar |
| facilitate, enable, unlock | permitir, o borrar |
| architected | diseñé |
| delve into, deep dive | revisar |
| align on | acordar |
| circle back | volver a X el «fecha» |
| bandwidth | tiempo |
| low-hanging fruit | nombra la tarea |
| best practices | nombra la práctica |
| robust, solid, powerful | di qué resiste, o borrar |
| seamless, elegant, clean | borrar |
| comprehensive | da el alcance ("cubre los 12 endpoints") |
| significant, substantial | da el número |
| performant | da la métrica ("200 ms p95") |
| scalable | di hasta qué carga |
| production-ready | di qué falta |
| properly, correctly | borrar |
| in order to | para |
| basically, essentially | borrar |
| it's worth noting that | borrar |
| as mentioned above | nombra la cosa |
| at the end of the day | borrar |
| landscape, ecosystem (metáfora) | nombra el sistema real |

`orchestrate` is the edge case. Keep it when it names agent or workflow orchestration, which is a real thing in this stack (`/samuel:team-orchestrate`). Replace it with "coordinar" anywhere else.

## 2. Deletion patterns

| Pattern | Example | Action |
|---|---|---|
| Opener | "Voy a revisar el archivo para entender..." | Delete. Show the result. |
| Closer | "¿Quieres que también actualice los tests?" | Delete, unless it is a real blocking question. |
| Self-narration | "Ahora que ya leí `auth.ts`, veo que..." | Delete the clause, keep the finding. |
| Recap | Prose describing the diff shown above it | Delete. |
| Empty hedge | "Creo que probablemente esto podría..." | Delete the hedge, state the fact. |
| Filler adjective | "una solución robusta y elegante" | Delete both adjectives. |
| Motivational closer | "¡Listo para producción!" | Delete. |
| Tricolon | "rápido, simple y confiable" | Keep the one item that carries a fact. |
| Em dash | "El hook falla — el path no existe" | "El hook falla porque el path no existe." |

A real hedge survives, with its cause attached. "No corrí los tests, no sé si pasa" is precise. "Creo que debería funcionar" is not.

## 3. Sentence surgery

**Split a subordinated chain.**

- Before: "Dado que el worktree ya existe y el branch está creado, lo que procede sería correr el implement, aunque antes convendría validar que el contexto esté cargado."
- After: "El worktree y el branch ya existen. Verifica que el contexto esté cargado. Luego corre el implement."

**Name the referent.**

- Before: "Eso rompe lo anterior."
- After: "El rename de `parseUser` rompe el import en `auth.ts:14`."

**Put the condition first.**

- Before: "Abre un PR nuevo si el anterior ya está mergeado."
- After: "Si el PR anterior ya está mergeado, abre uno nuevo."

**Break the noun stack.**

- Before: "GitHub issue pipeline label sync workflow"
- After: "el workflow que sincroniza los labels `pipeline:*` de los issues"

**Give the number.**

- Before: "Varios tests fallaron."
- After: "Fallaron 3 tests de 41."

## 4. Before/after pairs

### Pair A: agent status report (español)

Before:

> Perfecto, ya terminé de implementar los cambios solicitados. Básicamente lo que hice fue refactorizar el módulo de autenticación para que sea más robusto y mantenible, aprovechando el patrón de repositorio que ya existía en el codebase. Esto debería mejorar significativamente la testabilidad. Cabe mencionar que también actualicé algunos tests que estaban fallando. ¿Te gustaría que revise algo más?

After:

> Refactoricé `auth/` al patrón repository que ya usaba `orders/`. Arreglé 4 tests que fallaban. No corrí el suite completo.

### Pair B: instructions (español)

Before:

> Para poder proceder correctamente con el deploy, sería recomendable que primero valides que el pipeline de CI haya pasado exitosamente, y una vez verificado eso, podrías considerar hacer el merge del PR, teniendo en cuenta que si hay conflictos habría que resolverlos antes.

After:

> Verifica que CI pasó. Si hay conflictos, resuélvelos primero. Luego mergea el PR.

### Pair C: diagnosis (english)

Before:

> After a comprehensive investigation of the codebase, it appears that the root cause is likely related to a race condition that surfaces when multiple concurrent requests attempt to leverage the same cache instance, which is not particularly robust under load.

After:

> `CacheStore.get` has a race condition at `cache.ts:88`. Two concurrent requests write the same key. The second write wins and drops the first result.

### Pair D: protected span (mixed)

Before:

> Basically you'll want to run the following command in order to properly reset things:
> ```bash
> git reset --hard origin/main
> ```
> This should essentially get you back to a clean state.

After:

> ```bash
> git reset --hard origin/main
> ```
> Este comando borra tus cambios locales.

The command block is identical in both. The prose around it changed. That is the rule.

### Pair E: the TL;DR block of a PR (english)

Structure and chips: `../../../reference/github-operations.md` § TL;DR. This pair is about the prose inside it.

Before:

> **What:** This PR implements the plan from #47, adding comprehensive support for a robust new caching layer.
> **Why:** To significantly improve performance.
> **Caveat:** There are a few things that could potentially be affected, and it's worth noting the migration should probably be run first.

After:

> **What:** Adds a Redis read-through cache to `GET /events/:id`.
> **Why:** That endpoint was 340 ms p95 and it fronts the event page.
> **Caveat:** Run migration `0031` before deploying. The cache key includes the tenant id.

`What` restates neither the title nor the issue number. `Why` carries the number the word "performance" was hiding. The vague `Caveat` became two facts a reviewer can act on.

## 5. Self-check

Run these 6 questions over the rewrite before printing it.

1. Does any sentence admit two readings?
2. Does every term appear with the same word every time?
3. Is any fact from the source missing?
4. Did I add a claim the source did not make?
5. Are all code blocks, commands, and paths byte-identical to the source?
6. Is the rewrite in the same language as the source?

A "yes" on 1, 3, or 4, or a "no" on 2, 5, or 6, means the rewrite is not done.
