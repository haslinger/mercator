---
title: Troubleshooting
order: 40
---
| Symptom | Cause and remedy |
|---|---|
| `docker compose` says a variable "is not set" | `.env` is missing or incomplete, see [Configuration](configuration.md) |
| The app restarts in a loop | `docker compose logs app` names the missing setting, e.g. `SMTP_RELAY` or `DEMO_ADMIN_PASSWORD` |
| The page loads but shows "reconnecting" | the reverse proxy does not pass WebSockets (`Upgrade`/`Connection` headers), or `PHX_HOST` does not match the domain |
| A call is answered but stays at "Connecting …" or shows "The connection failed." | the UDP packets do not arrive: `CALL_PUBLIC_HOST` missing, the range `CALL_PORT_RANGE` not forwarded in the router, or blocked by the firewall; or the customer's network blocks UDP (see [Video calls](calls.md)). The incident of the failed call lists the candidates both sides offered |
| The call area says it needs the microphone | the browser has no microphone or the permission was refused; camera and microphone also need HTTPS (except on `localhost`) and do not work inside embedding frames such as dev tools |
| HTTPS does not work from outside | ports 80 and 443 must reach the reverse proxy (port 80 is needed for the certificate); check router and firewall, and IPv6 if the domain has an AAAA record |
| Emails do not arrive | an incident with the SMTP error in its technical details; typical: the sender (`MAIL_FROM_ADDRESS`) is not allowed for the SMTP account, or the certificate check fails |
| Everybody is rate-limited at once | the app sees the proxy's address instead of the visitors': `TRUSTED_PROXIES` must contain the proxy's address or network (rate-limit incidents show the resolved IP) |
| A PDF fails | an incident with Typst's error; the email still goes out, without the PDF |
| `docker compose build` cannot pull the base image | adjust `UBUNTU_TAG` in the `Dockerfile` to a current tag (Elixir and Erlang as in `.tool-versions`) |
