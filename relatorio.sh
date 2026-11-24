#!/bin/bash
# Lê os logs dos jobs e monta resultados/RESULTADOS.md (tabela de counters + verificações).
# Não depende do Hadoop: só dos arquivos em resultados/.
R="${R:-$(dirname "$0")/resultados}"
LOG_ORIG="${LOG_ORIG:-$(dirname "$0")/access.log}"

c() { grep -m1 "$2" "$1" | sed 's/.*=//' | tr -d ' \r'; }   # valor de um counter

MAP_IN=$(c $R/job1_sem.log "Map input records")
MAP_OUT_SEM=$(c $R/job1_sem.log "Map output records")
MAP_OUT_COM=$(c $R/job1_com.log "Map output records")
CIN=$(c $R/job1_com.log "Combine input records")
COUT=$(c $R/job1_com.log "Combine output records")
RIN_SEM=$(c $R/job1_sem.log "Reduce input records")
RIN_COM=$(c $R/job1_com.log "Reduce input records")
SHUF_SEM=$(c $R/job1_sem.log "Reduce shuffle bytes")
SHUF_COM=$(c $R/job1_com.log "Reduce shuffle bytes")
GRP_SEM=$(c $R/job1_sem.log "Reduce input groups")
GRP_COM=$(c $R/job1_com.log "Reduce input groups")
MAPS=$(c $R/job1_com.log "Launched map tasks")

pct() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN{ if (a>0) printf "%.2f", (1-b/a)*100; else print "n/d" }'; }
RED_REG=$(pct "$RIN_SEM" "$RIN_COM")
RED_BYTES=$(pct "$SHUF_SEM" "$SHUF_COM")

H1=$(md5sum < $R/job1_sem.out | cut -d' ' -f1)
H2=$(md5sum < $R/job1_com.out | cut -d' ' -f1)
if [ "$H1" = "$H2" ]; then IGUAL="IDÊNTICO (o Combiner não alterou o resultado)"; else IGUAL="DIFERENTE (investigar!)"; fi

TOTAL_LOG=$(wc -l < "$LOG_ORIG" 2>/dev/null || echo "?")
SOMA=$(awk -F'\t' '{split($2,a,","); s+=a[1]} END{print s+0}' $R/job1_com.out)

{
echo "# Resultados do experimento"
echo
echo "## Job 1: acessos e bytes por URL"
echo
echo "| Counter | Sem Combiner | Com Combiner |"
echo "|---|---:|---:|"
echo "| Map input records (linhas lidas) | $MAP_IN | $(c $R/job1_com.log 'Map input records') |"
echo "| Map output records (saída dos mappers) | $MAP_OUT_SEM | $MAP_OUT_COM |"
echo "| Combine input records | 0 | $CIN |"
echo "| Combine output records | 0 | $COUT |"
echo "| **Reduce input records (o que o Shuffle entregou)** | **$RIN_SEM** | **$RIN_COM** |"
echo "| **Reduce shuffle bytes** | **$SHUF_SEM** | **$SHUF_COM** |"
echo "| Reduce input groups (URLs distintas) | $GRP_SEM | $GRP_COM |"
echo "| Map tasks lançadas | $(c $R/job1_sem.log 'Launched map tasks') | $MAPS |"
echo
echo "- **Redução de registros no Shuffle:** ${RED_REG}%"
echo "- **Redução de bytes no Shuffle:** ${RED_BYTES}%"
echo
echo "## Verificações de correção"
echo
echo "- Saída do Job 1 sem x com Combiner: $IGUAL"
echo "- Soma dos acessos nas URLs: $SOMA | linhas do log original: $TOTAL_LOG"
echo
echo "## Job 2: Top 10 URLs mais acessadas (formato: top, acessos, bytes, url)"
echo
echo '```'
cat $R/top10.txt
echo '```'
echo
echo "## HDFS (resumo do fsck)"
echo
echo '```'
grep -E "Total blocks|Average block replication|Under-replicated|Default replication|Corrupt" $R/hdfs_fsck.txt
echo '```'
echo "Detalhe dos blocos e dos DataNodes de cada réplica: resultados/hdfs_fsck.txt"
} > $R/RESULTADOS.md

cat $R/RESULTADOS.md
