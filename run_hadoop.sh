#!/bin/bash
# Rode DENTRO do container namenode:  docker compose exec namenode bash /job/run_hadoop.sh
set -e
cd /job
PY=python3; command -v python3 >/dev/null || PY=python
STREAM=$(ls /opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-*.jar)
SPLIT=-Dmapreduce.input.fileinputformat.split.maxsize=2097152   # splits de 2MB => vários mappers

hdfs dfs -mkdir -p /logs
hdfs dfs -put -f access.log /logs/access.log
hdfs fsck /logs/access.log -files -blocks -locations   # mostra blocos, réplicas e DataNodes

hdfs dfs -rm -r -f /out/job1_sem /out/job1_com /out/job2

echo "=== JOB 1 SEM Combiner ==="
hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=2 \
  -files mapper1.py,reducer1.py \
  -input /logs/access.log -output /out/job1_sem \
  -mapper "$PY mapper1.py" -reducer "$PY reducer1.py" 2>&1 | tee job1_sem.log

echo "=== JOB 1 COM Combiner ==="
hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=2 \
  -files mapper1.py,reducer1.py \
  -input /logs/access.log -output /out/job1_com \
  -mapper "$PY mapper1.py" -combiner "$PY reducer1.py" -reducer "$PY reducer1.py" 2>&1 | tee job1_com.log

echo "=== JOB 2 (Top 10, encadeado na saída do Job 1) ==="
hadoop jar $STREAM $SPLIT -Dmapreduce.job.reduces=1 \
  -files mapper2.py,top10.py \
  -input /out/job1_com -output /out/job2 \
  -mapper "$PY mapper2.py" -combiner "$PY top10.py" -reducer "$PY top10.py"
hdfs dfs -cat /out/job2/part-*

echo; echo "=== Comparação dos Counters ==="
for f in job1_sem.log job1_com.log; do
  echo "--- $f"; grep -E "Map output records|Combine input records|Combine output records|Reduce input records|Reduce shuffle bytes|Launched map tasks" $f
done
