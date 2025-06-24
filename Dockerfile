FROM elixir:1.18.1

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV MIX_ENV=dev

RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libsodium-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

COPY mix.exs mix.lock .formatter.exs ./
COPY native/ ./native/

RUN mix deps.get && mix deps.compile

COPY lib/ ./lib/
COPY priv/ ./priv/
COPY examples/ ./examples/

RUN mix compile

CMD ["iex", "-S", "mix"] 