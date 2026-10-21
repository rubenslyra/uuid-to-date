# Guia da Aula — UUID to Date (Shell Script)

Documento de **treino do instrutor**. Roteiro para reconstruir o projeto ao vivo,
com objetivos de aprendizagem, ordem de execução, pontos de fala e exercícios.

---

## 1. Objetivos de aprendizagem

Ao final da aula, o aluno deve ser capaz de:

1. Explicar o que é um **UUID** e a diferença entre versões (v4 aleatório vs v7 com timestamp).
2. Ler a **RFC 9562** e localizar o campo `unix_ts_ms` (48 bits, big-endian).
3. Fazer **engenharia reversa** de um UUIDv7 para data/hora (UTC e local).
4. Estruturar um projeto shell **modular**: `main.*` (bootstrap) + `lib/` (bibliotecas).
5. Usar **File Descriptors** (0/1/2 e canais customizados 3–9) para separar
   saída humana de dados de máquina.
6. Escrever **testes golden master** e validar comportamento.
7. Entender **paridade entre ambientes** (shell vs PowerShell).

## 2. Pré-requisitos do ambiente

| Ambiente | Requisitos |
|----------|-----------|
| Linux/WSL/Git Bash | `bash` 4+, `date` com `-d @<epoch>` (GNU/uutils coreutils) |
| Windows | PowerShell 5.1 ou 7+ |

Verificação rápida:
```bash
bash --version | head -1
date -u -d '@1714826875' +'%Y-%m-%dT%H:%M:%S'   # deve imprimir 2024-05-04T12:47:55
```

## 3. Roteiro sugerido (90 min)

| Bloco | Tempo | Conteúdo |
|-------|-------|----------|
| 1. Contexto | 10 min | O problema: descobrir a hora da compra a partir do ID |
| 2. Teoria | 15 min | UUID, versões, RFC 9562, layout de 128 bits |
| 3. Anatomia | 10 min | Disecção de um UUIDv7 no quadro (48 bits) |
| 4. Código ao vivo | 30 min | Construir `lib/uuid_core.sh` → `main.sh` |
| 5. Canais | 10 min | FD 1/2/3, redirecionamento, `NO_COLOR` |
| 6. Testes | 10 min | Golden vectors, rodar a suíte |
| 7. Paridade | 5 min | Mostrar o equivalente em PowerShell |

## 4. Bloco 1 — Contexto (o gancho)

Pergunta para a turma:

> "Você tem o ID de um pedido: `018f43a5-9280-7000-8000-000000000000`.
> Sem consultar o banco, você consegue dizer **quando** ele foi criado?"

Resposta: **sim**, se for UUIDv7 — o timestamp está embutido nos primeiros 48 bits.

Contraexemplo (o erro clássico):
```
8426a8c8-3ca8-414f-ad50-f6147b9ceab2  ->  ano 6574 (!)
```
Esse é um **UUIDv4** (aleatório). Os 48 bits iniciais são ruído — não há timestamp.
**Lição:** sempre validar a versão antes de confiar no valor.

## 5. Bloco 2 — Teoria essencial

- UUID = 128 bits = 32 hexadecimais, exibidos como `8-4-4-4-12`.
- O **nibble de versão** é o 13º caractere (índice 12).
- O **nibble de variante** é o 17º caractere (índice 16): `8/9/a/b` = RFC 9562.
- **UUIDv7** (RFC 9562 §5.7):

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           unix_ts_ms                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          unix_ts_ms           |  ver  |       rand_a          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|var|                        rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                            rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- `unix_ts_ms` = milissegundos desde 1970-01-01, **big-endian** (os 12 primeiros hex).

## 6. Bloco 3 — Anatomia ao vivo

Escreva no quadro e resolva junto:

```
018f43a5-9280-7000-8000-000000000000
└────┬─────┘
 0x018f43a59280
```

1. Remover hífens → `018f43a5928070008000000000000000`
2. Pegar os 12 primeiros → `018f43a59280`
3. Converter hex → decimal → `1714826875520` ms
4. `1714826875520 / 1000` = `1714826875` s → **2024-05-04T12:47:55.520Z**

Confira no terminal:
```bash
printf '%d\n' 0x018f43a59280
date -u -d '@1714826875' +'%Y-%m-%dT%H:%M:%S'
```

## 7. Bloco 4 — Construção do código (ordem)

