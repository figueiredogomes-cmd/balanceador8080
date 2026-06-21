#!/usr/bin/env bash

set -e

APP_DIR="$HOME/balanceador8090"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
NGINX_FILE="$APP_DIR/nginx.conf"

create_files() {

mkdir -p "$APP_DIR"

cat > "$NGINX_FILE" << 'EOF'
events {}

http {

    upstream backend {
        server app1:3000;
        server app2:3000;
        server app3:3000;
    }

    server {

        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

cat > "$COMPOSE_FILE" << 'EOF'
services:

  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app1
      - app2
      - app3

  app1:
    image: node:20-alpine
    command: >
      sh -c "
      echo '
      const http=require(\"http\");
      let hits=0;
      http.createServer((req,res)=>{
        hits++;
        res.writeHead(200,{\"Content-Type\":\"application/json\"});
        res.end(JSON.stringify({
          app:\"app1\",
          requests:hits,
          status:\"online\"
        }));
      }).listen(3000);
      ' > server.js &&
      node server.js"

  app2:
    image: node:20-alpine
    command: >
      sh -c "
      echo '
      const http=require(\"http\");
      let hits=0;
      http.createServer((req,res)=>{
        hits++;
        res.writeHead(200,{\"Content-Type\":\"application/json\"});
        res.end(JSON.stringify({
          app:\"app2\",
          requests:hits,
          status:\"online\"
        }));
      }).listen(3000);
      ' > server.js &&
      node server.js"

  app3:
    image: node:20-alpine
    command: >
      sh -c "
      echo '
      const http=require(\"http\");
      let hits=0;
      http.createServer((req,res)=>{
        hits++;
        res.writeHead(200,{\"Content-Type\":\"application/json\"});
        res.end(JSON.stringify({
          app:\"app3\",
          requests:hits,
          status:\"online\"
        }));
      }).listen(3000);
      ' > server.js &&
      node server.js"
EOF

}

up_stack() {

create_files

cd "$APP_DIR"

docker compose up -d

echo
echo "======================================"
echo "Cluster iniciado"
echo "======================================"
echo
echo "URL:"
echo "http://localhost:8080"
echo

}

down_stack() {

cd "$APP_DIR" 2>/dev/null || exit 0

docker compose down -v --remove-orphans

}

start_stack() {

cd "$APP_DIR"

docker compose start

}

stop_stack() {

cd "$APP_DIR"

docker compose stop

}

status_stack() {

cd "$APP_DIR"

docker compose ps

}

logs_stack() {

cd "$APP_DIR"

docker compose logs -f

}

restart_stack() {

cd "$APP_DIR"

docker compose restart

}

case "$1" in

up)
    up_stack
    ;;

down)
    down_stack
    ;;

start)
    start_stack
    ;;

stop)
    stop_stack
    ;;

status)
    status_stack
    ;;

logs)
    logs_stack
    ;;

restart)
    restart_stack
    ;;

*)
    echo
    echo "Uso:"
    echo
    echo "./infra_manager_npm_v2.sh up"
    echo "./infra_manager_npm_v2.sh down"
    echo "./infra_manager_npm_v2.sh start"
    echo "./infra_manager_npm_v2.sh stop"
    echo "./infra_manager_npm_v2.sh restart"
    echo "./infra_manager_npm_v2.sh status"
    echo "./infra_manager_npm_v2.sh logs"
    echo
    exit 1
    ;;
esac
