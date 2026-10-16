---
title: System
roles: [administrator]
order: 140
---
**Administration → System** opens the [Phoenix LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard) in a new tab: a look into the running app, for administrators only. It has its own interface and no way back to the admin area; close the tab when you are done.

The values are live and not stored: the charts start empty when you open the page and fill while it stays open.

| Page | What it shows | What for |
|---|---|---|
| **Home** | Versions (Elixir, Erlang, Phoenix), uptime since the last start, memory and processes at a glance | Is the app running, and since when? |
| **OS Data** | CPU load, memory and disk space of the server | Is space running out (e.g. uploads or old Docker images)? |
| **Metrics** | Page response times, database query times, memory and run queues of the runtime, calls started and ended | Is the shop slow, and is it the database? |
| **Ecto Stats** | The database: table and index sizes, unused indexes, cache hit ratio, locks, long-running queries, vacuum statistics | Is the database growing, is an index missing, is a query stuck? |
| **WebRTC** | The connections of running video calls: bitrate, packet loss, round-trip time, the negotiated session descriptions (with the participants' IP addresses) | Is a call stuttering, and on which side? |
| **Memory Allocators**, **Applications**, **Processes**, **Ports**, **Sockets**, **ETS** | Runtime internals | Troubleshooting with developers |

Left out on purpose: environment variables (they hold secrets), the request logger, and actions such as killing processes or database connections. So the dashboard changes nothing.

In Docker, **OS Data** shows the server's CPU and memory, and the disks as the container sees them. How to free space is described under Operating → Maintenance.
