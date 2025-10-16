// lib/pages/library_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/custom_search_bar.dart';
import 'package:septima_biblia/pages/library_page/bible_timeline_page.dart';
import 'package:septima_biblia/pages/library_page/book_study_guide_page.dart';
import 'package:septima_biblia/pages/library_page/church_history_index_page.dart';
import 'package:septima_biblia/pages/library_page/compact_resource_card.dart';
import 'package:septima_biblia/pages/library_page/components/continue_reading_row.dart';
import 'package:septima_biblia/pages/library_page/components/recommendation_row.dart';
import 'package:septima_biblia/pages/library_page/generic_book_viewer_page.dart';
import 'package:septima_biblia/pages/library_page/gods_word_to_women/gods_word_to_women_index_page.dart';
import 'package:septima_biblia/pages/library_page/library_recommendation_page.dart';
import 'package:septima_biblia/pages/library_page/promises_page.dart';
import 'package:septima_biblia/pages/library_page/recommended_sermon_card.dart';
import 'package:septima_biblia/pages/library_page/resource_detail_modal.dart';
import 'package:septima_biblia/pages/library_page/spurgeon_sermons_index_page.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/pages/library_page/turretin_elenctic_theology/turretin_index_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/pages/themed_maps_list_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:redux/redux.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

// Lista estática e pública com os metadados de todos os recursos da biblioteca
// lib/pages/library_page.dart

