FROM node:22-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm config set registry https://registry.npmmirror.com \
  && npm install -g pnpm cross-env \
  && pnpm config set registry https://registry.npmmirror.com

FROM base AS build
COPY . /app
WORKDIR /app
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm build:server
RUN pnpm deploy --filter=api --prod /prod/api 
RUN pnpm build:client
RUN cp -r apps/client/.output/public /prod/client 

FROM base AS api
COPY --from=build /prod/api /prod/api
WORKDIR /prod/api
EXPOSE 3001
CMD [ "cross-env", "NODE_ENV=prod", "node", "dist/src/main" ]

FROM base AS client
COPY --from=build /prod/client /prod/client
WORKDIR /prod/client
EXPOSE 3000
CMD [ "npx", "serve" ]
