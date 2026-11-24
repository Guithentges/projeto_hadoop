#!/usr/bin/env python3
"""JOB 2 - COMBINER e REDUCER (mesmo script): mantém só os TOP N.
Entrada/Saída: top <TAB> n <TAB> bytes <TAB> url

Combiner: cada mapper manda só seus 10 melhores (não todas as URLs).
Reducer : entre os candidatos de todos os mappers, fica com os 10 globais.
Correto porque quem está no top 10 global está no top 10 local de algum mapper.
"""
import heapq
import sys

N = 10
candidatos = []                       # (n, bytes, url)

for line in sys.stdin:
    _, n, b, url = line.rstrip("\n").split("\t", 3)
    candidatos.append((int(n), int(b), url))
    if len(candidatos) > 4 * N:       # poda para não crescer sem limite
        candidatos = heapq.nlargest(N, candidatos)

for n, b, url in heapq.nlargest(N, candidatos):
    print(f"top\t{n}\t{b}\t{url}")