final List<Map<String, dynamic>> allLibraryItems = [
  // --- LIVROS ADICIONADOS ---
  {
    'id': 'o-peregrino-oxford-world-s-classics',
    'title': "O Peregrino",
    'description':
        "A jornada alegórica de Cristão da Cidade da Destruição à Cidade Celestial.",
    'author': 'John Bunyan',
    'pageCount': '2 partes',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/o-peregrino.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'o-peregrino-oxford-world-s-classics',
        bookTitle: "O Peregrino"),
    'ficcao': true,
    'dificuldade': 4,
    'isStudyGuide': false,
  },
  {
    'id': 'a-divina-comedia',
    'title': "A Divina Comédia",
    'description':
        "Uma jornada épica através do Inferno, Purgatório e Paraíso, explorando a teologia e a moralidade medieval.",
    'author': 'Dante Alighieri',
    'pageCount': '100 cantos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/a-divina-comedia.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'a-divina-comedia', bookTitle: "A Divina Comédia"),
    'ficcao': true,
    'dificuldade': 7,
    'isStudyGuide': false,
  },
  {
    'id': 'ben-hur',
    'title': "Ben-Hur: Uma História de Cristo",
    'description':
        "A épica história de um nobre judeu que, após ser traído, encontra redenção e fé durante a época de Jesus Cristo.",
    'author': 'Lew Wallace',
    'pageCount': '8 partes',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/ben-hur.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'ben-hur', bookTitle: "Ben-Hur: Uma História de Cristo"),
    'ficcao': true,
    'dificuldade': 4,
    'isStudyGuide': false,
  },
  {
    'id': 'elogio-da-loucura',
    'title': "Elogio da Loucura",
    'description':
        "Uma sátira espirituosa da sociedade, costumes e religião do século XVI, narrada pela própria Loucura.",
    'author': 'Desiderius Erasmus',
    'pageCount': '68 seções',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/elogio-loucura.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'elogio-da-loucura', bookTitle: "Elogio da Loucura"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': false,
  },
  {
    'id': 'anna-karenina',
    'title': "Anna Karenina",
    'description':
        "Um retrato complexo da sociedade russa e das paixões humanas através da história de uma mulher que desafia as convenções.",
    'author': 'Leo Tolstoy',
    'pageCount': '239 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/anna-karenina.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'anna-karenina', bookTitle: "Anna Karenina"),
    'ficcao': true,
    'dificuldade': 7,
    'isStudyGuide': false,
  },
  {
    'id': 'lilith',
    'title': "Lilith",
    'description':
        "Uma fantasia sombria e alegórica sobre a vida, a morte e a redenção, explorando temas de egoísmo e sacrifício.",
    'author': 'George MacDonald',
    'pageCount': '47 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/lilith.webp',
    'destinationPage':
        const GenericBookViewerPage(bookId: 'lilith', bookTitle: "Lilith"),
    'ficcao': true,
    'dificuldade': 6,
    'isStudyGuide': false,
  },
  {
    'id': 'donal-grantchapters',
    'title': "Donal Grant",
    'description':
        "A história de um jovem poeta e tutor que navega pelos desafios do amor, fé e mistério em um castelo escocês.",
    'author': 'George MacDonald',
    'pageCount': '78 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/donal-grant.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'donal-grantchapters', bookTitle: "Donal Grant"),
    'ficcao': true,
    'dificuldade': 5,
    'isStudyGuide': false,
  },
  {
    'id': 'david-elginbrod',
    'title': "David Elginbrod",
    'description':
        "Um romance que explora a fé, o espiritismo e a natureza do bem e do mal através de seus personagens memoráveis.",
    'author': 'George MacDonald',
    'pageCount': '58 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/david-elginbrod.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'david-elginbrod', bookTitle: "David Elginbrod"),
    'ficcao': true,
    'dificuldade': 5,
    'isStudyGuide': false,
  },
  // --- ITENS EXISTENTES ATUALIZADOS ---
  {
    'id': 'gravidade-e-graca',
    'title': "Gravidade e Graça",
    'description':
        "Todos os movimentos naturais da alma são regidos por leis análogas às da gravidade física. A graça é a única exceção.",
    'author': 'Simone Weil',
    'pageCount': '39 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/gravidade_e_graca_cover.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'gravidade-e-graca', bookTitle: "Gravidade e Graça"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': false,
  },
  {
    'id': 'o-enraizamento',
    'title': "O Enraizamento",
    'description':
        "A obediência é uma necessidade vital da alma humana. Ela é de duas espécies: obediência a regras estabelecidas e obediência a seres humanos.",
    'author': 'Simone Weil',
    'pageCount': '15 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/enraizamento.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'o-enraizamento', bookTitle: "O Enraizamento"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': false,
  },
  {
    'id': 'ortodoxia',
    'title': "Ortodoxia",
    'description':
        "A única desculpa possível para este livro é que ele é uma resposta a um desafio. Mesmo um mau atirador é digno quando aceita um duelo.",
    'author': 'G.K. Chesterton',
    'pageCount': '9 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/ortodoxia.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'ortodoxia', bookTitle: "Ortodoxia"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': false,
  },
  {
    'id': 'hereges',
    'title': "Hereges",
    'description':
        "É tolo, de modo geral, que um filósofo ateie fogo a outro filósofo porque não concordam em sua teoria do universo.",
    'author': 'G.K. Chesterton',
    'pageCount': '20 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/hereges.webp',
    'destinationPage':
        const GenericBookViewerPage(bookId: 'hereges', bookTitle: "Hereges"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': false,
  },
  {
    'id': 'carta-a-um-religioso',
    'title': "Carta a um Religioso",
    'description':
        "Quando leio o catecismo do Concílio de Trento, tenho a impressão de que não tenho nada em comum com a religião que nele se expõe.",
    'author': 'Simone Weil',
    'pageCount': '1 capítulo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/cartas_a_um_religioso.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'carta-a-um-religioso', bookTitle: "Carta a um Religioso"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': false,
  },
  {
    'id': 'mapas-tematicos',
    'title': "Mapas Temáticos",
    'description':
        "Explore as jornadas dos apóstolos e outros eventos bíblicos.",
    'author': 'Septima',
    'pageCount': '4 Viagens',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/themed_maps_cover.webp',
    'destinationPage': const ThemedMapsListPage(),
    'ficcao': false,
    'dificuldade': 2,
    'isStudyGuide': false,
  },
  {
    'id': 'spurgeon-sermoes',
    'title': "Sermões de Spurgeon",
    'description':
        "Uma vasta coleção dos sermões do 'Príncipe dos Pregadores'.",
    'author': 'C.H. Spurgeon',
    'pageCount': '+3000 sermões',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/spurgeon_cover.webp',
    'destinationPage': const SpurgeonSermonsIndexPage(),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false,
  },
  {
    'id': 'a-palavra-as-mulheres',
    'title': "A Palavra às Mulheres",
    'description':
        "Uma análise profunda das escrituras sobre o papel da mulher.",
    'author': 'K. C. Bushnell',
    'pageCount': '+500 páginas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/gods_word_to_women_cover.webp',
    'destinationPage': const GodsWordToWomenIndexPage(),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false,
  },
  {
    'id': 'promessas-da-biblia',
    'title': "Promessas da Bíblia",
    'description': "Um compêndio de promessas divinas organizadas por tema.",
    'author': 'Samuel Clarke',
    'pageCount': '+1500 promessas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/promessas_cover.webp',
    'destinationPage': const PromisesPage(),
    'ficcao': false,
    'dificuldade': 2,
    'isStudyGuide': false,
  },
  {
    'id': 'historia-da-igreja',
    'title': "História da Igreja",
    'description':
        "A jornada da igreja cristã desde os apóstolos até a era moderna.",
    'author': 'Philip Schaff',
    'pageCount': '+5000 páginas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/historia_igreja.webp',
    'destinationPage': const ChurchHistoryIndexPage(),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': false,
  },
  {
    'id': 'teologia-apologetica',
    'title': "Teologia Apologética",
    'description': "A obra monumental da teologia sistemática reformada.",
    'author': 'Francis Turretin',
    'pageCount': '+2000 páginas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/turretin_cover.webp',
    'destinationPage': const TurretinIndexPage(),
    'ficcao': false,
    'dificuldade': 7,
    'isStudyGuide': false,
  },
  {
    'id': 'estudos-rapidos',
    'title': "Estudos Rápidos",
    'description':
        "Guias e rotas de estudo temáticos para aprofundar seu conhecimento.",
    'author': 'Séptima',
    'pageCount': '10+ estudos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/estudos_tematicos_cover.webp',
    'destinationPage': const StudyHubPage(),
    'ficcao': false,
    'dificuldade': 2,
    'isStudyGuide': false,
  },
  {
    'id': 'linha-do-tempo',
    'title': "Linha do Tempo",
    'description': "Contextualize os eventos bíblicos com a história mundial.",
    'author': 'Septima',
    'pageCount': 'Interativo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/timeline_cover.webp',
    'destinationPage': const BibleTimelinePage(),
    'ficcao': false,
    'dificuldade': 2,
    'isStudyGuide': false,
  },
  {
    'id': 'c-s-lewis-o-peso-da-gloria',
    'title': "O Peso da Glória",
    'description':
        "Uma coleção de sermões e ensaios que exploram o anseio humano pelo céu e a natureza da glória divina.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-o-peso-da-gloria_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-o-peso-da-gloria', bookTitle: "O Peso da Glória"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-o-dom-da-amizade',
    'title': "O Dom da Amizade",
    'description':
        "Uma exploração profunda sobre a natureza e o valor da amizade, um dos 'quatro amores' de Lewis.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-o-dom-da-amizade_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-o-dom-da-amizade', bookTitle: "O Dom da Amizade"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-a-abolicao-do-homem',
    'title': "A Abolição do Homem",
    'description':
        "Uma defesa filosófica da existência de valores objetivos e da lei natural contra o relativismo.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-a-abolicao-do-homem_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-a-abolicao-do-homem',
        bookTitle: "A Abolição do Homem"),
    'ficcao': false,
    'dificuldade': 7,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-a-anatomia-de-uma-dor',
    'title': "A Anatomia de Uma Dor",
    'description':
        "Um diário íntimo e cru sobre a luta de Lewis com a fé e o sofrimento após a morte de sua esposa.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-a-anatomia-de-uma-dor_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-a-anatomia-de-uma-dor',
        bookTitle: "A Anatomia de Uma Dor"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-como-ser-cristao',
    'title': "Como Ser Cristão",
    'description':
        "Uma compilação que une 'Cristianismo Puro e Simples', 'Cartas de um Diabo a seu Aprendiz', 'O Grande Divórcio' e 'O Problema da Dor'.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-como-ser-cristao_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-como-ser-cristao', bookTitle: "Como Ser Cristão"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-a-ultima-noite-do-mundo',
    'title': "A Última Noite do Mundo",
    'description':
        "Uma coleção de ensaios que exploram temas como a segunda vinda de Cristo, oração e o significado da existência.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-a-ultima-noite-do-mundo_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-a-ultima-noite-do-mundo',
        bookTitle: "A Última Noite do Mundo"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-cartas-a-malcolm',
    'title': "Cartas a Malcolm",
    'description':
        "Uma troca de cartas fictícia que explora a natureza da oração de forma íntima, prática e profundamente pessoal.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-cartas-a-malcolm_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-cartas-a-malcolm', bookTitle: "Cartas a Malcolm"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-cartas-de-um-diabo-a-seu-aprendiz',
    'title': "Cartas de um Diabo a seu Aprendiz",
    'description':
        "Uma sátira genial onde um demônio veterano ensina seu sobrinho a como tentar e corromper um ser humano.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-cartas-de-um-diabo-a-seu-aprendiz_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-cartas-de-um-diabo-a-seu-aprendiz',
        bookTitle: "Cartas de um Diabo a seu Aprendiz"),
    'ficcao': true,
    'dificuldade': 5,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-cristianismo-puro-e-simples',
    'title': "Cristianismo Puro e Simples",
    'description':
        "Uma das mais famosas defesas da fé cristã, argumentando de forma lógica e acessível os pilares do cristianismo.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-cristianismo-puro-e-simples_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-cristianismo-puro-e-simples',
        bookTitle: "Cristianismo Puro e Simples"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-deus-no-banco-dos-reus',
    'title': "Deus no Banco dos Réus",
    'description':
        "Ensaios que abordam objeções comuns ao cristianismo, colocando Deus 'no banco dos réus' para responder a críticas.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-deus-no-banco-dos-reus_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-deus-no-banco-dos-reus',
        bookTitle: "Deus no Banco dos Réus"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-milagres',
    'title': "Milagres",
    'description':
        "Uma análise filosófica sobre a possibilidade e a natureza dos milagres em um mundo governado por leis naturais.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/guias/c-s-lewis-milagres_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-milagres', bookTitle: "Milagres"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-o-grande-divorcio',
    'title': "O Grande Divórcio",
    'description':
        "Uma alegoria sobre uma viagem do inferno ao céu, explorando as escolhas que nos prendem ao pecado e nos impedem de aceitar a graça.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-o-grande-divorcio_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-o-grande-divorcio', bookTitle: "O Grande Divórcio"),
    'ficcao': true,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-o-problema-da-dor',
    'title': "O Problema da Dor",
    'description':
        "Uma tentativa intelectual de reconciliar a existência de um Deus bom e todo-poderoso com a realidade do sofrimento no mundo.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-o-problema-da-dor_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-o-problema-da-dor', bookTitle: "O Problema da Dor"),
    'ficcao': false,
    'dificuldade': 6,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-os-quatro-amores',
    'title': "Os Quatro Amores",
    'description':
        "Uma exploração das quatro formas de amor descritas no grego: Afeição, Amizade, Eros e Caridade (Ágape).",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-os-quatro-amores_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-os-quatro-amores', bookTitle: "Os Quatro Amores"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': true,
  },
  {
    'id': 'c-s-lewis-reflexoes-sobre-os-salmos',
    'title': "Reflexões sobre os Salmos",
    'description':
        "Uma meditação pessoal e acadêmica sobre o livro de Salmos, abordando suas dificuldades, belezas e significados.",
    'author': 'C. S. Lewis',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/c-s-lewis-reflexoes-sobre-os-salmos_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'c-s-lewis-reflexoes-sobre-os-salmos',
        bookTitle: "Reflexões sobre os Salmos"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-a-jornada',
    'title': "A Jornada",
    'description':
        "Uma exploração sobre o propósito de Deus para a vida e como lidar com as decepções e desafios ao longo do caminho.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/guias/billy-graham-a-jornada_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-a-jornada', bookTitle: "A Jornada"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-anjos',
    'title': "Anjos",
    'description':
        "Uma investigação sobre o papel dos anjos como agentes secretos de Deus, sua influência na história bíblica e sua atuação na proteção da humanidade.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/guias/billy-graham-anjos_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-anjos', bookTitle: "Anjos"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-aproximando-se-de-casa-vida-fe-e-terminar-bem',
    'title': "Aproximando-se de Casa",
    'description':
        "Reflexões sobre envelhecer com graça, fé e propósito, oferecendo sabedoria para terminar bem a jornada da vida.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-aproximando-se-de-casa-vida-fe-e-terminar-bem_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-aproximando-se-de-casa-vida-fe-e-terminar-bem',
        bookTitle: "Aproximando-se de Casa"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-como-nascer-de-novo',
    'title': "Como Nascer de Novo",
    'description':
        "Um guia que explica a experiência do novo nascimento espiritual, ajudando a descobrir valores esquecidos e a tomar uma decisão que pode revolucionar a vida.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-como-nascer-de-novo_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-como-nascer-de-novo',
        bookTitle: "Como Nascer de Novo"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-em-paz-com-deus',
    'title': "Em Paz com Deus",
    'description':
        "Apresenta o caminho para a autêntica paz pessoal em um mundo em crise, mostrando como encontrar calma espiritual em meio ao estresse e desânimo.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-em-paz-com-deus_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-em-paz-com-deus', bookTitle: "Em Paz com Deus"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-esperanca-para-o-coracao-perturbado',
    'title': "Esperança para o Coração Perturbado",
    'description':
        "Oferece conforto e encorajamento bíblico para aqueles que enfrentam dor, perda e incerteza, lembrando do amor inabalável de Deus.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-esperanca-para-o-coracao-perturbado_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-esperanca-para-o-coracao-perturbado',
        bookTitle: "Esperança para o Coração Perturbado"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-o-espirito-santo',
    'title': "O Espírito Santo",
    'description':
        "Responde a perguntas fundamentais sobre a terceira pessoa da Trindade, explicando quem Ele é, o que Ele faz e como experimentar Seu poder na vida diária.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-o-espirito-santo_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-o-espirito-santo', bookTitle: "O Espírito Santo"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-respostas-para-os-problemas-da-vida',
    'title': "Respostas para os Problemas da Vida",
    'description':
        "Um guia com respostas bíblicas para as preocupações e dúvidas mais comuns da atualidade, abordando mais de 80 tópicos para fortalecer a fé.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-respostas-para-os-problemas-da-vida_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-respostas-para-os-problemas-da-vida',
        bookTitle: "Respostas para os Problemas da Vida"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-tempestade-a-vista',
    'title': "Tempestade à Vista",
    'description':
        "Analisa os sinais dos tempos e os problemas urgentes que o mundo enfrenta, explicando como Deus está traçando seu plano final em meio às crises.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-tempestade-a-vista_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-tempestade-a-vista',
        bookTitle: "Tempestade à Vista"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': true,
  },
  {
    'id': 'billy-graham-vida-e-pos-morte',
    'title': "Vida e Pós-morte",
    'description':
        "Aborda uma das maiores questões da humanidade, a morte, explicando-a como parte do plano de Deus e ajudando a superar o medo do que vem a seguir.",
    'author': 'Billy Graham',
    'pageCount': 'Guia de Estudo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/guias/billy-graham-vida-e-pos-morte_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'billy-graham-vida-e-pos-morte', bookTitle: "Vida e Pós-morte"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': true,
  },
  {
    'id': 'os-guinness-o-chamado',
    'title': "O Chamado",
    'description':
        "Um livro escrito para aqueles que possuem um profundo desejo de compreender o propósito de sua existência - o 'porquê' último de sua vida. Os Guinness avalia como essa busca é empreendida por adolescentes, universitários, jovens profissionais, pessoas na meia-idade, pais com o 'ninho vazio', homens e mulheres dos cinquenta para cima. Para conhecer o sentido da sua vida deverão descobrir o propósito para o qual foram criados e para o qual foram chamados.",
    'author': 'Os Guinness',
    'pageCount': '256',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/os-guinness-o-chamado_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'os-guinness-o-chamado', bookTitle: "O Chamado"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id': 'christine-caine-inesperado-deixe-o-medo-para-tras-e-avance-em-fe',
    'title': "Inesperado: Deixe o Medo para Trás e Avance em Fé",
    'description':
        "Neste livro, Christine Caine convida o leitor a deixar para trás o medo do desconhecido e a avançar com fé, mesmo quando a vida toma rumos inesperados. A autora compartilha experiências pessoais e ensinamentos bíblicos para encorajar e equipar o leitor a confiar em Deus em meio às incertezas.",
    'author': 'Christine Caine',
    'pageCount': '224',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/christine-caine-inesperado-deixe-o-medo-para-tras-e-avance-em-fe_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'christine-caine-inesperado-deixe-o-medo-para-tras-e-avance-em-fe',
        bookTitle: "Inesperado"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id': 'corrie-ten-boom-o-refugio-secreto',
    'title': "O Refúgio Secreto",
    'description':
        "A história verídica de como uma família holandesa arrisca sua vida para esconder judeus durante a Segunda Guerra Mundial é vividamente registrada neste livro. Como membros do movimento de Resistência, Corrie ten Boom, seu pai e sua irmã foram enviados aos campos de concentração nazistas onde seu aprendizado sobre a graça divina foi o sustentáculo durante os anos de provação.",
    'author': 'Corrie ten Boom',
    'pageCount': '324',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/corrie-ten-boom-o-refugio-secreto_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'corrie-ten-boom-o-refugio-secreto',
        bookTitle: "O Refúgio Secreto"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id': 'elisabeth-elliot-paixao-e-pureza',
    'title': "Paixão e Pureza",
    'description':
        "Por meio de cartas trocadas com Jim e escritos em seu diário, a autora compartilha memórias de sua perseverança sobre as tentações, os sacrifícios enfrentados e as vitórias sobre o fogo da paixão em sua história de namoro com Jim. Neste clássico, Elisabeth oferece ricos ensinamentos bíblicos que auxiliam os solteiros a priorizarem o compromisso com Cristo acima do amor entre um homem e uma mulher.",
    'author': 'Elisabeth Elliot',
    'pageCount': '250',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/elisabeth-elliot-paixao-e-pureza_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'elisabeth-elliot-paixao-e-pureza',
        bookTitle: "Paixão e Pureza"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id': 'ellen-santilli-tornando-se-elisabeth-elliot',
    'title': "Tornando-se Elisabeth Elliot",
    'description':
        "Uma biografia que narra a vida de Elisabeth Elliot, desde sua infância e juventude até seus anos como missionária, escritora e palestrante. O livro explora as experiências que moldaram sua fé e ministério, incluindo a perda de seu primeiro marido, Jim Elliot. A obra oferece um olhar íntimo sobre a jornada de uma das mulheres mais influentes do cristianismo do século XX.",
    'author': 'Ellen Santilli Vaughn',
    'pageCount': '384',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/ellen-santilli-tornando-se-elisabeth-elliot_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'ellen-santilli-tornando-se-elisabeth-elliot',
        bookTitle: "Tornando-se Elisabeth Elliot"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id': 'elisabeth-elliot-deixe-me-ser-mulher',
    'title': "Deixe-me Ser Mulher",
    'description':
        "Escrito de mãe para filha no auge do movimento feminista em 1976, este livro reúne ensinamentos preciosos para os dias de hoje sobre o que é ser uma mulher cristã. Com o objetivo de responder à pergunta “O que significa ser mulher”, Elisabeth Elliot aborda vários assuntos relevantes como: submissão, orgulho, liberdade, vocação.",
    'author': 'Elisabeth Elliot',
    'pageCount': '256',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/elisabeth-elliot-deixe-me-ser-mulher_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'elisabeth-elliot-deixe-me-ser-mulher',
        bookTitle: "Deixe-me Ser Mulher"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id': 'elisabeth-elliot-esperanca-na-solidao-encontrando-deus-na-escuridao',
    'title': "Esperança na Solidão: Encontrando Deus na Escuridão",
    'description':
        "Neste livro, Elisabeth Elliot explora o tema da solidão e como encontrar esperança e a presença de Deus em meio a ela. A autora compartilha reflexões e experiências pessoais para encorajar aqueles que se sentem sozinhos, mostrando que a solidão pode ser um caminho para um relacionamento mais profundo com Deus.",
    'author': 'Elisabeth Elliot',
    'pageCount': '192',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/elisabeth-elliot-esperanca-na-solidao-encontrando-deus-na-escuridao_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'elisabeth-elliot-esperanca-na-solidao-encontrando-deus-na-escuridao',
        bookTitle: "Esperança na Solidão"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id': 'elisabeth-elliot-o-sofrimento-nunca-e-em-vao',
    'title': "O Sofrimento Nunca é em Vão",
    'description':
        "A partir de seu testemunho de vida e todas as provações que ela passou, somos desafiados, encorajados e inspirados a continuar confiando em Deus mesmo nos momentos mais difíceis e angustiantes de nossas vidas.",
    'author': 'Elisabeth Elliot',
    'pageCount': '132',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/elisabeth-elliot-o-sofrimento-nunca-e-em-vao_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'elisabeth-elliot-o-sofrimento-nunca-e-em-vao',
        bookTitle: "O Sofrimento Nunca é em Vão"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id':
        'elisabeth-elliot-uma-vida-de-obediencia-7-disciplinas-para-uma-vida-mais-forte',
    'title': "Uma Vida de Obediência: 7 Disciplinas para uma Vida mais Forte",
    'description':
        "Elisabeth Elliot apresenta sete disciplinas espirituais para fortalecer a vida cristã. Com base em sua própria jornada de fé, a autora explora a importância da obediência a Deus em áreas como a vontade, o corpo, a mente, as posses, o tempo, o trabalho e os sentimentos. O livro oferece um guia prático para uma vida de maior disciplina e dedicação a Deus.",
    'author': 'Elisabeth Elliot',
    'pageCount': '208',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/elisabeth-elliot-uma-vida-de-obediencia-7-disciplinas-para-uma-vida-mais-forte_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'elisabeth-elliot-uma-vida-de-obediencia-7-disciplinas-para-uma-vida-mais-forte',
        bookTitle: "Uma Vida de Obediência"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id':
        'emerson-eggerichs-amor-e-respeito-na-familia-o-que-os-pais-mais-desejam-do-que-os-filhos-mais-precisam',
    'title': "Amor e Respeito na Família",
    'description':
        "Psicólogos afirmam hoje o que a sabedoria bíblica já havia estabelecido há milênios: as crianças precisam do amor que Deus nos ordenou dar a elas (Tito 2.4), e os pais precisam receber delas o respeito que as Escrituras apontam ser o dever dos filhos (Êxodo 20.12). Amor e respeito na família oferece orientações práticas para romper o que os autores denominam o ciclo insano que realimenta a discórdia, afasta pais e filhos e torna o lar um ambiente tóxico.",
    'author': 'Emerson Eggerichs',
    'pageCount': '222',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/emerson-eggerichs-amor-e-respeito-na-familia-o-que-os-pais-mais-desejam-do-que-os-filhos-mais-precisam_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'emerson-eggerichs-amor-e-respeito-na-familia-o-que-os-pais-mais-desejam-do-que-os-filhos-mais-precisam',
        bookTitle: "Amor e Respeito na Família"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id':
        'jen-wilkin-mulheres-da-palavra-como-estudar-a-biblia-com-o-coracao-e-a-mente',
    'title': "Mulheres da Palavra",
    'description':
        "Oferecendo um plano claro e conciso de aprofundamento no estudo das Sagradas Escrituras, este livro irá ajudar as mulheres a perseverarem na leitura da Palavra de Deus, de forma a treinar suas mentes e transformar seus corações.",
    'author': 'Jen Wilkin',
    'pageCount': '184',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/jen-wilkin-mulheres-da-palavra-como-estudar-a-biblia-com-o-coracao-e-a-mente_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'jen-wilkin-mulheres-da-palavra-como-estudar-a-biblia-com-o-coracao-e-a-mente',
        bookTitle: "Mulheres da Palavra"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id': 'jen-wilkin-ninguem-como-ele',
    'title': "Ninguém como Ele",
    'description':
        "Jen Wilkin explora dez atributos de Deus que destacam Sua singularidade e majestade. O livro convida o leitor a um estudo profundo sobre quem Deus é, mostrando como a compreensão de Seus atributos pode transformar a adoração, o relacionamento e a vida diária do crente.",
    'author': 'Jen Wilkin',
    'pageCount': '224',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/jen-wilkin-ninguem-como-ele_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'jen-wilkin-ninguem-como-ele', bookTitle: "Ninguém como Ele"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id':
        'joyce-meyer-campo-de-batalha-da-mente-vencendo-a-batalha-em-sua-mente',
    'title': "Campo de Batalha da Mente",
    'description':
        "Se você é um dos milhões que sofrem com preocupação, dúvida, depressão, raiva ou culpa, você está experimentando um ataque à sua mente. Superar pensamentos negativos que vêm contra sua mente traz liberdade e paz.",
    'author': 'Joyce Meyer',
    'pageCount': '288',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/joyce-meyer-campo-de-batalha-da-mente-vencendo-a-batalha-em-sua-mente_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'joyce-meyer-campo-de-batalha-da-mente-vencendo-a-batalha-em-sua-mente',
        bookTitle: "Campo de Batalha da Mente"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id': 'martyn-lloyd-jones-depressao-espiritual',
    'title': "Depressão Espiritual",
    'description':
        "Neste livro, o Dr. Lloyd-Jones discute as causas da depressão espiritual e a forma como deve ser tratada e superada. A Bíblia aborda este tema com muita frequência, e como parece ser um problema que afetou muitos do povo de Deus, e ainda afeta os cristãos de hoje, este livro certamente será de grande ajuda para esclarecer o que a Bíblia ensina sobre este assunto.",
    'author': 'Martyn Lloyd-Jones',
    'pageCount': '320',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/martyn-lloyd-jones-depressao-espiritual_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'martyn-lloyd-jones-depressao-espiritual',
        bookTitle: "Depressão Espiritual"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': false
  },
  {
    'id':
        'nancy-demoss-adornada-vivendo-a-beleza-do-evangelho-em-meio-as-mulheres',
    'title': "Adornada: Vivendo a Beleza do Evangelho em Meio às Mulheres",
    'description':
        "Nancy DeMoss Wolgemuth explora a passagem de Tito 2 e o chamado para que as mulheres mais velhas ensinem as mais novas. O livro oferece uma visão prática de como viver o evangelho de forma bela e intencional, construindo relacionamentos de mentoria que edificam a igreja e glorificam a Deus.",
    'author': 'Nancy DeMoss Wolgemuth',
    'pageCount': '352',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/nancy-demoss-adornada-vivendo-a-beleza-do-evangelho-em-meio-as-mulheres_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'nancy-demoss-adornada-vivendo-a-beleza-do-evangelho-em-meio-as-mulheres',
        bookTitle: "Adornada"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id':
        'nancy-leigh-demoss-mentiras-em-que-as-garotas-acreditam-e-a-verdade-que-as-liberta',
    'title': "Mentiras em que as Garotas Acreditam e a Verdade que as Liberta",
    'description':
        "Nancy DeMoss Wolgemuth e Dannah Gresh abordam as mentiras comuns que as jovens acreditam sobre Deus, si mesmas, rapazes, amizades e o futuro. O livro oferece a verdade da Palavra de Deus para combater essas mentiras, ajudando as jovens a viverem na liberdade e na verdade de Cristo.",
    'author': 'Nancy DeMoss Wolgemuth',
    'pageCount': '240',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/nancy-leigh-demoss-mentiras-em-que-as-garotas-acreditam-e-a-verdade-que-as-liberta_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'nancy-leigh-demoss-mentiras-em-que-as-garotas-acreditam-e-a-verdade-que-as-liberta',
        bookTitle: "Mentiras em que as Garotas Acreditam"),
    'ficcao': false,
    'dificuldade': 2,
    'isStudyGuide': false
  },
  {
    'id':
        'nancy-r-pearcey-verdade-total-libertando-o-cristianismo-de-seu-cativeiro-cultural',
    'title':
        "Verdade Total: Libertando o Cristianismo de seu Cativeiro Cultural",
    'description':
        "Nancy Pearcey argumenta que o cristianismo não é apenas uma fé privada, mas uma verdade total que se aplica a todas as áreas da vida. O livro desafia os cristãos a desenvolverem uma cosmovisão bíblica consistente, capaz de engajar e transformar a cultura, libertando o cristianismo da dicotomia entre o sagrado e o secular.",
    'author': 'Nancy R. Pearcey',
    'pageCount': '448',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/nancy-r-pearcey-verdade-total-libertando-o-cristianismo-de-seu-cativeiro-cultural_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'nancy-r-pearcey-verdade-total-libertando-o-cristianismo-de-seu-cativeiro-cultural',
        bookTitle: "Verdade Total"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': false
  },
  {
    'id': 'richard-j-foster-celebracao-da-disciplina',
    'title': "Celebração da Disciplina",
    'description':
        "Richard Foster escreveu este livro para ajudar os cristãos a redescobrir os 'hábitos sagrados' que foram negligenciados ou mal compreendidos no cristianismo moderno. Ele divide essas práticas em três categorias: disciplinas internas, disciplinas externas e disciplinas corporativas.",
    'author': 'Richard J. Foster',
    'pageCount': '303',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/richard-j-foster-celebracao-da-disciplina_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'richard-j-foster-celebracao-da-disciplina',
        bookTitle: "Celebração da Disciplina"),
    'ficcao': false,
    'dificuldade': 5,
    'isStudyGuide': false
  },
  {
    'id': 'rosaria-butterfield-o-evangelho-vem-com-uma-chave-de-casa',
    'title': "O Evangelho Vem com uma Chave de Casa",
    'description':
        "Rosaria Butterfield descreve a prática da hospitalidade radicalmente comum como um meio de viver o evangelho no dia a dia. A autora compartilha histórias de como abrir sua casa para estranhos e vizinhos se tornou uma poderosa ferramenta de evangelismo e discipulado, mostrando que o evangelho é compartilhado tanto na mesa de jantar quanto no púlpito.",
    'author': 'Rosaria Butterfield',
    'pageCount': '224',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/rosaria-butterfield-o-evangelho-vem-com-uma-chave-de-casa_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'rosaria-butterfield-o-evangelho-vem-com-uma-chave-de-casa',
        bookTitle: "O Evangelho Vem com uma Chave de Casa"),
    'ficcao': false,
    'dificuldade': 3,
    'isStudyGuide': false
  },
  {
    'id':
        'rosaria-butterfield-pensamentos-secretos-de-uma-convertida-improvavel',
    'title': "Pensamentos Secretos de uma Convertida Improvável",
    'description':
        "A jornada de uma professora de língua inglesa rumo à fé cristã. Rosaria Champagne Butterfield conta a história de sua conversão, e é surpreendente. O amor de Deus não tem limites, ninguém é um caso perdido, Jesus veio para TODOS. Essa leitura despertou em mim um olhar diferente para as pessoas.",
    'author': 'Rosaria Butterfield',
    'pageCount': '174',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/rosaria-butterfield-pensamentos-secretos-de-uma-convertida-improvavel_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'rosaria-butterfield-pensamentos-secretos-de-uma-convertida-improvavel',
        bookTitle: "Pensamentos Secretos de uma Convertida Improvável"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id':
        'sally-clarkson-o-lar-que-da-vida-criando-um-lugar-de-pertenca-e-proposito',
    'title': "O Lar que Dá Vida: Criando um Lugar de Pertença e Propósito",
    'description':
        "Sally Clarkson inspira as mães a criarem um lar que seja um refúgio de amor, vida e aprendizado para seus filhos. O livro oferece conselhos práticos e encorajamento para cultivar uma atmosfera familiar que nutra a alma e o coração, transformando a casa em um lugar onde a fé e o caráter são forjados.",
    'author': 'Sally Clarkson',
    'pageCount': '272',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/sally-clarkson-o-lar-que-da-vida-criando-um-lugar-de-pertenca-e-proposito_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId:
            'sally-clarkson-o-lar-que-da-vida-criando-um-lugar-de-pertenca-e-proposito',
        bookTitle: "O Lar que Dá Vida"),
    'ficcao': false,
    'dificuldade': 2,
    'isStudyGuide': false
  },
  {
    'id': 'tedd-tripp-pastoreando-o-coracao-da-crianca',
    'title': "Pastoreando o Coração da Criança",
    'description':
        "Pastoreando o Coração da Criança é uma obra sobre como falar ao coração de nossos filhos. As coisas que seu filho diz e faz brotam do coração. Lucas 6.45 afirma isso com as seguintes palavras: 'A boca fala do que está cheio o coração'. Escrito para pais que têm filhos de qualquer idade, este livro esclarecedor fornece perspectivas e procedimentos para o pastoreio do coração da criança nos caminhos da vida.",
    'author': 'Tedd Tripp',
    'pageCount': '240',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/tedd-tripp-pastoreando-o-coracao-da-crianca_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'tedd-tripp-pastoreando-o-coracao-da-crianca',
        bookTitle: "Pastoreando o Coração da Criança"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  },
  {
    'id': 'timothy-keller-o-significado-do-casamento',
    'title': "O Significado do Casamento",
    'description':
        "Este livro se baseia na muito aplaudida série de sermões pregados por Timothy Keller, autor best-seller do New York Times. O autor mostra a todos — cristãos, céticos, solteiros, casais casados há muito tempo e aos que estão prestes a noivar — a visão do que o casamento deve ser segundo a Bíblia.",
    'author': 'Timothy Keller',
    'pageCount': '296',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath':
        'assets/covers/timothy-keller-o-significado-do-casamento_cover.webp',
    'destinationPage': const BookStudyGuidePage(
        bookId: 'timothy-keller-o-significado-do-casamento',
        bookTitle: "O Significado do Casamento"),
    'ficcao': false,
    'dificuldade': 4,
    'isStudyGuide': false
  }
];

