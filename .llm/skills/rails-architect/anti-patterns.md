# Anti-Patterns em Rails (a evitar)

## 1) Models gigantes
- Sintoma: model concentra fluxo de negocio, integracao e apresentacao.
- Risco: baixa testabilidade e alta fragilidade.

## 2) Controllers com regra de negocio
- Sintoma: validacoes/regras complexas direto no controller.
- Risco: acoplamento HTTP-dominio e duplicacao.

## 3) Services em excesso ou sem necessidade
- Sintoma: service para logica trivial.
- Risco: inflacao de camadas e perda de clareza.

## 4) Callbacks escondendo logica critica
- Sintoma: comportamento importante acontece implicitamente.
- Risco: efeitos colaterais e bugs dificeis de rastrear.

## 5) Concerns como “lixeira”
- Sintoma: concern com comportamentos nao transversais.
- Risco: acoplamento oculto e dificuldade de manutencao.

## 6) Queries ineficientes
- Sintoma: N+1, loops com query, falta de preload.
- Risco: degradacao em escala.

## 7) Violacao de responsabilidades
- Sintoma: serializacao, autorizacao e dominio misturados.
- Risco: baixa previsibilidade e regressao frequente.

## 8) Abstracoes prematuras
- Sintoma: interfaces/camadas “para futuro” sem uso real.
- Risco: complexidade desnecessaria.

## Alertas especificos deste projeto
- Quebrar compatibilidade de `legacy_network_maps` sem cobertura.
- Ignorar escopo de organizacao em queries.
- Expor lastvalue/lastclock sem `Zabbix::LiveValuesFetcher`.

