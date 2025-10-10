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
  bool _isSearchActive = false;

  // Estado dos filtros
  bool _showFiction = true; // Inicia como true para mostrar por padrão
  bool _showStudyGuide = true; // Inicia como true para mostrar por padrão
  RangeValues _difficultyRange = const RangeValues(1, 7);

  // Nova variável para controlar o modo de filtro exclusivo (ativado com long press)
  String? _exclusiveFilter; // Pode ser 'ficcao', 'isStudyGuide', ou null

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
    _filteredLibraryItems = allLibraryItems;
    _searchController.addListener(_filterLibrary);
    // Chama o filtro uma vez no início para garantir que o estado inicial seja aplicado
    _filterLibrary();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterLibrary);
    _searchController.dispose();
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
    List<Map<String, dynamic>> filtered = allLibraryItems;

    // --- Lógica Principal de Filtro (Ficção e Guias) ---
    if (_exclusiveFilter != null) {
      // MODO EXCLUSIVO: Mostra apenas o tipo selecionado
      if (_exclusiveFilter == 'ficcao') {
        filtered = filtered.where((item) => item['ficcao'] == true).toList();
      } else if (_exclusiveFilter == 'isStudyGuide') {
        filtered =
            filtered.where((item) => item['isStudyGuide'] == true).toList();
      }
    } else {
      // MODO NORMAL (EXCLUSÃO): Esconde os tipos desmarcados
      if (!_showFiction) {
        filtered = filtered.where((item) => item['ficcao'] != true).toList();
      }
      if (!_showStudyGuide) {
        filtered =
            filtered.where((item) => item['isStudyGuide'] != true).toList();
      }
    }

    // --- Filtros Adicionais (aplicados sobre o resultado anterior) ---
    // Filtro de Dificuldade
    filtered = filtered.where((item) {
      final difficulty = item['dificuldade'] as int? ?? 1; // Padrão 1 se nulo
      return difficulty >= _difficultyRange.start &&
          difficulty <= _difficultyRange.end;
    }).toList();

    // Filtro de Busca por Texto
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

    // Atualiza o estado da UI com a lista final filtrada
    setState(() => _filteredLibraryItems = filtered);
  }

  // Limpa apenas o texto da barra de busca
  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  // Limpa TODOS os filtros e reseta a lista
  void _clearAllFilters() {
    setState(() {
      _showFiction = true;
      _showStudyGuide = true;
      _exclusiveFilter = null;
      _difficultyRange = const RangeValues(1, 7);
    });
    _filterLibrary(); // Reaplica os filtros (agora zerados)
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
              // ✅ ETAPA 1: BARRA DE BUSCA CONDICIONAL COM ANIMAÇÃO
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _isSearchActive
                      ? Padding(
                          key: const ValueKey('searchBar'),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: CustomSearchBar(
                                  controller: _searchController,
                                  hintText: "Buscar na biblioteca...",
                                  onChanged: (value) {},
                                  onClear: _clearSearch,
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
                      : const SizedBox(
                          key: ValueKey('empty'),
                          height: 16), // Espaço quando a busca está oculta
                ),
              ),

              // --- CORPO PRINCIPAL COM SCROLL UNIFICADO ---
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Sliver 1: Seção "Continuar Lendo"
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: ContinueReadingRow(),
                      ),
                    ),

                    // Sliver 2: Renderiza dinamicamente as prateleiras de recomendação
                    ...viewModel.libraryShelves.map((shelfData) {
                      return SliverToBoxAdapter(
                        child: RecommendationRow(shelfData: shelfData),
                      );
                    }).toList(),