// ViewModel
class _LibraryViewModel {
  final bool isPremium;
  final List<Map<String, dynamic>> libraryShelves;
  final List<Map<String, dynamic>> recommendedSermons;
  _LibraryViewModel({
    required this.isPremium,
    required this.libraryShelves,
    required this.recommendedSermons,
  });
  static _LibraryViewModel fromStore(Store<AppState> store) {
    bool isCurrentlyPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!isCurrentlyPremium) {
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final status = userDetails['subscriptionStatus'] as String?;
        final endDateTimestamp =
            userDetails['subscriptionEndDate'] as Timestamp?;
        if (status == 'active' &&
            endDateTimestamp != null &&
            endDateTimestamp.toDate().isAfter(DateTime.now())) {
          isCurrentlyPremium = true;
        }
      }
    }
    return _LibraryViewModel(
      isPremium: isCurrentlyPremium,
      libraryShelves: store.state.booksState.libraryShelves,
      recommendedSermons: store.state.userState.recommendedSermons,
    );
  }
}

// Página principal da Biblioteca
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredLibraryItems = [];
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  // Estado dos filtros
  bool _showFiction = true; // Inicia como true para mostrar por padrão
  bool _showStudyGuide = true; // Inicia como true para mostrar por padrão
  RangeValues _difficultyRange = const RangeValues(1, 7);

  // Nova variável para controlar o modo de filtro exclusivo (ativado com long press)
  String? _exclusiveFilter; // Pode ser 'ficcao', 'isStudyGuide', ou null

  bool get _isFilterOrSearchActive =>
      _searchController.text.isNotEmpty ||
      !_showFiction ||
      !_showStudyGuide ||
      _exclusiveFilter != null ||
      _difficultyRange.start != 1 ||
      _difficultyRange.end != 7;

  // Getter para verificar se algum filtro está ativo
  bool get _isAnyFilterActive =>
      !_showFiction ||
      !_showStudyGuide ||
      _exclusiveFilter != null ||
      _difficultyRange.start != 1 ||
      _difficultyRange.end != 7;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterLibrary);
    _filterLibrary(); // Executa uma vez no início para popular a lista.
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Função para normalizar texto para busca (case-insensitive e sem acentos)
  String _normalize(String text) {
    return unorm
        .nfd(text)
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toLowerCase();
  }

  // Lógica de filtragem atualizada para lidar com os dois modos
  void _filterLibrary() {
    // A lógica de filtragem interna está correta e permanece a mesma.
    List<Map<String, dynamic>> filtered = allLibraryItems;

    // Filtros de categoria
    if (_exclusiveFilter != null) {
      if (_exclusiveFilter == 'ficcao') {
        filtered = filtered.where((item) => item['ficcao'] == true).toList();
      } else if (_exclusiveFilter == 'isStudyGuide') {
        filtered =
            filtered.where((item) => item['isStudyGuide'] == true).toList();
      }
    } else {
      if (!_showFiction) {
        filtered = filtered.where((item) => item['ficcao'] != true).toList();
      }
      if (!_showStudyGuide) {
        filtered =
            filtered.where((item) => item['isStudyGuide'] != true).toList();
      }
    }

    // Filtro de dificuldade
    filtered = filtered.where((item) {
      final difficulty = item['dificuldade'] as int? ?? 1;
      return difficulty >= _difficultyRange.start &&
          difficulty <= _difficultyRange.end;
    }).toList();

    // Filtro de texto (sempre aplicado)
    final query = _normalize(_searchController.text);
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final title = _normalize(item['title'] ?? '');
        final author = _normalize(item['author'] ?? '');
        final description = _normalize(item['description'] ?? '');
        return title.contains(query) ||
            author.contains(query) ||
            description.contains(query);
      }).toList();
    }

    // setState agora é chamado em um único lugar, garantindo que a UI sempre reflita o estado correto.
    setState(() {
      _filteredLibraryItems = filtered;
    });
  }

  // Limpa apenas o texto da barra de busca
  void _clearSearchText() {
    _searchController.clear();
    // A chamada a _filterLibrary() já acontece automaticamente pelo listener.
  }

  // Limpa TODOS os filtros e reseta a lista
  void _clearAllFiltersAndSearch() {
    _searchController.clear();
    setState(() {
      _showFiction = true;
      _showStudyGuide = true;
      _exclusiveFilter = null;
      _difficultyRange = const RangeValues(1, 7);
    });
    // O listener do searchController já vai chamar _filterLibrary.
    // Se não chamar (porque o texto já estava vazio), chamamos manualmente.
    if (_searchController.text.isEmpty) {
      _filterLibrary();
    }
  }

  // Mostra o modal para selecionar o range de dificuldade
  Future<void> _showDifficultyFilter() async {
    RangeValues tempRange = _difficultyRange;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Filtrar por Dificuldade",
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    RangeSlider(
                      values: tempRange,
                      min: 1,
                      max: 7,
                      divisions: 6,
                      labels: RangeLabels(
                        'Nível ${tempRange.start.round()}',
                        'Nível ${tempRange.end.round()}',
                      ),
                      onChanged: (RangeValues values) {
                        setModalState(() {
                          tempRange = values;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                            7,
                            (index) => Text((index + 1).toString(),
                                style: Theme.of(context).textTheme.bodySmall)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _difficultyRange = tempRange;
                        });
                        _filterLibrary();
                        Navigator.pop(context);
                      },
                      child: const Text("Aplicar Filtro"),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content:
            const Text('Este recurso é exclusivo para assinantes Premium.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool shouldHideRecommendations = _searchController.text.isNotEmpty;

    return StoreConnector<AppState, _LibraryViewModel>(
      converter: (store) => _LibraryViewModel.fromStore(store),
      onInit: (store) {
        store.dispatch(LoadInProgressItemsAction());
        store.dispatch(LoadLibraryShelvesAction());
        store.dispatch(FetchRecommendedSermonsAction());
      },
      builder: (context, viewModel) {
        return Scaffold(
          body: Column(
            children: [
              // Barra de busca animada
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showSearchBar
                    ? Padding(
                        key: const ValueKey('searchBar'),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomSearchBar(
                                controller: _searchController,
                                hintText: "Buscar na biblioteca...",
                                onChanged: (value) => setState(() {}),
                                onClear: _clearSearchText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.auto_awesome,
                                  color: theme.colorScheme.primary),
                              tooltip: "Recomendação com IA",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const LibraryRecommendationPage()),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 16),
              ),

              // Corpo principal com scroll
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // --- SEÇÕES CONDICIONAIS ---
                    if (!shouldHideRecommendations) ...[
                      // "Continuar Lendo"
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: ContinueReadingRow(),
                        ),
                      ),

                      // Prateleiras dinâmicas do Firestore
                      ...viewModel.libraryShelves.map((shelfData) {
                        return SliverToBoxAdapter(
                          child: RecommendationRow(shelfData: shelfData),
                        );
                      }).toList(),

                      // "Sermões Recomendados"
                      if (viewModel.recommendedSermons.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Text("Sermões Recomendados",
                                      style: theme.textTheme.titleLarge),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 220,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    itemCount:
                                        1 + viewModel.recommendedSermons.length,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        final spurgeonResourceData =
                                            allLibraryItems.firstWhere(
                                          (item) =>
                                              item['id'] == 'spurgeon-sermoes',
                                          orElse: () => {},
                                        );
                                        if (spurgeonResourceData.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              right: 12.0),
                                          child: SizedBox(
                                            width: 120,
                                            child: CompactResourceCard(
                                              title:
                                                  spurgeonResourceData['title'],
                                              author: spurgeonResourceData[
                                                  'author'],
                                              coverImage: AssetImage(
                                                  spurgeonResourceData[
                                                      'coverImagePath']),
                                              onCardTap: () {
                                                Navigator.push(
                                                    context,
                                                    FadeScalePageRoute(
                                                        page: spurgeonResourceData[
                                                            'destinationPage']));
                                              },
                                              onExpandTap: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  builder: (ctx) =>
                                                      ResourceDetailModal(
                                                    itemData:
                                                        spurgeonResourceData,
                                                    onStartReading: () {
                                                      Navigator.pop(ctx);
                                                      Navigator.push(
                                                          context,
                                                          FadeScalePageRoute(
                                                              page: spurgeonResourceData[
                                                                  'destinationPage']));
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                      final sermonData = viewModel
                                          .recommendedSermons[index - 1];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12.0),
                                        child: RecommendedSermonCard(
                                            sermonData: sermonData),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],

                    // Título da grade principal
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? "Resultados da Busca"
                              : "Toda a Biblioteca",
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),

                    // --- Grade de Resultados ---
                    _filteredLibraryItems.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  _searchController.text.isNotEmpty
                                      ? "Nenhum livro encontrado para '${_searchController.text}'."
                                      : "Nenhum livro corresponde aos filtros aplicados.",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(16.0),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 140.0,
                                mainAxisExtent: 210.0,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final itemData = _filteredLibraryItems[index];
                                  final bool isFullyPremium =
                                      itemData['isFullyPremium'] == true;
                                  final String coverPath =
                                      itemData['coverImagePath'] ?? '';

                                  void startReadingAction() {
                                    AnalyticsService.instance
                                        .logLibraryResourceOpened(
                                            itemData['title']);
                                    if (isFullyPremium &&
                                        !viewModel.isPremium) {
                                      _showPremiumDialog(context);
                                    } else {
                                      if (!viewModel.isPremium) {
                                        interstitialManager.tryShowInterstitial(
                                            fromScreen:
                                                "Library_To_${itemData['title']}");
                                      }
                                      Navigator.push(
                                        context,
                                        FadeScalePageRoute(
                                            page: itemData['destinationPage']),
                                      );
                                    }
                                  }

                                  void openDetailsModal() {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => ResourceDetailModal(
                                        itemData: itemData,
                                        onStartReading: () {
                                          Navigator.pop(ctx);
                                          startReadingAction();
                                        },
                                      ),
                                    );
                                  }

                                  return CompactResourceCard(
                                    title: itemData['title'],
                                    author: itemData['author'],
                                    coverImage: coverPath.isNotEmpty
                                        ? AssetImage(coverPath)
                                        : null,
                                    isPremium: isFullyPremium,
                                    onCardTap: startReadingAction,
                                    onExpandTap: openDetailsModal,
                                  ).animate().fadeIn(
                                      duration: 400.ms,
                                      delay: (50 * (index % 15)).ms);
                                },
                                childCount: _filteredLibraryItems.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              // Barra de filtros inferior
              LibraryFilterBar(
                showFiction: _showFiction,
                showStudyGuide: _showStudyGuide,
                exclusiveFilter: _exclusiveFilter,
                difficultyRange: _difficultyRange,
                isAnyFilterActive: _isFilterOrSearchActive,
                onFictionTap: () => setState(() {
                  _exclusiveFilter =
                      (_exclusiveFilter == 'ficcao') ? null : null;
                  _showFiction = !_showFiction;
                  _filterLibrary();
                }),
                onFictionLongPress: () => setState(() {
                  _exclusiveFilter = 'ficcao';
                  _filterLibrary();
                }),
                onStudyGuideTap: () => setState(() {
                  _exclusiveFilter =
                      (_exclusiveFilter == 'isStudyGuide') ? null : null;
                  _showStudyGuide = !_showStudyGuide;
                  _filterLibrary();
                }),
                onStudyGuideLongPress: () => setState(() {
                  _exclusiveFilter = 'isStudyGuide';
                  _filterLibrary();
                }),
                onDifficultyTap: _showDifficultyFilter,
                onSearchOrClearTap: () {
                  if (_isFilterOrSearchActive) {
                    _clearAllFiltersAndSearch();
                    setState(() => _showSearchBar = false);
                    FocusScope.of(context).unfocus();
                  } else {
                    setState(() {
                      _showSearchBar = true;
                      _searchFocusNode.requestFocus();
                    });
                  }
                },
                isSearchActive: _showSearchBar,
                searchQuery: _searchController.text,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ 6. WIDGET DA BARRA DE FILTROS ATUALIZADO PARA ACEITAR NOVOS PARÂMETROS E EVENTOS
class LibraryFilterBar extends StatelessWidget {
  final bool showFiction;
  final bool showStudyGuide;
  final String? exclusiveFilter;
  final RangeValues difficultyRange;
  final bool isAnyFilterActive;
  final VoidCallback onFictionTap;
  final VoidCallback onFictionLongPress;
  final VoidCallback onStudyGuideTap;
  final VoidCallback onStudyGuideLongPress;
  final VoidCallback onDifficultyTap;

  // Parâmetros atualizados para a nova funcionalidade
  final VoidCallback onSearchOrClearTap;
  final bool isSearchActive;
  final String searchQuery;

  const LibraryFilterBar({
    super.key,
    required this.showFiction,
    required this.showStudyGuide,
    this.exclusiveFilter,
    required this.difficultyRange,
    required this.isAnyFilterActive,
    required this.onFictionTap,
    required this.onFictionLongPress,
    required this.onStudyGuideTap,
    required this.onStudyGuideLongPress,
    required this.onDifficultyTap,

    // Construtor atualizado
    required this.onSearchOrClearTap,
    required this.isSearchActive,
    required this.searchQuery,
  });

  // Widget auxiliar para construir os botões de filtro
  Widget _buildFilterButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required bool isActive,
    bool hasDropdown = false,
    int flex = 2,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Material(
        color: isActive
            ? theme.colorScheme.primary.withOpacity(0.15)
            : theme.cardColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasDropdown)
                  Icon(
                    Icons.arrow_drop_down,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Lógica para determinar o ícone e o estado do botão de busca/limpar
    IconData finalIcon;
    String tooltip;
    bool isFinalButtonActive = isSearchActive || isAnyFilterActive;

    if (isSearchActive) {
      if (searchQuery.isNotEmpty) {
        finalIcon =
            Icons.clear; // Mostra 'X' se a barra está visível e com texto
        tooltip = "Limpar Busca";
      } else {
        finalIcon = Icons.search; // Mostra lupa se a barra está visível e vazia
        tooltip = "Ocultar Busca";
      }
    } else {
      if (isAnyFilterActive) {
        finalIcon =
            Icons.tune; // Mostra 'tune' se a busca está oculta mas há filtros
        tooltip = "Limpar Filtros";
      } else {
        finalIcon = Icons.search; // Mostra lupa se tudo estiver limpo/oculto
        tooltip = "Buscar na Biblioteca";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Botão de Filtro: Ficção
          _buildFilterButton(
            context: context,
            icon: Icons.auto_stories_outlined,
            label: 'Ficção',
            onTap: onFictionTap,
            onLongPress: onFictionLongPress,
            isActive: exclusiveFilter == 'ficcao' ||
                (exclusiveFilter == null && showFiction),
            flex: 2,
          ),
          const SizedBox(width: 6),

          // Botão de Filtro: Guias
          _buildFilterButton(
            context: context,
            icon: Icons.school_outlined,
            label: 'Guias',
            onTap: onStudyGuideTap,
            onLongPress: onStudyGuideLongPress,
            isActive: exclusiveFilter == 'isStudyGuide' ||
                (exclusiveFilter == null && showStudyGuide),
            flex: 2,
          ),
          const SizedBox(width: 6),

          // Botão de Filtro: Dificuldade
          _buildFilterButton(
            context: context,
            icon: Icons.stacked_line_chart,
            label:
                '${difficultyRange.start.round()}-${difficultyRange.end.round()}',
            onTap: onDifficultyTap,
            onLongPress: onDifficultyTap,
            isActive: difficultyRange.start != 1 || difficultyRange.end != 7,
            hasDropdown: true,
            flex: 3,
          ),
          const SizedBox(width: 6),

          // Botão Final: Busca / Limpar / Tune
          Material(
            color: isFinalButtonActive
                ? theme.colorScheme.primary.withOpacity(0.15)
                : theme.cardColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onSearchOrClearTap,
              borderRadius: BorderRadius.circular(8),
              child: Tooltip(
                message: tooltip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Icon(
                    finalIcon,
                    size: 22,
                    color: isFinalButtonActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
