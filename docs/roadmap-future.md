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

- **os_mon noise in the test output:** since `:os_mon` is started, every `mix test` run ends with "[os_mon] … Erlang has closed". Turn it off in the test environment (e.g. `config :os_mon, start_cpu_sup: false, start_memsup: false, start_disksup: false` in `config/test.exs`, or not starting the application) and adjust `system_dashboard_test.exs`, which expects the OS Data page link.
- **Sobelow skips are fingerprinted by line:** an accepted finding (`.sobelow-skips`) reappears as soon as its line moves (seen in `router.ex` for the CSP finding and in `demo.ex`). Document in `.sobelow-conf` / the developer docs how to re-mark (`mix sobelow --config --mark-skip-all` after reviewing that only moved findings are new), or find a less fragile way.

## Open questions

- *None right now.*