// ==========================================================
                    // <<< INÍCIO DA NOVA SEÇÃO DE SERMÕES >>>
                    // ==========================================================
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
                                height: 220, // Altura da prateleira horizontal
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  // +1 para o card estático que leva ao índice
                                  itemCount:
                                      1 + viewModel.recommendedSermons.length,
                                  itemBuilder: (context, index) {
                                    // 1. O primeiro item (index 0) é o card estático
                                    if (index == 0) {
                                      // Busca os dados do recurso "Sermões de Spurgeon" na lista global
                                      final spurgeonResourceData =
                                          allLibraryItems.firstWhere(
                                        (item) =>
                                            item['id'] == 'spurgeon-sermoes',
                                        orElse: () => {},
                                      );

                                      if (spurgeonResourceData.isEmpty) {
                                        return const SizedBox
                                            .shrink(); // Não renderiza se não encontrar
                                      }

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12.0),
                                        child: CompactResourceCard(
                                          title: spurgeonResourceData['title'],
                                          author:
                                              spurgeonResourceData['author'],
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
                                            // Você pode adicionar um modal de detalhes aqui se quiser
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (ctx) =>
                                                  ResourceDetailModal(
                                                itemData: spurgeonResourceData,
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
                                      );
                                    }

                                    // 2. O resto dos itens são os sermões recomendados
                                    // (index - 1 para ajustar o índice da lista)
                                    final sermonData =
                                        viewModel.recommendedSermons[index - 1];
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
                    // ==========================================================
                    // <<< FIM DA NOVA SEÇÃO DE SERMÕES >>>
                    // ==========================================================
                    // Sliver 3: Título para a grade completa de livros
                    if (_filteredLibraryItems.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: Text(
                            "Toda a Biblioteca",
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),

                    // Sliver 4: A grade com todos os livros da biblioteca (filtrados)
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.5,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final itemData = _filteredLibraryItems[index];
                            final bool isFullyPremium =
                                itemData['isFullyPremium'] == true;
                            final String coverPath =
                                itemData['coverImagePath'] ?? '';

                            // Lógica completa para o toque no card
                            void startReadingAction() {
                              AnalyticsService.instance
                                  .logLibraryResourceOpened(itemData['title']);
                              if (isFullyPremium && !viewModel.isPremium) {
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

                            // Lógica completa para o menu de detalhes
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

                    // Sliver 5: Mensagem para quando a busca ou filtro não retorna resultados
                    if (_filteredLibraryItems.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                              "Nenhum item encontrado com os filtros aplicados."),
                        ),
                      ),
                  ],
                ),
              ),

              // --- BARRA DE FILTROS INFERIOR ---
              LibraryFilterBar(
                showFiction: _showFiction,
                showStudyGuide: _showStudyGuide,
                exclusiveFilter: _exclusiveFilter,
                difficultyRange: _difficultyRange,
                isAnyFilterActive: _isAnyFilterActive,
                onFictionTap: () {
                  setState(() {
                    if (_exclusiveFilter == 'ficcao') {
                      _exclusiveFilter = null;
                    } else {
                      _exclusiveFilter = null;
                      _showFiction = !_showFiction;
                    }
                  });
                  _filterLibrary();
                },
                onFictionLongPress: () {
                  setState(() => _exclusiveFilter = 'ficcao');
                  _filterLibrary();
                },
                onStudyGuideTap: () {
                  setState(() {
                    if (_exclusiveFilter == 'isStudyGuide') {
                      _exclusiveFilter = null;
                    } else {
                      _exclusiveFilter = null;
                      _showStudyGuide = !_showStudyGuide;
                    }
                  });
                  _filterLibrary();
                },
                onStudyGuideLongPress: () {
                  setState(() => _exclusiveFilter = 'isStudyGuide');
                  _filterLibrary();
                },
                onDifficultyTap: _showDifficultyFilter,
                // ✅ AÇÃO DO BOTÃO DE BUSCA/LIMPAR
                onSearchOrClearTap: () {
                  if (_isSearchActive) {
                    // Se a busca está ativa e o campo tem texto, limpa o campo
                    if (_searchController.text.isNotEmpty) {
                      _clearSearch();
                    } else {
                      // Se a busca está ativa mas o campo está vazio, oculta a barra
                      setState(() => _isSearchActive = false);
                    }
                  } else {
                    // Se a busca não está ativa, mostra a barra
                    setState(() => _isSearchActive = true);
                  }
                },
                // Passa o estado atual para o botão saber qual ícone mostrar
                isSearchActive: _isSearchActive,
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
