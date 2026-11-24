#!/bin/bash
# Roda DENTRO do container namenode (o run.sh chama este script).
# Logs completos dos jobs ficam em resultados/*.log; o terminal mostra só o andamento.
set -e
set -o pipefail
cd /job
R=/job/resultados
mkdir -p $R

# Imagem é CentOS 7 antigo: costuma ter só "python" (2.7). Os scripts servem nos dois.
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
command -v $PY >/dev/null 2>&1 || { echo "ERRO: sem Python no container"; exit 1; }

STREAM=$(ls /opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -1)
# Splits de 4MB => vários mappers (senão um arquivo pequeno teria 1 só)
SPLIT=-Dmapreduce.input.fileinputformat.split.maxsize=4194304

roda() {   # roda "nome" comando...  -> saída completa em resultados/<nome>.log
  local nome="$1"; shift
  echo "   $nome"
  "$@" > $R/$nome.log 2>&1 || { echo "ERRO em $nome (últimas linhas):"; tail -25 $R/$nome.log; exit 1; }
}

echo "   Enviando o log ao HDFS (blocos de 16MB só para a demo; o padrão real é 128MB)"
hdfs dfs -mkdir -p /logs >/dev/null 2>&1
hdfs dfs -D dfs.blocksize=16777216 -put -f access.log /logs/access.log >/dev/null 2>&1
hdfs fsck /logs/access.log -files -blocks -locations > $R/hdfs_fsck.txt 2>&1
hdfs dfs -rm -r -f /out/job1_sem /out/job1_com /out/job2 >/dev/null 2>&1 || true

roda job1_sem_combiner hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=2 \
  -files mapper1.py,reducer1.py \
  -input /logs/access.log -output /out/job1_sem \
  -mapper "$PY mapper1.py" -reducer "$PY reducer1.py"

roda job1_com_combiner hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=2 \
  -files mapper1.py,reducer1.py \
  -input /logs/access.log -output /out/job1_com \
  -mapper "$PY mapper1.py" -combiner "$PY reducer1.py" -reducer "$PY reducer1.py"

roda job2_top10 hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=1 \
  -files mapper2.py,top10.py \
  -input /out/job1_com -output /out/job2 \
  -mapper "$PY mapper2.py" -combiner "$PY top10.py" -reducer "$PY top10.py"

hdfs dfs -cat /out/job1_sem/part-* 2>/dev/null | sort > $R/job1_sem.out
hdfs dfs -cat /out/job1_com/part-* 2>/dev/null | sort > $R/job1_com.out
hdfs dfs -cat /out/job2/part-*     2>/dev/null       > $R/top10.txt

bash /job/relatorio.sh
