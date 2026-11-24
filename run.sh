#!/bin/bash
# Uso:  ./run.sh        -> faz TUDO e grava o resultado em resultados/RESULTADOS.txt
#       ./run.sh down   -> desliga o cluster
set -e
cd "$(dirname "$0")"

if [ "$1" = "down" ]; then docker compose down >/dev/null 2>&1; echo "Cluster desligado."; exit 0; fi

docker info >/dev/null 2>&1 || { echo "ERRO: Docker não está rodando"; exit 1; }

mkdir -p resultados/detalhes
LOGCMD=resultados/detalhes/comandos.log

quieto() {   # roda um comando sem poluir o terminal; só mostra a saída se falhar
  "$@" >> "$LOGCMD" 2>&1 || { echo "ERRO ao executar: $*"; tail -20 "$LOGCMD"; exit 1; }
}

espera() {   # espera "descrição" comando...   (máx. ~5 min)
  local desc="$1"; shift
  for i in $(seq 1 100); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 3
  done
  echo "ERRO: tempo esgotado esperando: $desc"; exit 1
}

: > "$LOGCMD"

echo "[1/5] Log de acessos"
[ -s access.log ] || python3 gerar_logs.py 600000 > access.log

echo "[2/5] Subindo o cluster"
quieto docker compose up -d --scale datanode=3

echo "[3/5] Aguardando HDFS e YARN"
espera "3 DataNodes vivos" bash -c 'docker compose exec -T namenode hdfs dfsadmin -report | grep -q "Live datanodes (3)"'
quieto docker compose exec -T namenode hdfs dfsadmin -safemode wait
espera "NodeManager registrado" bash -c 'docker compose exec -T resourcemanager yarn node -list | grep -q "Total Nodes:1"'

echo "[4/5] Verificando Python no NodeManager"
quieto docker compose exec -T nodemanager sh -c 'command -v python3 || command -v python'

echo "[5/5] Executando os jobs MapReduce (alguns minutos)"
docker compose exec -T namenode bash /job/run_hadoop.sh

echo "Concluído."
