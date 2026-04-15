# Checklist - Code Review

- [ ] Mudanca respeita escopo de organizacao (`current_organization` ou `scoped_*`).
- [ ] Escritas mantem `require_editor_or_admin!` quando necessario.
- [ ] Nao expoe segredos (`api_token`, `db_password`, credenciais).
- [ ] Endpoints legados nao foram quebrados sem cobertura.
- [ ] Contrato de resposta e consistente para o contexto alterado.
- [ ] Mudancas de API atualizam `docs/api-contract.md`.
- [ ] Uso de `lastvalue/lastclock` passa por `Zabbix::LiveValuesFetcher` quando aplicavel.
- [ ] Testes atualizados para comportamento alterado.
- [ ] Rubocop/Brakeman/testes foram considerados ou justificados.

