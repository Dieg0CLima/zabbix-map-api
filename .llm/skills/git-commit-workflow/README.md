# Skill: Git Commit Workflow

## Quando usar
- Preparar mudancas locais para commit de forma rastreavel e segura.

## Entradas esperadas
- Objetivo da tarefa.
- Lista de arquivos alterados.
- Confirmacao de testes/comandos executados.

## Passos
1. Revisar diff (`git status`, `git diff -- <arquivos>`).
2. Separar mudancas relacionadas ao objetivo (evitar commit acoplado).
3. Validar qualidade minima:
   - testes relevantes
   - lint/security quando aplicavel
4. Escrever mensagem de commit orientada a impacto.
5. Registrar atualizacao em `.llm/history/changes.md` quando a mudanca for significativa.

## Padrao de mensagem (sugestao)
`<tipo>(<escopo>): <acao objetiva>`

Exemplos:
- `feat(network_maps): add editor_state payload builder`
- `fix(zabbix_items): handle unsupported db adapter`
- `docs(llm): bootstrap local agent memory`

