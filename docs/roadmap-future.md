# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

Phases 1–9 are done (see [roadmap-history.md](roadmap-history.md)).

*No phase planned right now.*

## Postponed

- **Audio/video and screen sharing** in the advice chat (#100, from phase 6); possible self-hosted with `ex_webrtc`.

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- **Preselect a newly saved address in the checkout:** a customer who already has an address and adds another one from the checkout ("Manage addresses", `return_to`) without ticking a default comes back to the old address still selected. Preselect the address just saved, e.g. by passing its id back (`/checkout?billing=…`) or by remembering it in the checkout params.
- **os_mon noise in the test output:** since `:os_mon` is started, every `mix test` run ends with "[os_mon] … Erlang has closed". Turn it off in the test environment (e.g. `config :os_mon, start_cpu_sup: false, start_memsup: false, start_disksup: false` in `config/test.exs`, or not starting the application) and adjust `system_dashboard_test.exs`, which expects the OS Data page link.
- **Sobelow skips are fingerprinted by line:** an accepted finding (`.sobelow-skips`) reappears as soon as its line moves (seen in `router.ex` for the CSP finding and in `demo.ex`). Document in `.sobelow-conf` / the developer docs how to re-mark (`mix sobelow --config --mark-skip-all` after reviewing that only moved findings are new), or find a less fragile way.

## Open questions

- **#134 Database page in the LiveDashboard:** add `ecto_psql_extras` (new dependency) so `/admin/system` shows slow queries, table and index sizes, index usage and locks? Read-only, administrators only; today the Ecto page is left out (`ecto_repos: []`).
- **#135 Metrics history in the LiveDashboard:** keep the last minutes of the metrics in memory (a small buffer process, `metrics_history:`) so the charts are not empty on every page load? Lost on restart; no database.
- **#136 Log rate-limit hits:** besides the incident (#126), write a `Logger.warning` with bucket and client IP for every limit reached, so `docker compose logs` and tools like fail2ban can see them? (Offered in the rate-limit session, unanswered.)