Construa **de baixo para cima**, testando cada camada:

1. **`lib/uuid_core.sh`** — funções puras:
   - `uuid_normalize` (remove hífens, valida 32 hex)
   - `uuid_version` / `uuid_version_name`
   - `uuid_variant`
   - `uuid_ts_hex` / `uuid_ts_ms`
   - `uuid_ts_plausible` (faixa 2022 → agora+24h)
   - `uuid_to_utc_iso` / `uuid_to_local_iso`
2. **`lib/output.sh`** — cores (paleta Slate) + `data()` no FD 3 + `NO_COLOR`.
3. **`main.sh`** — bootstrap com subcomandos `decode`, `batch`, `help`.

Pontos de fala importantes:
- `set -euo pipefail` no topo (rigor).
- `local ms=$1 sec=$((ms/1000))` **não funciona** com `set -u` — expanda em linhas separadas.
- `[[ ... ]] && continue` **aborta** o script com `set -e` — use `if ...; then continue; fi`.
- `printf '%s\n' "$*" >&"$OUT_DATA_FD"` — o canal de dados é variável.

## 8. Bloco 5 — Canais (File Descriptors)

Demonstre ao vivo:

```bash
./main.sh decode -u <uuid> 3>linha.csv      # CSV no FD 3
./main.sh decode -u <uuid> 1>/dev/null 3>&1 # só CSV
./main.sh decode -u <uuid> 2>erros.log      # diagnóstico em arquivo
NO_COLOR=1 ./main.sh decode -u <uuid>       # sem cores
```

Explique a "dança dos FDs": `exec 3>&1` guarda o stdout original antes de
redirecionar — mesma técnica usada pelo `dialog`/ncurses.

## 9. Bloco 6 — Testes

```bash
bash shell/tests/run_tests.sh
```

Mostre que os **golden vectors** travam o comportamento:
- A `018f43a5-…` → `2024-05-04T12:47:55.520Z`
- B `017f22e2-…` → `2022-02-22T19:22:22.000Z`
- C `8426a8c8-…` → v4, **recusado** (exit 3)

## 10. Bloco 7 — Paridade Windows

Mostre o mesmo resultado via PowerShell:
```bat
windows\main.bat decode -Uuid 018f43a5-9280-7000-8000-000000000000
powershell -File windows\tests\run_tests.ps1
```

## 11. Exercícios para os alunos

1. **Fácil:** adicionar um subcomando `version` que imprime a versão do UUID.
2. **Médio:** no `batch`, gerar também um resumo por dia (contagem de UUIDs).
3. **Médio:** aceitar UUIDs colados de um pipe (`cat ids.txt | ./main.sh batch -i -`).
4. **Difícil:** detectar UUIDs "forjados" (timestamp no futuro ou anterior a 2022).
5. **Difícil:** implementar o mesmo em PowerShell do zero e comparar saídas.

## 12. Perguntas frequentes da turma

- **"Por que 48 bits?"** → 48 bits de ms cobrem ~8.900 anos; suficiente e deixa
  74 bits para aleatoriedade/monotonicidade.
- **"E se o relógio da máquina estiver errado?"** → por isso existe o
  `uuid_ts_plausible`; timestamp fora de faixa é sinalizado.
- **"Por que big-endian?"** → ordenação lexicográfica dos UUIDs = ordenação
  temporal (útil para índices de banco).
- **"v4 tem timestamp?"** → não. Nunca. É 122 bits aleatórios.

## 13. Checklist do instrutor (antes da aula)

- [ ] `bash shell/tests/run_tests.sh` → 30 PASS
- [ ] `powershell -File windows/tests/run_tests.sh` → 28 PASS
- [ ] Terminal com fonte legível e cores ativas
- [ ] `data/lista_uuid.txt` com os 3 vetores + 1 linha inválida
- [ ] Quadro/editor pronto para desenhar o layout de 128 bits
- [ ] Repositório clonado e `git log` limpo para mostrar a estrutura

## 14. Referências

- RFC 9562 — *Universally Unique IDentifiers (UUIDs)*
- `docs/Padronizacoes_e_Documentacao_Oficial_UUIDv7.md`
- Michael Kerrisk — *The Linux Programming Interface* (cap. sobre File Descriptors)
- W. Richard Stevens — *Advanced Programming in the UNIX Environment*
