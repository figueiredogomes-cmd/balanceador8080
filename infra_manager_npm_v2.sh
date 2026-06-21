#!/usr/bin/env bash

set -e

APP_DIR="$HOME/docker-cluster"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

create_files() {

mkdir -p "$APP_DIR"

cat > "$COMPOSE_FILE" <<'EOF'
services:

  nginx:
    image: nginx:alpine
    container_name: nginx_lb
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
    container_name: app1
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
          requests:hits
        }));
      }).listen(3000);
      ' > server.js &&
      node server.js"

  app2:
    image: node:20-alpine
    container_name: app2
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
          requests:hits
        }));
      }).listen(3000);
      ' > server.js &&
      node server.js"

  app3:
    image: node:20-alpine
    container_name: app3
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
          requests:hits
        }));
      }).listen(3000);
      ' > server.js &&
      node server.js"
EOF

cat > "$APP_DIR/nginx.conf" <<'EOF'
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

}

up_stack() {
    create_files
    cd "$APP_DIR"
    docker compose up -d
    echo
    echo "Cluster iniciado."
    echo "Acesse:"
    echo "http://localhost:8080"
}

down_stack() {
    cd "$APP_DIR" 2>/dev/null || exit 0
    docker compose down -v
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
    *)
        echo
        echo "Uso:"
        echo
        echo "./cluster.sh up"
        echo "./cluster.sh down"
        echo "./cluster.sh start"
        echo "./cluster.sh stop"
        echo "./cluster.sh status"
        echo
        exit 1
        ;;
esac
