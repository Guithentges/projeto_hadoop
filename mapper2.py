#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""JOB 2 - MAPPER  (Python 2.7 e 3)
Entrada : saída do Job 1  ->  url <TAB> n,bytes
Saída   : top <TAB> n <TAB> bytes <TAB> url

Chave constante "top": força TODOS os registros para o MESMO reducer,
que é o que precisamos para achar o ranking global.
"""
from __future__ import print_function
import sys

for line in sys.stdin:
    url, valor = line.rstrip("\n").split("\t", 1)
    n, b = valor.split(",")
    print("top\t%s\t%s\t%s" % (n, b, url))
