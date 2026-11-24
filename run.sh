#!/bin/bash
# Uso:  ./run.sh          -> faz TUDO (gera log, sobe cluster, roda os jobs)
#       ./run.sh down     -> desliga o cluster
set -e
cd "$(dirname "$0")"

if [ "$1" = "down" ]; then docker compose down; exit 0; fi

command -v docker >/dev/null || { echo "ERRO: Docker não encontrado (abra o Docker Desktop)"; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERRO: Docker não está rodando (abra o Docker Desktop)"; exit 1; }

echo ">> [1/5] Gerando log de 2 milhões de linhas..."
if [ ! -s access.log ]; then
  if command -v python3 >/dev/null; then python3 gerar_logs.py 2000000 > access.log
  elif command -v python >/dev/null; then python gerar_logs.py 2000000 > access.log
  else docker run --rm -v "$PWD":/w -w /w python:3-slim sh -c "python gerar_logs.py 2000000 > access.log"; fi
else echo "   (access.log já existe, reaproveitando)"; fi

echo ">> [2/5] Subindo cluster (1 NameNode, 3 DataNodes, ResourceManager, NodeManager)..."
docker compose up -d --scale datanode=3

echo ">> [3/5] Esperando HDFS e YARN ficarem prontos..."
until docker compose exec -T namenode hdfs dfsadmin -report 2>/dev/null | grep -q "Live datanodes (3)"; do sleep 3; done
docker compose exec -T namenode hdfs dfsadmin -safemode wait
until docker compose exec -T resourcemanager yarn node -list 2>/dev/null | grep -q "Total Nodes:1"; do sleep 3; done

echo ">> [4/5] Verificando Python no NodeManager (onde rodam mappers/reducers)..."
if docker compose exec -T nodemanager python3 --version >/dev/null 2>&1; then echo "   python3 ok"
elif docker compose exec -T nodemanager python --version 2>&1 | grep -q Python; then echo "   python (2.7) ok - scripts são compatíveis"
else echo "ERRO: sem Python no NodeManager"; exit 1; fi

echo ">> [5/5] Rodando os jobs MapReduce..."
docker compose exec -T namenode bash /job/run_hadoop.sh

echo
echo "PRONTO. UIs:  HDFS http://localhost:9870   YARN http://localhost:8088"
echo "Para desligar: ./run.sh down"
