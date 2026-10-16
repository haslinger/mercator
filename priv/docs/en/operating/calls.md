---
title: Video calls
order: 25
---
Consultants call customers right from the advice conversation: audio, video and screen sharing. The media runs through the app's own server, not a third-party service, and is not recorded.

For this to work from outside, three things are needed besides HTTPS:

1. **The public address:** `CALL_PUBLIC_HOST` in `.env`, usually the same name as `PHX_HOST`. Inside the container the app only knows its container address; with this setting it offers the public one to the browsers. The name is resolved again for every call, so a changing IP behind DynDNS is no problem.
2. **The UDP ports in the router:** the media does not go through the reverse proxy but straight to the UDP ports `CALL_PORT_RANGE` (default 50000–50049). Forward this range in the router to the server, with the same port numbers.
3. **The firewall:** Docker publishes the ports with its own rules, which take effect before ufw's; without further measures the range is open. With the [ufw-docker](https://github.com/chaifeng/ufw-docker) rules ufw decides, and one rule is enough, limited to the app container with its fixed address (`APP_IP`, default `172.30.0.10`):

```sh
sudo ufw route allow proto udp from any to 172.30.0.10 port 50000:50049
```

After changing `.env` or `docker-compose.yml`: `docker compose up -d`.

## Trying it out

Two browsers, one of them outside your own network (e.g. a phone on mobile data): start a conversation as a customer, take it at the sales desk and choose **Video call**. If the call stays at "Connecting …", the UDP packets do not arrive, see [Troubleshooting](troubleshooting.md).

## Bandwidth

Every picture goes once to the server and from there to the other side. A video call needs about 2–4 Mbit/s at the server in each direction, a shared screen more at times. On a home connection that is enough for one or two calls at once.

## What the app does not do

No TURN server: networks that block UDP entirely (some offices, hotels) cannot reach the call. If that happens often, a TURN server can be added.
