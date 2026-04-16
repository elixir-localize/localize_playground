# Multi-stage Dockerfile that builds the app as an Elixir release and
# copies only the runtime artefacts into the final image.
#
#   fly deploy

ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.2
ARG DEBIAN_VERSION=bookworm-20260202-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential git && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

ENV MIX_ENV=prod
ENV HOME=/app
# Cap schedulers and compile concurrency to keep peak memory in check.
# +S 1:1 = single scheduler, +MBas aobf = best-fit allocator (lower peak).
ENV ERL_FLAGS="+S 1:1 +MBas aobf +MBlmbcs 512"
ENV ELIXIR_ERL_OPTIONS="+S 1:1"

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod

COPY rel rel
COPY priv priv
COPY lib lib
COPY assets assets

# Single compile step to avoid duplicate CLDR data loading across layers.
RUN mix deps.compile && mix compile && mix assets.deploy

# Download the Astro ephemeris data (required by calendrical).
RUN mix astro.download_ephemeris

RUN mix release

# --- Runtime image ---
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/localize_playground ./

USER nobody

ENV PORT=4000
ENV PHX_HOST=localhost

EXPOSE 4000

CMD ["/app/bin/server"]
