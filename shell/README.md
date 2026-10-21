# UUID to Date — Shell (Unix / WSL / Git Bash)

Implementação em **shell script** (POSIX/bash) da engenharia reversa de UUID
conforme a **RFC 9562**. Extrai o `unix_ts_ms` (48 bits) de um UUIDv7 e traduz
para data/hora UTC e local.

## Requisitos

- `bash` 4+ (testado em bash 5.3)
- `date` com suporte a `-d @<epoch>` (GNU coreutils ou uutils coreutils)
- Ambiente: Linux, WSL ou Git Bash no Windows

## Estrutura

```
shell/
├── main.sh              # bootstrap: decode | batch | help
├── lib/
│   ├── uuid_core.sh     # funções puras (RFC 9562)
│   └── output.sh        # paleta Slate + canais FD 1/2/3
├── data/
│   └── lista_uuid.txt   # entrada de exemplo para o lote
└── tests/
    └── run_tests.sh     # golden master (30 vetores)
```

## Uso

```bash
# Unidade — um UUID
./main.sh decode -u 018f43a5-9280-7000-8000-000000000000

# Unidade — grava a linha CSV no arquivo
./main.sh decode -u <uuid> -o data/linha.csv

# Lote — arquivo de UUIDs -> relatório CSV
./main.sh batch -i data/lista_uuid.txt -o data/relatorio_datas.csv

# Ajuda
./main.sh help
```

### Canais customizáveis (File Descriptors)

| Canal | Uso |
|-------|-----|
| FD 1 (stdout) | relatório humano (colorido) |
| FD 2 (stderr) | avisos e erros |
| FD 3 (custom) | dados de máquina (CSV) |

```bash
./main.sh decode -u <uuid> 3>linha.csv          # CSV no FD 3
./main.sh decode -u <uuid> 1>/dev/null 3>&1     # somente CSV
./main.sh decode -u <uuid> 2>erros.log          # diagnóstico em arquivo
NO_COLOR=1 ./main.sh decode -u <uuid>           # sem cores
```

`-o <arquivo>` tem precedência sobre um `3>` externo.

## Códigos de saída

| Código | Significado |
|--------|-------------|
| 0 | UUIDv7 com timestamp plausível decodificado |
| 1 | Entrada inválida (formato) |
| 2 | Uso incorreto |
| 3 | UUID analisado, mas sem timestamp confiável (não-v7 ou fora de faixa) |

## Testes

```bash
bash tests/run_tests.sh
```

Esperado: `30 PASS / 0 FAIL`.

## Notas

- Os `.sh` devem usar fim de linha **LF**. Se clonar no Windows, rode
  `sed -i 's/\r$//' main.sh lib/*.sh tests/*.sh`.
- UUIDs que não sejam v7 são identificados (versão + variante) e **recusados**
  para cálculo de data — os 48 bits iniciais são dado aleatório, não timestamp.
