# Documentação Técnica e Normativa: Engenharia Reversa de UUIDv7 (48-bit Timestamp)

Este documento reúne de forma exaustiva as padronizações internacionais, arquiteturas e especificações oficiais que governam o uso de timestamps de 48 bits codificados na estrutura de identificadores únicos globais, com foco no padrão contemporâneo **UUIDv7**.

---

## 1. Contexto e Justificativa Tecnológica

Historicamente, os sistemas Unix e POSIX utilizavam inteiros de 32 bits assinados para contabilizar segundos a partir da época inicial de 1º de janeiro de 1970. Esta abordagem gerou o conhecido problema crítico do ano 2038 (Y2038). A transição para estruturas com contagem de tempo estendida eliminou essa barreira.

No contexto de sistemas altamente distribuídos, bases de dados modernas e microserviços, surgiu a necessidade de identificadores que fossem simultaneamente:
1. **Universais e Únicos:** Improbabilidade matemática de colisão sem coordenação central.
2. **Ordenáveis por Tempo (Time-Ordered):** Melhoria drástica na performance de indexação de árvores B+ (B-Trees) em bancos de dados relacionais e NoSQL.

O **UUID Versão 7 (UUIDv7)** foi desenhado especificamente para suprir essa demanda, alocando os primeiros **48 bits** estritamente para o registro temporal.

---

## 2. Padrões Internacionais e Normas Oficiais

### RFC 9562 — Universally Unique IDentifiers (UUID)
Publicada em **maio de 2024** pelo Internet Engineering Task Force (IETF), a **RFC 9562** tornou obsoletas as históricas RFC 4122 e RFC 4122-bis. Ela define o padrão técnico definitivo para a criação, tratamento e representação de UUIDs na internet.

#### Seção 5.7: Layout e Alocação do UUIDv7
A especificação dita que o UUIDv7 é composto por uma cadeia binária estruturada sequencialmente da seguinte forma:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           unix_ts_ms                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          unix_ts_ms           |  ver  |          rand_a       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|var|                        rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                            rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

*   **`unix_ts_ms` (Bits 0 a 47):** Um inteiro de 48 bits, sem sinal, no formato big-endian, representando o número de milissegundos decorridos desde a Unix Epoch (1970-01-01T00:00:00Z), desconsiderando segundos intercalares.
*   **`ver` (Bits 48 a 51):** O campo de versão composto por 4 bits. Para o UUIDv7, este valor é obrigatoriamente binário `0111` (hexadecimal `0x7`).
*   **`rand_a` (Bits 52 a 63):** 12 bits pseudo-aleatórios adicionados para garantir entropia de unicidade.
*   **`var` (Bits 64 a 65):** O campo de variante composto por 2 bits. Definido obrigatoriamente como binário `10` para conformidade com a variante padrão do IETF.
*   **`rand_b` (Bits 66 a 127):** Os 62 bits finais inteiramente preenchidos com dados pseudo-aleatórios de alta entropia.

### ISO 8601-1:2019 e ISO 8601-2:2019
Norma técnica internacional da *International Organization for Standardization* (ISO) que dita os critérios mundiais para a representação de elementos de data e hora. 
*   **Intercambialidade:** A extração do timestamp binário e sua respectiva decodificação de strings hexadecimais geram strings legíveis em formato estendido. O script PowerShell gera saídas estritamente compatíveis com este padrão (ex: `YYYY-MM-DDTHH:mm:ss.fffZ`).
*   **RFC 3339:** Perfil simplificado e restrito da ISO 8601 aplicado diretamente em protocolos de internet e APIs.

### ITU-T Rec. X.667 / ISO/IEC 9834-8
Padronização conjunta internacional focada nos procedimentos operacionais e técnicos de registro e geração de identificadores de forma livre de colisões. Mantém total paridade com as especificações técnicas da IETF.

---

## 3. Comportamento Temporal dos 48 Bits

Diferente de um número inteiro de 32 bits (que satura no ano 2038), e de um inteiro cheio de 64 bits (que cobre escalas cosmológicas), a escolha de um contador de **48 bits baseado em milissegundos** fornece um equilíbrio matemático ideal entre economia de espaço binário e longevidade operacional.

### Limite Matemático
*   **Capacidade Máxima:** $2^{48} - 1 = 281.474.976.710.655$ milissegundos.
*   **Conversão para Anos:** Aproximadamente $8.921$ anos de autonomia operacional contínua a partir de 1970.
*   **Ano de Esgotamento do UUIDv7:** O estouro do contador binário (`unix_ts_ms`) ocorrerá precisamente no ano de **8921 d.C.**

---

## 4. Engenharia Reversa e Mapeamento de Memória

A extração da data a partir de um UUIDv7 serializado em texto canônico funciona isolando estritamente os primeiros 12 caracteres hexadecimais, uma vez que cada caractere em hexadecimal representa 4 bits em representação de memória ($12 	imes 4 = 48	ext{ bits}$).

### Tabela de Mapeamento Estrutural do Texto Canônico

| Grupo Hexadecimal | Tamanho (Caracteres) | Bits Equivalentes | Significado no Padrão UUIDv7 |
| :--- | :--- | :--- | :--- |
| **Primeiro (Parte 1)** | 8 caracteres | 32 bits | Alta magnitude do Timestamp (`unix_ts_ms`) |
| **Segundo (Parte 2)** | 4 caracteres | 16 bits | Baixa magnitude do Timestamp (`unix_ts_ms`) |
| **Terceiro** | 4 caracteres | 16 bits | 4 bits de Versão (`0x7`) + 12 bits de Entropia (`rand_a`) |
| **Quarto** | 4 caracteres | 16 bits | 2 bits de Variante (`0x2`) + 14 bits de Entropia (`rand_b`) |
| **Quinto** | 12 caracteres | 48 bits | 48 bits finais de Entropia pura (`rand_b`) |

### Passo a Passo de Decodificação em Baixo Nível
1. **Limpeza da String:** Remove-se todos os delimitadores lógicos (hífens `-`).
2. **Isolamento de Janela de Memória:** Copia-se a substring localizada do índice `0` ao `11` (totalizando os 12 caracteres primordiais).
3. **Conversão de Base Numérica:** Executa-se a conversão da base hexadecimal (Base 16) para inteiro decimal (Base 10) sem sinal de 64 bits (`Int64`).
4. **Alinhamento de Escala Temporal:** Divide-se o valor decimal por $1.000$ para obter a contagem integral de segundos Unix, reservando o resto aritmético como fração de milissegundos.
5. **Mapeamento de Fuso Horário:** Transforma-se o carimbo Unix relativo ao Meridiano de Greenwich (UTC 0) para o fuso horário local utilizando tabelas de fuso geográfico (`tzdata` no Linux ou chaves de registro `TimeZoneInfo` no ecossistema Microsoft Windows).

---

*Nota legal: Este documento serve apenas para fins de referência de engenharia de software e análise de sistemas.*
