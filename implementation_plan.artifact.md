# Plano de Implementação: Melhorias no Serviço Casa dos Dados e Integração

Este plano visa otimizar o `CasaDosDadosService`, melhorar o tratamento de erros na interface de usuário e tornar a integração mais robusta e flexível.

## User Review Required

> [!IMPORTANT]
> O token da API está hardcoded no arquivo `casa_dos_dados_service.dart`. Para produção, recomenda-se mover este token para um arquivo `.env` ou usar o Firebase Remote Config.
> Além disso, o monitoramento automático atualmente assume o estado "PR" como padrão.

## Proposed Changes

### [Serviços]

#### [MODIFY] [casa_dos_dados_service.dart](file:///G:/Ens/TCC/Geobank/lib/services/casa_dos_dados_service.dart)
- Adicionar tratamento de erros robusto (verificação de status code).
- Lançar exceções específicas para erros de autenticação (401), limite de requisições (429) ou erro interno (500).
- Melhorar o log de erros.

#### [MODIFY] [monitor_cnpj_service.dart](file:///G:/Ens/TCC/Geobank/lib/services/monitor_cnpj_service.dart)
- Atualizar `EmpresaDetectada.fromCasaDosDados` para utilizar a função `_parseTelefone`, garantindo que os números de telefone sejam formatados corretamente ao vir da Casa dos Dados.
- Ajustar a chamada no método `verificar` para permitir uma maior flexibilidade ou tratar o UF de forma mais dinâmica se possível.

### [Interface]

#### [MODIFY] [pesquisa_avancada_screen.dart](file:///G:/Ens/TCC/Geobank/lib/screens/pesquisa_avancada_screen.dart)
- Atualizar o método `_pesquisar` para capturar as novas exceções do serviço.
- Exibir mensagens de erro amigáveis ao usuário (ex: "Token expirado", "Limite de buscas atingido").

## Verification Plan

### Automated Tests
- N/A (O projeto não possui testes unitários configurados no momento).

### Manual Verification
- Realizar uma pesquisa na tela de "Pesquisa Avançada" e verificar se os resultados são exibidos.
- Simular um erro de rede ou token inválido e verificar se a mensagem de erro correta aparece.
- Verificar se os telefones das empresas adicionadas via Casa dos Dados estão formatados corretamente na carteira.
