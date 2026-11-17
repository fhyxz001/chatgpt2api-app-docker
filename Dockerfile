# syntax=docker/dockerfile:1

# 离线镜像：构建阶段就下载好固定提交的后端源码、uv 与 Python 3.13 依赖，
# 容器启动和运行时都不再需要联网。
FROM node:22-bookworm-slim

# curl 仅在配置下载代理时用于下载；ca-certificates 保证 HTTPS 校验可用。
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV CHATGPT2API_HOME=/data \
    CHATGPT2API_BIND_HOST=0.0.0.0 \
    NODE_ENV=production

COPY package.json ./
COPY lib ./lib
COPY scripts ./scripts
COPY src ./src
COPY web ./web
COPY README.md LICENSE ./

# 生成管理页面；项目没有运行时 npm 依赖，无需 npm install。
RUN node scripts/build.mjs

# 预置后端运行环境（uv、固定提交源码、隔离 Python 3.13 及依赖）。
# 需要代理构建时：
#   docker build --build-arg CHATGPT2API_DOWNLOAD_PROXY=http://127.0.0.1:7897 .
ARG CHATGPT2API_DOWNLOAD_PROXY=
RUN CHATGPT2API_DOWNLOAD_PROXY="$CHATGPT2API_DOWNLOAD_PROXY" \
      node scripts/manage-backend.mjs repair --data-dir /data \
 && rm -rf /data/downloads /data/uv-cache /data/admin-key

EXPOSE 38650 38651
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.CHATGPT2API_WEB_PORT||38651)+'/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["node", "scripts/launch.mjs"]
CMD ["--no-open"]
