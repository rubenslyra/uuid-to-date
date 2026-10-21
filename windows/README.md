# UUID to Date — Windows (PowerShell)

Implementação em **PowerShell** da engenharia reversa de UUID conforme a
**RFC 9562**. Extrai o `unix_ts_ms` (48 bits) de um UUIDv7 e traduz para
data/hora UTC e local.

## Requisitos

- Windows PowerShell 5.1 **ou** PowerShell 7+ (`pwsh`)
- Sem dependências externas

## Estrutura

```
windows/
├── main.ps1             # bootstrap: decode | batch | help
├── main.bat             # launcher (chama main.ps1 via pwsh ou powershell)
├── lib/
│   ├── uuid_core.ps1    # funções puras (RFC 9562)
│   ├── output.ps1       # paleta Slate + canais
│   ├── Decode-UUIDv7.ps1        # CLI unidade (standalone)
│   ├── Convert-FromUuid7.ps1    # CLI unidade (standalone)
│   └── Convert-UUIDv7Batch.ps1  # CLI lote (standalone)
├── data/
│   └── lista_uuid.txt   # entrada de exemplo para o lote
└── tests/
    └── run_tests.ps1    # golden master (28 vetores)
```

## Uso

```bat
REM Unidade — um UUID
main.bat decode -Uuid 018f43a5-9280-7000-8000-000000000000

REM Unidade — grava a linha CSV no arquivo
main.bat decode -Uuid <uuid> -DataFile data\linha.csv

REM Lote — arquivo de UUIDs -> relatório CSV
main.bat batch -InputFile data\lista_uuid.txt -OutputFile data\relatorio_datas.csv

REM Ajuda
main.bat help
```

Também é possível chamar direto pelo PowerShell:

```powershell
.\main.ps1 decode -Uuid <uuid>
.\main.ps1 batch  -InputFile data\lista_uuid.txt -OutputFile data\relatorio_datas.csv
```

### Canais

| Canal | Uso |
|-------|-----|
| stdout | relatório humano (colorido) |
| stderr | avisos e erros |
| `-DataFile <csv>` | dados de máquina (CSV) — equivalente ao FD 3 do shell |

```powershell
$env:NO_COLOR = 1        # desativa ANSI
```

## Códigos de saída

| Código | Significado |
|--------|-------------|
| 0 | UUIDv7 com timestamp plausível decodificado |
| 1 | Entrada inválida (formato) |
| 2 | Uso incorreto |
| 3 | UUID analisado, mas sem timestamp confiável (não-v7 ou fora de faixa) |

## Testes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_tests.ps1
```

Esperado: `28 PASS / 0 FAIL`.

## Notas

- UUIDs que não sejam v7 são identificados (versão + variante) e **recusados**
  para cálculo de data — os 48 bits iniciais são dado aleatório, não timestamp.
- Os scripts em `lib/` são CLIs standalone mantidas para uso direto; o
  `main.ps1` é o ponto de entrada recomendado.
