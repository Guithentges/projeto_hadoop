#!/bin/bash
# Lê os logs dos jobs e escreve resultados/RESULTADOS.txt (texto simples).
# Não depende do Hadoop: só dos arquivos em resultados/.
R="${R:-$(dirname "$0")/resultados}"
LOG_ORIG="${LOG_ORIG:-$(dirname "$0")/access.log}"
D="$R/detalhes"
SEM="$D/job1_sem_combiner.log"
COM="$D/job1_com_combiner.log"
OUT="$R/RESULTADOS.txt"

c() { grep -m1 "$2" "$1" | sed 's/.*=//' | tr -d ' \r'; }   # valor de um counter

pct() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN{ if (a>0) printf "%.2f", (1-b/a)*100; else print "n/d" }'; }
linha() { printf "%-48s %16s %16s\n" "$1" "$2" "$3"; }

RIN_SEM=$(c $SEM "Reduce input records");  RIN_COM=$(c $COM "Reduce input records")
SHUF_SEM=$(c $SEM "Reduce shuffle bytes"); SHUF_COM=$(c $COM "Reduce shuffle bytes")

H1=$(md5sum < $D/job1_sem.out | cut -d' ' -f1)
H2=$(md5sum < $D/job1_com.out | cut -d' ' -f1)
if [ "$H1" = "$H2" ]; then IGUAL="IDENTICA (o Combiner nao alterou o resultado)"; else IGUAL="DIFERENTE (investigar!)"; fi

TOTAL_LOG=$(wc -l < "$LOG_ORIG" 2>/dev/null || echo "?")
SOMA=$(awk -F'\t' '{split($2,a,","); s+=a[1]} END{print s+0}' $D/job1_com.out)

{
echo "RESULTADOS DO EXPERIMENTO - MapReduce com Hadoop (Grupo 10)"
echo "============================================================"
echo
echo "JOB 1: acessos e bytes por URL"
echo "------------------------------"
linha "Counter" "Sem Combiner" "Com Combiner"
linha "Linhas lidas (Map input records)" "$(c $SEM 'Map input records')" "$(c $COM 'Map input records')"
linha "Saida dos mappers (Map output records)" "$(c $SEM 'Map output records')" "$(c $COM 'Map output records')"
linha "Combine input records" "0" "$(c $COM 'Combine input records')"
linha "Combine output records" "0" "$(c $COM 'Combine output records')"
linha "Reduce input records (entregues pelo Shuffle)" "$RIN_SEM" "$RIN_COM"
linha "Reduce shuffle bytes" "$SHUF_SEM" "$SHUF_COM"
linha "URLs distintas (Reduce input groups)" "$(c $SEM 'Reduce input groups')" "$(c $COM 'Reduce input groups')"
linha "Map tasks lancadas" "$(c $SEM 'Launched map tasks')" "$(c $COM 'Launched map tasks')"
echo
echo "Reducao de registros no Shuffle: $(pct "$RIN_SEM" "$RIN_COM")%"
echo "Reducao de bytes no Shuffle:     $(pct "$SHUF_SEM" "$SHUF_COM")%"
echo
echo "VERIFICACOES DE CORRECAO"
echo "------------------------"
echo "Saida do Job 1 sem x com Combiner: $IGUAL"
echo "Soma dos acessos nas URLs: $SOMA  |  Linhas do log original: $TOTAL_LOG"
echo
echo "JOB 2: Top 10 URLs mais acessadas"
echo "---------------------------------"
printf "%-4s %12s %16s  %s\n" "#" "Acessos" "Bytes" "URL"
awk -F'\t' '{ printf "%-4d %12d %16d  %s\n", NR, $2, $3, $4 }' $D/top10.txt
echo
echo "HDFS (resumo do fsck)"
echo "---------------------"
grep -E "Total blocks|Average block replication|Under-replicated|Default replication|Corrupt blocks" $R/hdfs_fsck.txt | sed 's/^[ \t]*//'
echo "(detalhe dos blocos e DataNodes de cada replica: resultados/hdfs_fsck.txt)"
echo "(logs completos dos jobs e saidas intermediarias: resultados/detalhes/)"
} > $OUT
