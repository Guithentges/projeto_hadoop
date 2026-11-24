#!/usr/bin/env python3
"""JOB 2 - MAPPER
Entrada : saída do Job 1  ->  url <TAB> n,bytes
Saída   : top <TAB> n <TAB> bytes <TAB> url

Chave constante "top": força TODOS os registros para o MESMO reducer,
que é o que precisamos para achar o ranking global.
"""
import sys

for line in sys.stdin:
    url, valor = line.rstrip("\n").split("\t", 1)
    n, b = valor.split(",")
    print(f"top\t{n}\t{b}\t{url}")
