#!/usr/bin/env python3
"""JOB 1 - MAPPER
Entrada : linhas de log no formato Apache/NCSA (Common Log Format)
Saída   : url <TAB> 1,bytes        ->  (k2, v2)

Hadoop Streaming: lê stdin linha a linha e escreve "chave<TAB>valor" no stdout.
"""
import re
import sys

LOG = re.compile(r'^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+)[^"]*" (\d{3}) (\d+|-)')

for line in sys.stdin:
    m = LOG.match(line)
    if not m:
        # contador customizado: aparece nos Counters do job no Hadoop
        sys.stderr.write("reporter:counter:logs,linhas_malformadas,1\n")
        continue
    ip, ts, metodo, url, status, tamanho = m.groups()
    url = url.split("?")[0]                      # ignora query string
    tamanho = 0 if tamanho == "-" else int(tamanho)
    print(f"{url}\t1,{tamanho}")
