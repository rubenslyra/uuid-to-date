# UUID to Date

![Shell](https://img.shields.io/badge/shell-bash%204%2B-4EAA25?logo=gnubash&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20WSL%20%7C%20Windows-607D8B)
![RFC](https://img.shields.io/badge/RFC-9562-455A64)
![Tests](https://img.shields.io/badge/tests-58%20passing-2E7D32)
![License](https://img.shields.io/badge/license-MIT-546E7A)

Ferramenta de **engenharia reversa de UUID** conforme a **RFC 9562**: descobre se
um identificador é um UUID, qual a sua **versão** e **variante**, e traduz o
timestamp de 48 bits (`unix_ts_ms`) de um **UUIDv7** para data/hora UTC e local.

> Caso de uso: a partir do ID de um produto/pedido, descobrir a **hora da compra**
> embutida no UUIDv7 — sem consultar banco de dados.

## Por que isso funciona

O UUIDv7 (RFC 9562 §5.7) reserva os **primeiros 48 bits** para o
`unix_ts_ms` — milissegundos desde a época Unix (1970-01-01), em **big-endian**.
Isso torna o timestamp legível diretamente dos 12 primeiros caracteres
hexadecimais do UUID.

```
018f43a5-9280-7000-8000-000000000000
└──────┬──────┘
   unix_ts_ms (48 bits) = 0x018f43a59280 = 1714826875520 ms
                                        = 2024-05-04T12:47:55.520Z
```

UUIDs de outras versões (ex.: v4, aleatório) **não** carregam timestamp — os 48
bits iniciais são ruído. A ferramenta identifica isso e recusa calcular a data.

## Estrutura do repositório

```
uuid_to_date/
├── shell/          # implementação Unix/WSL/Git Bash  (main.sh + lib/)
├── windows/        # implementação Windows/PowerShell (main.ps1 + main.bat + lib/)
├── docs/           # documentação de referência (RFC 9562)
└── README.md       # este arquivo
```

Cada pasta de plataforma é **autocontida** (código, `data/`, `tests/` e README
próprios) e pode ser distribuída separadamente.

## Início rápido

**Shell (Linux/WSL/Git Bash):**
```bash
cd shell
./main.sh decode -u 018f43a5-9280-7000-8000-000000000000
./main.sh batch  -i data/lista_uuid.txt -o data/relatorio_datas.csv
```

**Windows (PowerShell):**
```bat
cd windows
main.bat decode -Uuid 018f43a5-9280-7000-8000-000000000000
main.bat batch  -InputFile data\lista_uuid.txt -OutputFile data\relatorio_datas.csv
```

Instruções detalhadas: [`shell/README.md`](shell/README.md) ·
[`windows/README.md`](windows/README.md).

Roteiro de aula (instrutor): [`docs/GUIA_DA_AULA.md`](docs/GUIA_DA_AULA.md).

## Testes

| Ambiente | Comando | Resultado |
|----------|---------|-----------|
| Shell | `bash shell/tests/run_tests.sh` | 30 PASS |
| Windows | `powershell -File windows/tests/run_tests.ps1` | 28 PASS |

Os testes usam **golden vectors** conhecidos (RFC 9562) e cobrem: UUIDv7 válido,
UUIDv4 recusado, entrada inválida, canais de dados, `NO_COLOR` e processamento
em lote.

## Propósito do estudo

Projeto didático para a disciplina de **Shell Script**: construir uma aplicação
real, modular e testável, com **arquivos separados por responsabilidade**
(bootstrap `main.*` + bibliotecas `lib/`), **canais de E/S customizáveis**
(File Descriptors 1/2/3) e **paridade entre ambientes** (shell e PowerShell).
Serve de base para reconstrução ao vivo em aula.

## Autor

**Rubens Lyra** — [@rubenslyra.ti](https://github.com/rubenslyra)

## Licença

MIT.
