FROM node:22-bookworm-slim AS node-toolchain

FROM node-toolchain AS frontend-build

WORKDIR /frontend

COPY src/admin-panel/package.json src/admin-panel/package-lock.json ./

RUN npm ci

COPY src/admin-panel ./

RUN npm run build

FROM ocaml/opam:debian-12-ocaml-4.14 AS base

WORKDIR /workspace

ENV OPAMSOLVERTIMEOUT=300 \
    OPAMYES=1

RUN sudo chown -R opam:opam /workspace

RUN sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      libev-dev \
      libgmp-dev \
      libpq-dev \
      libssl-dev \
      m4 \
      make \
      pkg-config \
      python3 \
      python3-fake-factory \
      postgresql-client \
 && sudo rm -rf /var/lib/apt/lists/*

COPY --chown=opam:opam comp_theory_toolkit.opam dune-project ./
COPY --chown=opam:opam vendor ./vendor

RUN opam install . --deps-only --with-test

FROM base AS dev

RUN sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends \
      gnupg \
 && sudo install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && sudo chmod a+r /etc/apt/keyrings/docker.gpg \
 && . /etc/os-release \
 && printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian %s stable\n' \
      "$(dpkg --print-architecture)" "$VERSION_CODENAME" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null \
 && sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends \
      docker-ce-cli \
      docker-compose-plugin \
 && sudo rm -rf /var/lib/apt/lists/*

COPY --from=node-toolchain /usr/local/ /usr/local/

CMD ["sleep", "infinity"]

FROM base AS build

COPY --chown=opam:opam . .

RUN opam exec -- dune build \
      apps/api/server.exe \
      apps/admincli/admincli.exe \
      apps/trafficctl/trafficctl.exe \
      apps/trafficd/trafficd.exe \
      apps/web/webapp.exe \
      apps/worker/worker.exe \
      @runtest

FROM debian:12-slim AS runtime

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      libev4 \
      libgmp10 \
      libpq5 \
      libssl3 \
      python3 \
      python3-fake-factory \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/scripts

COPY --from=build /workspace/_build/default/apps/api/server.exe /app/server
COPY --from=build /workspace/_build/default/apps/admincli/admincli.exe /app/admincli
COPY --from=build /workspace/_build/default/apps/trafficctl/trafficctl.exe /app/trafficctl
COPY --from=build /workspace/_build/default/apps/trafficd/trafficd.exe /app/trafficd
COPY --from=build /workspace/_build/default/apps/web/webapp.exe /app/webapp
COPY --from=build /workspace/_build/default/apps/worker/worker.exe /app/worker
COPY --from=build /workspace/scripts/mock_identity_faker.py /app/scripts/mock_identity_faker.py
COPY --from=build /workspace/scripts/mock_task_faker.py /app/scripts/mock_task_faker.py
COPY --from=build /workspace/openapi /app/openapi
COPY --from=build /workspace/sql /app/sql
COPY --from=frontend-build /frontend/dist /app/admin-panel

EXPOSE 8080
EXPOSE 8081

CMD ["/app/server"]
