FROM node:20-alpine
WORKDIR /app

# 复制 package.json 文件
COPY package*.json ./

# 安装依赖（包括 sqlite3 需要的编译工具）
RUN apk add --no-cache python3 make g++ \
    && npm ci --only=production \
    && apk del python3 make g++

# 复制应用代码
COPY server-sqlite.js ./server.js

EXPOSE 8787
CMD ["node", "server.js"]