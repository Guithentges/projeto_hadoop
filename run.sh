#!/bin/bash
# Uso:  ./run.sh        -> faz TUDO: gera log, sobe o cluster, roda os jobs e mostra os resultados
#       ./run.sh down   -> desliga o cluster
set -e
cd "$(dirname "$0")"

if [ "$1" = "down" ]; then docker compose down; exit 0; fi

docker info >/dev/null 2>&1 || { echo "ERRO: Docker não está rodando"; exit 1; }

espera() {   # espera "descrição" comando...   (máx. ~5 min)
  local desc="$1"; shift
  for i in $(seq 1 100); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 3
  done
  echo "ERRO: tempo esgotado esperando: $desc"; exit 1
}

echo ">> [1/5] Log de acessos..."
if [ ! -s access.log ]; then
  python3 gerar_logs.py 600000 > access.log
fi
echo "   $(wc -l < access.log) linhas em access.log"

echo ">> [2/5] Subindo cluster (1 NameNode, 3 DataNodes, ResourceManager, NodeManager)..."
docker compose up -d --scale datanode=3

echo ">> [3/5] Esperando HDFS e YARN ficarem prontos..."
espera "3 DataNodes vivos" bash -c 'docker compose exec -T namenode hdfs dfsadmin -report | grep -q "Live datanodes (3)"'
docker compose exec -T namenode hdfs dfsadmin -safemode wait
espera "NodeManager registrado" bash -c 'docker compose exec -T resourcemanager yarn node -list | grep -q "Total Nodes:1"'

echo ">> [4/5] Verificando Python no NodeManager (onde rodam mappers e reducers)..."
if ! docker compose exec -T nodemanager sh -c 'command -v python3 || command -v python' ; then
  echo "ERRO: nem python nem python3 no NodeManager"; exit 1
fi

echo ">> [5/5] Rodando os jobs MapReduce (leva alguns minutos)..."
docker compose exec -T namenode bash /job/run_hadoop.sh

echo
echo "=========================================================="
echo " PRONTO. Resultados em: resultados/RESULTADOS.md"
echo " HDFS (porta 9870) e YARN (porta 8088): veja a aba PORTAS"
echo " do Codespaces e clique no globo ao lado de cada porta."
echo " Para desligar: ./run.sh down"
echo "=========================================================="
