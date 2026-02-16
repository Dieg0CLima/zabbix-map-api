# Zabbix Map API

API em Ruby on Rails para autenticação, multi-organização e evolução de um sistema de mapas integrado ao Zabbix.

## Documentação

- Visão de estrutura e diretrizes de consistência: [`docs/zabbix-map-architecture.md`](docs/zabbix-map-architecture.md)
- Contrato sugerido para renderização no frontend: [`docs/api-contract.md`](docs/api-contract.md)
- Compatibilidade e estratégia para KMZ/KML e correlatos: [`docs/kmz-compatibility.md`](docs/kmz-compatibility.md)

## Estado atual

- Autenticação com Devise + JWT;
- Usuários, organizações e memberships com perfis (`admin`, `editor`, `viewer`);
- Namespace de API versionada em `/api/v1`;
- Modelagem inicial para mapas de rede com nós, cabos e pontos de linha.

## Como subir o projeto

### Pré-requisitos

- Ruby (versão definida no projeto/container)
- Bundler
- Banco de dados configurado em `config/database.yml`

### Setup

```bash
bundle install
bin/rails db:prepare
```

### Rodar aplicação

```bash
bin/rails server
```

### Rodar testes

```bash
bin/rails test
```
