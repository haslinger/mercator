#!/bin/sh
# Container entrypoint (DOCKER.md): migrations before every start; other
# commands go to the release, e.g. `docker compose exec app bin/mercator remote`.
set -eu

case "${1:-start}" in
  start)
    /app/bin/mercator eval "Mercator.Release.migrate()"
    exec /app/bin/mercator start
    ;;
  *)
    exec /app/bin/mercator "$@"
    ;;
esac
