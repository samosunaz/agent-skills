# Commit Conventions

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

- **type**: required — describes the category of change
- **scope**: optional but recommended — the area of the codebase affected
- **description**: required — imperative mood, lowercase, no period at end

## Valid Commit Types

| Type       | Purpose                                                   |
| ---------- | --------------------------------------------------------- |
| `feat`     | New feature                                               |
| `fix`      | Bug fix                                                   |
| `docs`     | Documentation changes                                     |
| `style`    | Code style changes (formatting, missing semicolons, etc.) |
| `refactor` | Code refactoring without feature changes                  |
| `perf`     | Performance improvements                                  |
| `test`     | Adding or updating tests                                  |
| `build`    | Build system or external dependency changes               |
| `ci`       | CI/CD configuration changes                               |
| `chore`    | Other changes that don't modify src or test files         |
| `revert`   | Revert previous commit                                    |

## Scopes

Scopes identify the area of the codebase affected by the change. They are project-specific.

### How to determine scopes

1. **Check commitlint config** — If the project has `commitlint.config.mjs` (or `.js`, `.ts`, `.json`), read it to find defined scopes.
2. **Check monorepo structure** — In monorepos (nx, turborepo, lerna), use package/app names as scopes.
3. **Use module/feature names** — For standalone projects, use logical areas: `auth`, `api`, `db`, `ui`, `config`, etc.

## Commit message guidelines

1. **Imperative mood**: "add feature" not "added feature" or "adds feature"
2. **Lowercase description**: "fix login redirect" not "Fix Login Redirect"
3. **No period at end**: "add user validation" not "add user validation."
4. **Be specific**: "fix null pointer in user lookup by email" not "fix bug"
5. **Body for context**: Use the body to explain **why**, not what (the diff shows what)
6. **50/72 rule**: Subject line ~50 chars, body wrapped at 72 chars

## Breaking changes

Use `!` after type/scope or add `BREAKING CHANGE:` footer:

```bash
feat(api)!: change authentication to OAuth2
```

## Staging best practices

- Always use `git add <specific-files>` — never `git add -A` or `git add .`
- Review what you're staging: unrelated files should go in separate commits
- Never commit files that contain secrets (`.env`, credentials, tokens)
