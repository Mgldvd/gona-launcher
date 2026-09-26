# Scope vocabulary

Generic, layer/area-based scope words for the `(<scope>)` part of a commit subject — see
`commit-standard.md` for the full format. Each entry describes an architectural concern common
to many projects, not a specific folder or module name from any one repo, so the same word means
the same thing wherever this convention is adopted. Sourced from
[`commit-convention`](https://github.com/Mgldvd/commit-convention); kept identical to
`commit-history-rewrite`'s copy.

**Rule:** max 8 characters each (keeps subjects short). English only.

If a commit doesn't fit any entry here, add the closest new one to this file instead of
inventing an ad-hoc word inline in the commit — that's what keeps the vocabulary shared and
reusable across projects instead of drifting into per-repo dialects. Keep entries generic
enough to apply outside the project that first needed them.

| Area | Scopes |
|---|---|
| UI / Frontend | `ui`, `layout`, `theme`, `a11y`, `forms`, `nav`, `icons` |
| Backend / API | `api`, `backend`, `server`, `router`, `endpoint`, `handler` |
| Data / Storage | `db`, `schema`, `cache`, `storage`, `migrate`, `query`, `model` |
| Auth / Security | `auth`, `security`, `perms`, `session`, `token`, `oauth` |
| CLI / Tooling | `cli`, `cmd`, `script`, `tooling` |
| Infra / Deploy | `infra`, `deploy`, `docker`, `network`, `ci`, `cdn`, `dns` |
| Config | `config`, `env`, `flags` |
| Dependencies | `deps` |
| Docs | `docs`, `readme`, `changes` |
| Tests | `tests`, `e2e`, `mock` |
| i18n | `i18n`, `locale` |
| Observability | `logs`, `metrics`, `tracing`, `alerts` |
| State | `state`, `store` |
| Build / Release | `build`, `release`, `bundler`, `package` |
| Messaging | `queue`, `events`, `pubsub` |
| Notifications | `notif`, `email`, `push` |
| Search | `search`, `index` |
| Media | `media`, `upload`, `image` |
| Networking | `http`, `ws`, `grpc` |
| Mobile | `mobile`, `ios`, `android` |
| Payments | `billing`, `payment` |
