ARG ELIXIR_VERSION=1.14.2
ARG OTP_VERSION=25.0.4
ARG DEBIAN_VERSION=bullseye-20220801-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

ARG APPLICATION="speed_daemon"

# set build ENV
ENV MIX_ENV="prod"

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# Install Hex and rebar3
RUN mix do local.hex --force, local.rebar --force

# Copy configuration from this app and all children
COPY config config

# Copy mix.exs and mix.lock from all children applications
COPY mix.exs ./
COPY apps/${APPLICATION}/mix.exs apps/${APPLICATION}/mix.exs
COPY apps/${APPLICATION}/mix.lock apps/${APPLICATION}/mix.lock
RUN mix do deps.get --only $MIX_ENV, deps.compile

# Copy lib for all applications and compile
COPY apps/${APPLICATION}/lib apps/${APPLICATION}/lib
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY apps/${APPLICATION}/rel apps/${APPLICATION}/rel
RUN mix release ${APPLICATION}

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

ENV APPLICATION="speed_daemon"

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel ./

USER nobody

ENV ERL_AFLAGS "-proto_dist inet6_tcp"

CMD ["/app/${APPLICATION}/bin/${APPLICATION}", "start"]
