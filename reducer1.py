#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""JOB 1 - COMBINER e REDUCER (mesmo script; Python 2.7 e 3)
Entrada : url <TAB> n,bytes   (já ORDENADO por chave pelo Shuffle & Sort)
Saída   : url <TAB> soma_n,soma_bytes

Por que o mesmo script serve de Combiner e Reducer?
Somar é associativo e comutativo, e a saída tem o MESMO formato da entrada.
Então somar parcialmente no mapper (Combiner) e somar de novo no reducer
dá o mesmo resultado final, só que com muito menos dados na rede.
"""
from __future__ import print_function
import sys

atual = None
n_total = 0
bytes_total = 0

for line in sys.stdin:
    chave, valor = line.rstrip("\n").split("\t", 1)
    n, b = valor.split(",")
    if chave == atual:
        n_total += int(n)
        bytes_total += int(b)
    else:
        if atual is not None:
            print("%s\t%d,%d" % (atual, n_total, bytes_total))
        atual, n_total, bytes_total = chave, int(n), int(b)

if atual is not None:                 # não esquecer a última chave
    print("%s\t%d,%d" % (atual, n_total, bytes_total))
