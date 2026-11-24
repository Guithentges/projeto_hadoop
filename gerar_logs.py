#!/usr/bin/env python3
"""Gera um log sintético de servidor web (Common Log Format).
Uso: python3 gerar_logs.py [num_linhas] > access.log

As URLs seguem uma distribuição "cauda longa" (poucas URLs muito acessadas,
como em sites reais). É isso que faz o Combiner render bastante.
Para usar um log real (ex.: NASA-HTTP, 1995), basta colocar o arquivo
em access.log: o código funciona sem alteração.
"""
import random
import sys
from datetime import datetime, timedelta

n = int(sys.argv[1]) if len(sys.argv) > 1 else 600_000
random.seed(42)

urls = [f"/produtos/item{i}.html" for i in range(300)] + \
       ["/", "/index.html", "/login", "/carrinho", "/api/busca", "/img/logo.png"]
pesos = [1 / (i + 1) for i in range(len(urls))]        # estilo Zipf
status = [200] * 90 + [304] * 5 + [404] * 4 + [500]
t = datetime(2026, 11, 1, 0, 0, 0)

for _ in range(n):
    t += timedelta(seconds=random.randint(0, 2))
    ip = f"10.{random.randint(0,50)}.{random.randint(0,255)}.{random.randint(1,254)}"
    url = random.choices(urls, pesos)[0]
    st = random.choice(status)
    size = random.randint(200, 50000) if st == 200 else random.randint(0, 500)
    print(f'{ip} - - [{t:%d/%b/%Y:%H:%M:%S} -0300] "GET {url} HTTP/1.1" {st} {size}')
