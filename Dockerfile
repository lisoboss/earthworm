FROM node:22-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm config set registry https://registry.npmmirror.com \
  && npm install -g pnpm cross-env nuxt \
  && pnpm config set registry https://registry.npmmirror.com

FROM base AS build
COPY . /app
WORKDIR /app
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

FROM build AS apiBuild
COPY apps/api/.env apps/api/.env
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm build:server
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm deploy --filter=api --prod /prod/api

FROM build AS clientBuild
ARG CLARITY
ENV CLARITY=${CLARITY}
COPY apps/client/.env apps/client/.env
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm build:client
RUN mkdir -p /prod && cp -r apps/client/dist /prod/client

FROM base AS api
COPY --from=apiBuild /prod/api /prod/api
WORKDIR /prod/api
EXPOSE 3001
CMD [ "cross-env", "NODE_ENV=prod", "node", "dist/src/main" ]

FROM nginx:stable-alpine-slim AS client
COPY --from=clientBuild /prod/client /usr/share/nginx/html
EXPOSE 80
