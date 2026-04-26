# Multi-stage: pull tctl from the official Teleport image, then ship it
# with a Node.js runtime so we can wrap it behind a clean REST API.

FROM public.ecr.aws/gravitational/teleport-distroless:17.4.4 AS teleport

FROM node:20-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=teleport /usr/local/bin/tctl /usr/local/bin/tctl
COPY --from=teleport /usr/local/bin/tsh  /usr/local/bin/tsh
WORKDIR /app
COPY package.json server.js ./
EXPOSE 3500
CMD ["node", "server.js"]
