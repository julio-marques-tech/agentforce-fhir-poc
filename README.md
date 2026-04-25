'''# ELO Platform — POC Motor de Validação FHIR com IA
> **SPMS · MCDT sem Requisição · POC v2.2**  
> Plataforma de validação de conformidade FHIR R4 para o fluxo de Partilha de Resultados MCDT (Meios Complementares de Diagnóstico e Terapêutica) sem requisição prévia.

---

## 📋 Descrição

Esta POC implementa um **motor de validação multicamada** para mensagens FHIR R4 trocadas entre software de fabricante e os sistemas centrais da SPMS (PNB/BDNR). O objetivo é permitir que equipas técnicas validem os seus payloads FHIR antes de integrarem com os ambientes reais.

A plataforma combina:
- **Validação estrutural** via HL7 FHIR Validator (`.jar`)
- **Validação determinística** por regras configuráveis campo a campo
- **Validação semântica com IA** — motor local heurístico ou Anthropic Claude (cloud)

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Backend | Python + Flask | 3.x / Flask 3.x |
| CORS | flask-cors | — |
| Frontend | HTML5 + Vanilla JS + CSS3 | — |
| Validação Estrutural | HL7 FHIR Validator CLI | 6.9.6 |
| Runtime FHIR Validator | Java (JDK/JRE) | 21+ |
| IA Cloud (opcional) | Anthropic Claude claude-sonnet-4 | API |
| IA Local (fallback) | Motor heurístico Python built-in | — |
| Persistência | JSON flat-file (`custom_tests.json`) | — |
| FHIR Standard | HL7 FHIR R4 | 4.0.1 |
| Pacotes FHIR | hl7.terminology.r4, hl7.fhir.uv.extensions.r4 | cache local |

### Ficheiros principais
```
├── server.py              # Backend Flask — toda a lógica de validação
├── static/
│   └── index.html         # Frontend SPA
├── validator_cli.jar      # HL7 FHIR Validator (não incluído no git)
├── taxonomy_constants.py  # Taxonomia de categorias, vocabulário e IDs
├── custom_tests.json      # Casos de teste customizados (gerado em runtime)
└── uploads/               # Ficheiros de evidência temporários
```

---

## 🔌 Endpoints da API

### Validação

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `POST` | `/api/validate` | **Endpoint principal** — executa validação completa (determinística + IA + .jar) de um caso de teste |
| `POST` | `/api/validate-payload` | Validação rápida de estrutura FHIR sem caso de teste (suporta JSON e XML) |

#### `POST /api/validate` — Campos do form-data
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `testid` | string | ID do caso de teste (ex: `TST-01-AA-S1`) |
| `httpstatus` | int | HTTP status da resposta submetida |
| `responseTimems` | int | Tempo de resposta em ms |
| `payload` | string | Payload FHIR em JSON ou XML |
| `rulesoverride` | JSON string | Sobrepõe as regras do caso de teste (opcional) |
| `files[]` | file | Ficheiros de evidência (.json, .xml, .txt, .log, .jpg, .png, .mp4) |

---

### Suite de Testes

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/api/test-suite` | Devolve a suite de testes base (MCDT-CT-2025 v2.2) |
| `GET` | `/api/suite` | Devolve suite completa incluindo casos customizados |
| `GET` | `/api/operators` | Lista de operadores de regras disponíveis |
| `GET` | `/api/taxonomy` | Categorias, vocabulário e descrições de cenários |

---

### Casos de Teste Customizados

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/api/test-cases` | Lista todos os casos customizados persistidos |
| `POST` | `/api/test-cases` | Cria novo caso de teste customizado |
| `DELETE` | `/api/test-cases/<testid>` | Remove um caso de teste customizado |

---

### Sistema / Diagnóstico

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/api/ai-mode` | Modo IA activo (`local`, `cloud`, `auto`) e se tem chave Anthropic |
| `GET` | `/api/jar-status` | Estado do `validator_cli.jar` e disponibilidade do Java |
| `GET` | `/` | Serve o frontend (`static/index.html`) |

---

## 🧠 Inteligência Artificial — Como Funciona

### Arquitectura de 3 camadas de validação

```
Payload FHIR
     │
     ▼
┌─────────────────────────────┐
│  Camada 1 — .jar HL7        │  Validação estrutural FHIR R4 oficial
│  validator_cli.jar          │  Detecta erros de schema, constraints,
│  HL7 FHIR Validator 6.9.6   │  cardinalidades, terminologias
└─────────────────────────────┘
     │
     ▼
┌─────────────────────────────┐
│  Camada 2 — Determinística  │  Regras campo a campo configuráveis
│  Motor de Regras Python     │  FHIR path resolution + operadores
│  (evaluate_rule)            │  eq, contains, isnull, regex, lt/gt...
└─────────────────────────────┘
     │
     ▼
┌─────────────────────────────┐
│  Camada 3 — IA Semântica    │  Análise contextual inteligente
│  Local heurístico OU        │  Deteta anomalias semânticas que as
│  Anthropic Claude (cloud)   │  regras determinísticas não capturam
└─────────────────────────────┘
```

---

### Camada 3 — Motor IA Semântico

#### Modo `local` (sem custo, sem API)
O motor local (`local_ai_semantic_validate`) é um sistema heurístico em Python puro que simula análise de LLM. Executa as seguintes verificações:

1. **Heurística de IDs técnicos** — detecta se campos de ID (`.id`) contêm nomes humanos em vez de identificadores lógicos FHIR. Usa regex para identificar padrões de nome próprio (`João Silva`, `Maria Costa`, etc.)

2. **Validação de Logical ID** — verifica se IDs respeitam o padrão FHIR `[A-Za-z0-9\-\.]{1,64}`

3. **Coerência HTTP ↔ Severity** — para HTTP 401/403, valida que o `OperationOutcome.issue[].severity` é `fatal` ou `error` (incoerência semântica se for `warning`)

4. **Proporção de entries por tipo de erro** — um cenário de erro (4xx) com muitas entries é sinalizado como suspeito

5. **Semantic Hints do gestor de regras** — regras com campo `semanticHint` preenchido são processadas como instruções para o motor heurístico, permitindo extensão dinâmica sem alterar código

6. **Scoring de confiança** — calcula `confidence` entre 0.0 e 1.0 com base no número de issues/anomalias vs positives, produzindo veredicto `PASS / FAIL / NEEDSREVIEW`

#### Modo `cloud` (Anthropic Claude)
Quando `ANTHROPIC_API_KEY` está configurada, o payload + regras + evidências são enviados ao modelo `claude-sonnet-4-20250514` com um system prompt estruturado. O Claude devolve JSON com `semanticPass`, `confidence`, `issues`, `positives`, `metadataAnomalies` e `recommendation`.

#### Modo `auto` (padrão)
Tenta cloud; se a chave não existir ou falhar, cai automaticamente para o motor local. O frontend indica sempre qual modo está activo.

---

### Operadores de Regras Disponíveis

| Operador | Descrição | Exemplo |
|----------|-----------|---------|
| `eq` | Igual a | `fatal` |
| `noteq` | Diferente de | `HC` |
| `contains` | Contém substring | `Invalid username` |
| `notcontains` | Não contém | `error` |
| `startswith` | Começa com | `PNB-` |
| `isnull` | Nulo / ausente | — |
| `notnull` | Existe e não nulo | — |
| `gt` / `lt` | Maior / Menor que (numérico) | `5000` |
| `regex` | Expressão regular | `[0-9]+` |
| `matchesMsgHeaderId` | Identifier == MessageHeader.id | — |
| `semantic` | Avaliação delegada à IA | Descreva comportamento esperado |

---

## 📁 Suite de Testes Base (MCDT-CT-2025 v2.2)

| Grupo | Código | Título |
|-------|--------|--------|
| **AA** Autenticação | TST-01 | Credencial inválida (403) |
| **AA** Autenticação | TST-02 | Sem permissões adequadas (403) |
| **INT** Interoperabilidade | TST-03 | Método HTTP inválido GET (405) |
| **INT** Interoperabilidade | TST-04 | Recurso Patient ausente (422) |
| **INT** Interoperabilidade | TST-05 | Patient.identifier.value ausente (422) |
| **INT** Interoperabilidade | TST-06 | JSON inválido (422) |
| **INT** Interoperabilidade | TST-07 | Destino inválido (422) |
| **INT** Interoperabilidade | TST-08 | Bundle.id ausente (422) |
| **INT** Interoperabilidade | TST-09 | MessageHeader.id ausente (422) |
| **INT** Interoperabilidade | TST-10 | fullUrl ausente (422) |
| **FUNC** Funcionais | TST-11 | Utente inexistente (422) |
| **FUNC** Funcionais | TST-12 | Utente falecido (422) |
| **FUNC** Funcionais | TST-13 | Tipo documento inválido (422) |
| **FUNC** Funcionais | TST-14 | Software não registado (422) |
| **FUNC** Funcionais | TST-15 | Médico não registado (422) |
| **FUNC** Funcionais | TST-16 | Tipo profissional inválido MC (422) |
| **FUNC** Funcionais | TST-17 | Função/especialidade inexistente (422) |
| **FUNC** Funcionais | TST-18 | Status relatório inválido `amended` (422) |
| **FUNC** Funcionais | TST-23 | Envio com sucesso resultados MCDT (200) |
| **NF** Não Funcionais | TST-27 | Timeout — servidor indisponível (500) |
| **NF** Não Funcionais | TST-28 | Erro interno plataforma central (500) |
| **NF** Não Funcionais | TST-43 | Tempo resposta PDF pequeno ≤300KB (<5s) |
| **NF** Não Funcionais | TST-44 | Tempo resposta PDF grande ~10MB (<30s) |

---

## ⚙️ Como Executar

### Pré-requisitos
- Python 3.10+
- Java 21+ no PATH
- `validator_cli.jar` na raiz do projecto

### Instalação

```bash
pip install flask flask-cors
```

### Arrancar o servidor

```bash
python server.py
```

Aceder em: **http://localhost:5000**

### Variáveis de Ambiente (opcionais)

| Variável | Valores | Padrão | Descrição |
|----------|---------|--------|-----------|
| `ELO_AI_MODE` | `local`, `cloud`, `auto` | `auto` | Força modo IA |
| `ANTHROPIC_API_KEY` | `sk-ant-api03-...` | — | Activa modo cloud |
| `ELO_ENABLE_AI` | `0`, `1` | `1` | Desactiva IA completamente |

---

## 🔒 Notas de Segurança

- O `validator_cli.jar` **não deve ser incluído no repositório** (> 100MB). Adicionar ao `.gitignore`.
- A `ANTHROPIC_API_KEY` nunca deve ser commitada — usar variável de ambiente ou `.env`.
- A pasta `uploads/` contém ficheiros temporários de evidência — não commitar.

---

## 📌 Taxonomia de IDs de Teste Customizados

O sistema gera IDs no formato:
```
TC.<CATEGORY>.<RESOURCE>.<SCENARIO>.<NNN>
Exemplo: TC.VALIDATION.Patient.requiredfield.002
```

---

*POC desenvolvida no âmbito do projeto ELO — SPMS, 2025/2026.*
'''

with open('/root/output/README.md', 'w', encoding='utf-8') as f:
    f.write(readme)

print("README gerado:", len(readme), "caracteres")
