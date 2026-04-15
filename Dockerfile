# Multi-stage Dockerfile that builds the app as an Elixir release and
# copies only the runtime artefacts into the final image. Build locally
# with:
#
#   docker build -t localize-playground .
#   docker run --rm -p 4000:4000 -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
#     localize-playground

ARG ELIXIR_VERSION=1.20.0-rc.4
ARG OTP_VERSION=28.3.1
ARG DEBIAN_VERSION=bookworm-20241016-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build tools for native extensions.
RUN apt-get update -y && \
    apt-get install -y build-essential git && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# NOTE: the playground depends on sibling path projects (:localize,
# :localize_web, :calendrical). Either vendor them into the build
# context or switch to hex-published versions before building.
COPY ../localize /deps/localize
COPY ../localize_web /deps/localize_web
COPY ../calendrical /deps/calendrical

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile

RUN mix release

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
