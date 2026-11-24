#!/bin/bash
# Roda DENTRO do container namenode (o run.sh chama este script).
# Tudo que interessa é salvo em /job/resultados (= pasta resultados/ do projeto).
set -e
set -o pipefail
cd /job
R=/job/resultados
mkdir -p $R

# Imagem é CentOS 7 antigo: costuma ter só "python" (2.7). Os scripts servem nos dois.
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
command -v $PY >/dev/null 2>&1 || { echo "ERRO: sem Python no container"; exit 1; }
echo "Usando interpretador: $PY"

STREAM=$(ls /opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -1)
# Splits de 4MB => vários mappers (senão um arquivo pequeno teria 1 só)
SPLIT=-Dmapreduce.input.fileinputformat.split.maxsize=4194304

echo "=== 1) HDFS: enviando o log (bloco de 16MB só para a demo; o padrão real é 128MB) ==="
hdfs dfs -mkdir -p /logs
hdfs dfs -D dfs.blocksize=16777216 -put -f access.log /logs/access.log
hdfs fsck /logs/access.log -files -blocks -locations > $R/hdfs_fsck.txt 2>&1
grep -E "Total blocks|Average block replication|Under-replicated|Default replication" $R/hdfs_fsck.txt || true

hdfs dfs -rm -r -f /out/job1_sem /out/job1_com /out/job2 >/dev/null 2>&1 || true

echo "=== 2) JOB 1 SEM Combiner ==="
hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=2 \
  -files mapper1.py,reducer1.py \
  -input /logs/access.log -output /out/job1_sem \
  -mapper "$PY mapper1.py" -reducer "$PY reducer1.py" 2>&1 | tee $R/job1_sem.log

echo "=== 3) JOB 1 COM Combiner ==="
hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=2 \
  -files mapper1.py,reducer1.py \
  -input /logs/access.log -output /out/job1_com \
  -mapper "$PY mapper1.py" -combiner "$PY reducer1.py" -reducer "$PY reducer1.py" 2>&1 | tee $R/job1_com.log

echo "=== 4) JOB 2 (Top 10, encadeado na saída do Job 1) ==="
hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=1 \
  -files mapper2.py,top10.py \
  -input /out/job1_com -output /out/job2 \
  -mapper "$PY mapper2.py" -combiner "$PY top10.py" -reducer "$PY top10.py" 2>&1 | tee $R/job2.log

hdfs dfs -cat /out/job1_sem/part-* | sort > $R/job1_sem.out
hdfs dfs -cat /out/job1_com/part-* | sort > $R/job1_com.out
hdfs dfs -cat /out/job2/part-*            > $R/top10.txt

bash /job/relatorio.sh
