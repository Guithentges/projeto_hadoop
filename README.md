# Projeto Hadoop: MapReduce com HDFS, YARN e Combiner (Grupo 10)

Análise de logs de servidor web com **Hadoop Streaming (Python)** num cluster Docker:
1 NameNode, 3 DataNodes, 1 ResourceManager e 1 NodeManager.

## Como rodar (um comando)

```bash
./run.sh
```

Gera o log, sobe o cluster, roda os jobs e mostra a tabela de resultados.
Tudo fica salvo em `resultados/` (principal: `resultados/RESULTADOS.txt`).
Para desligar: `./run.sh down`.

No GitHub Codespaces, abra a aba **PORTAS** e clique no globo ao lado de:
- **9870**: HDFS (Datanodes; Utilities → Browse the file system → /logs/access.log mostra blocos e réplicas)
- **8088**: YARN (Applications mostra os jobs, o ApplicationMaster e os containers)

## O que cada arquivo faz

| Arquivo | Função |
|---|---|
| `gerar_logs.py` | Gera `access.log` (log sintético, distribuição cauda longa) |
| `mapper1.py` | Job 1, Map: `linha do log -> (url, "1,bytes")` |
| `reducer1.py` | Job 1, **Combiner e Reducer**: soma acessos e bytes por URL |
| `mapper2.py` | Job 2, Map: manda tudo para a chave `top` (um reducer só) |
| `top10.py` | Job 2, **Combiner e Reducer**: mantém só os 10 maiores |
| `run.sh` | Orquestra tudo (log, cluster, espera, jobs) |
| `run_hadoop.sh` | Roda dentro do NameNode: envia ao HDFS, executa os 3 jobs |
| `relatorio.sh` | Lê os counters e escreve `resultados/RESULTADOS.txt` |
| `docker-compose.yml`, `config` | Cluster Hadoop |

## Fluxo de dados (chave-valor)

```
Job 1:  (offset, linha) -> map -> (url, "1,bytes") -> combine -> shuffle & sort
        -> (url, lista de "n,bytes") -> reduce -> (url, "total,bytes")
Job 2:  (url, "total,bytes") -> map -> ("top", "total,bytes,url") -> combine (top 10 local)
        -> shuffle -> reduce (top 10 global)
```

## Experimento

Job 1 é executado **sem** e **com** Combiner. A comparação dos counters
(`Reduce input records`, `Reduce shuffle bytes`) mostra a redução do tráfego no
Shuffle, e o `md5sum` das saídas prova que o resultado é idêntico.

## Observações

- A imagem `apache/hadoop` é CentOS 7 (antigo). Ela traz Python 2.7; por isso os
  scripts são compatíveis com Python 2.7 e 3, e nada precisa ser instalado.
- O bloco do HDFS é reduzido para 16 MB só para a demo gerar vários blocos
  (o padrão real é 128 MB). Os splits são de 4 MB para gerar vários mappers.
- Para um log real (ex.: NASA-HTTP), coloque-o em `access.log` antes de rodar.
