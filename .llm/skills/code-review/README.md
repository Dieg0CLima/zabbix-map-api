# Skill: Code Review

## Quando usar
- Revisar PRs, commits locais ou mudancas de agente antes de merge.
- Encontrar regressao funcional, risco de seguranca, quebra de contrato e lacunas de teste.

## Entradas esperadas
- Escopo da mudanca (arquivos/commit/PR).
- Objetivo funcional.
- Contratos impactados (`docs/api-contract.md` quando API muda).

## Passos
1. Ler diff e identificar arquivos alterados.
2. Avaliar impacto em:
   - isolamento por organizacao
   - autorizacao por papel
   - contratos de API
   - integracao Zabbix (incluindo `LiveValuesFetcher` quando aplicavel)
3. Verificar risco de regressao em legados (`legacy_network_maps`).
4. Confirmar testes existentes e lacunas.
5. Registrar findings por severidade com path e linha.

## Escopo fora da skill
- Refatoracao ampla sem objetivo aprovado.
- Correcao de todos os warnings de estilo sem relacao com risco real.

