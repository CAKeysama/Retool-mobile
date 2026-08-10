# Plano de Implementação - Nova Tela Inicial (Wireframe)

Este plano detalha a transformação da tela inicial atual (contador padrão) para o design fornecido no wireframe, focado na gestão de dispositivos industriais.

## Mudanças Propostas

### 1. Tematização e Cores
Definir as cores principais para manter a consistência com o wireframe:
- **Vermelho Primário**: Para o logo "Tool", botão "+" e números nos cards.
- **Cinza Escuro/Preto**: Para o logo "Re" e textos principais.
- **Cinza Claro**: Para o fundo da tela e borda da busca.
- **Rosa/Vermelho Suave**: Para o fundo dos cards de dashboard.

### 2. Estrutura da Tela (`RetoolHomePage`)
Substituir `MyHomePage` por uma nova estrutura que inclua:

#### Cabeçalho Personalizado
- Ícone de menu à esquerda.
- Botão "Sobre o Projeto" com ícone de informação à direita.

#### Seção de Logo
- Texto "ReTool" estilizado (Re em preto, Tool em vermelho).
- Subtítulo: "Gestão de Dispositivos e Ferramentas Industriais".

#### Barra de Busca
- Campo de texto arredondado com ícone de lupa e hint text específico.
- Sombra suave (glow) avermelhada conforme o wireframe.

#### Botões de Ação
- Fila com o botão "Buscar dispositivos" (cinza) e o botão "+" circular (vermelho).

#### Cards de Dashboard
- Lista vertical de cards contendo:
    - Ícone no topo.
    - Número em destaque (vermelho).
    - Descrição abaixo.
    - Letra identificadora no canto inferior direito.

#### Rodapé
- Texto de instrução: "Pressione / para focar a busca de qualquer tela".

## Arquivos a serem Modificados

#### [MODIFY] [main.dart](file:///C:/Users/conta/OneDrive/Documentos/GITHUB REPOS/Retool-mobile/retoolapp/lib/main.dart)
- Remover o código do contador.
- Implementar a nova UI e componentes auxiliares.

## Plano de Verificação

### Verificação Manual
- Validar o layout visual contra a imagem do wireframe.
- Garantir que os elementos estão centralizados e com o espaçamento correto.
- Verificar se o campo de busca é interativo.
