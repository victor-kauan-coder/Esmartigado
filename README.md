# Esmartigado

Criar gado ainda é uma atividade tocada muito no instinto. O produtor sabe quando a ração está acabando porque foi até o cocho olhar, percebe que um animal sumiu quando dá falta dele no fim do dia e descobre o custo real da engorda só quando fecha a conta no fim do mês. O Esmartigado nasce dessa lacuna: trazer para a palma da mão, em tempo quase real, o que está acontecendo dentro do curral.

A ideia é simples de explicar e ambiciosa de executar. Sensores espalhados pela propriedade medem presença dos animais e o nível de ração, mandam isso para um servidor e o aplicativo transforma esses números em decisão. Em vez de planilha e palpite, o produtor abre o celular e enxerga onde está cada lote, quanto de ração resta, quanto está sendo consumido por dia e para onde o custo está indo.

## O que o app faz hoje

A tela inicial concentra a visão geral do rebanho e os indicadores do dia, pensada para responder rápido à pergunta de sempre, "está tudo bem com os animais?". O rastreamento mostra um mapa do curral com as zonas monitoradas e a presença detectada em cada ponto, usando o MapKit.

A parte de alimentação é hoje a mais completa. Ela exibe o nível atual da ração em porcentagem e em quilos, guarda o histórico das medições e deixa o produtor configurar a calibração do recipiente e horários para medições automáticas. O consumo aparece em gráfico por dia, semana e mês, e há uma estimativa que olha a tendência recente com uma regressão linear leve e considera a sazonalidade da semana, então a previsão não é só uma média preguiçosa e sim algo que tenta antecipar a próxima reposição. Quando o sensor percebe um animal parado na frente do cocho, o app segura o comando de medir naquele instante para não registrar uma leitura falsa.

No financeiro o app reúne os custos do rebanho e calcula o gasto de alimentação a partir do consumo realmente medido, em vez de uma estimativa fixa. É o primeiro passo para responder a pergunta que decide o negócio: quanto custa, de fato, engordar cada animal.

## Por que isso pode virar produto

Pecuária é um mercado gigante e ainda pouco digitalizado fora das grandes fazendas. A maior parte das soluções de gestão mira o produtor grande, com brincos eletrônicos caros e integrações complexas. O Esmartigado aposta no pequeno e médio produtor, com hardware acessível e um aplicativo direto, que entrega valor já na primeira semana de uso sem exigir que ninguém vire especialista em tecnologia. A partir do consumo, da presença e do custo já capturados, o caminho natural é evoluir para alertas inteligentes, recomendação de reposição de ração e projeções de custo por arroba, que é onde mora o ganho real para quem vive da margem.

## Como foi construído

O aplicativo é feito em SwiftUI com Swift Charts para os gráficos e MapKit para o mapa, rodando em iOS 17 ou superior. A camada de dados usa Combine junto de async/await. No centro está o `IoTService`, que mantém o estado da aplicação, faz polling a cada dez segundos e publica os dados prontos para as telas, enquanto `AnimaisAPI` e `RacaoAPI` cuidam apenas das chamadas de rede.

O backend é um fluxo no Node-RED que recebe os dados dos sensores ESP32 e Arduino e expõe rotas HTTP, além de uma conexão por WebSocket para disparar medições sob demanda. Como esse fluxo ainda está em evolução, a leitura dos JSONs foi escrita de forma tolerante, aceitando campos ausentes ou em formatos diferentes sem quebrar a tela.

## Rodando o projeto

Abra o `Esmartigado.xcodeproj` no Xcode, ajuste o endereço do Node-RED para o IP da máquina onde ele está rodando e dê run em um simulador ou device na mesma rede.

```swift
enum IoTConfig {
    static let baseURL = "http://192.168.128.65:1880"
}
```

As chamadas acontecem em HTTP dentro da rede local, então o `Info.plist` já libera conexão local. Para uso fora da rede da propriedade o próximo passo é colocar tudo atrás de HTTPS.

## Referência das rotas

Para quem for mexer na integração, as rotas consumidas pelo app são:


| Método   | Rota                 | Função                         |
| -------- | -------------------- | ------------------------------ |
| GET      | `/getanimais`        | lista o rebanho                |
| POST     | `/postanimais`       | cadastra animal                |
| PUT      | `/animais/{id}`      | atualiza animal                |
| DELETE   | `/animais/{id}`      | remove animal                  |
| GET      | `/ultimo`            | última leitura de ração        |
| GET      | `/historico`         | leituras anteriores            |
| POST     | `/medir`             | dispara uma medição            |
| GET/POST | `/alarme`            | horários de medição automática |
| GET/POST | `/config-recipiente` | calibração do recipiente       |
| GET      | `/consumo?periodo=`  | consumo por dia, semana ou mês |
| GET      | `/presenca`          | estado do sensor de presença   |


