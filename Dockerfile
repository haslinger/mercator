# syntax=docker/dockerfile:1
#
# Builds the Mercator release (phase 8, docs/deployment-design.md, DOCKER.md).
# One image for every deployment: demo or customer shop is decided at runtime
# (MERCATOR_MODE, #48). The build needs no secrets; they come from .env at
# container start (config/runtime.exs).

# the versions of .tool-versions; check https://hub.docker.com/r/hexpm/elixir/tags
ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.1.1
ARG UBUNTU_TAG=noble-20260917
ARG TYPST_VERSION=0.15.1
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_TAG}"
ARG RUNNER_IMAGE="ubuntu:24.04"

# ---- Build stage ----
# libsctp1 (both stages): the Erlang VM loads it at start and otherwise logs
# "Failed open sctp dynamic library" (harmless, SCTP is not used)
FROM ${BUILDER_IMAGE} AS builder
ARG TYPST_VERSION

RUN apt-get update -y && apt-get install -y --no-install-recommends \
      build-essential git curl ca-certificates xz-utils libsctp1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Typst for the PDF documents (#104): the official Linux binary
RUN curl -fsSL "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" \
      | tar -xJ -C /tmp \
    && mv /tmp/typst-x86_64-unknown-linux-musl/typst /usr/local/bin/typst

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# deps first, so this layer is cached unless mix.exs/mix.lock change
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Tailwind and esbuild come as Mix tools (no Node/npm)
RUN mix assets.setup

COPY priv priv
COPY lib lib
# the documentation is compiled into the app (Mercator.Docs)
COPY docs docs
COPY assets/css assets/css
COPY assets/js assets/js
COPY assets/vendor assets/vendor
COPY assets/tsconfig.json assets/

# compile first: colocated LiveView hooks are extracted for esbuild
RUN mix compile
RUN mix assets.deploy
RUN mix release

# ---- Runtime stage ----
FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y && apt-get install -y --no-install-recommends \
      libstdc++6 openssl libncurses6 locales ca-certificates tzdata libsctp1 \
      fonts-noto-core fonts-dejavu-core \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV UPLOADS_DIR=/data/uploads
ENV DEMO_IMAGE_DIR=/app/demo-img

RUN useradd --create-home --shell /bin/bash mercator
WORKDIR /app

# the uploads volume is mounted here; created with the right owner so the
# named volume inherits it on first run
RUN mkdir -p /data/uploads && chown mercator:mercator /data/uploads

COPY --from=builder /usr/local/bin/typst /usr/local/bin/typst
COPY --from=builder --chown=mercator:mercator /app/_build/prod/rel/mercator ./
# demo photos, only used for seeding the demo (#44)
COPY --chown=mercator:mercator assets/img /app/demo-img
COPY --chown=mercator:mercator docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER mercator
EXPOSE 4000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["start"]
