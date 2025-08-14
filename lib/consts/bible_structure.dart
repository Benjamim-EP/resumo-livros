// lib/consts/bible_structure.dart

// Classe para representar uma seção dentro de um testamento (ex: "Pentateuco")
class BibleSection {
  final String title;
  final String description;
  final List<String> bookAbbrevs;

  const BibleSection({
    required this.title,
    required this.description,
    required this.bookAbbrevs,
  });
}

// Classe para representar um testamento completo
class Testament {
  final String title;
  final String description;
  final List<BibleSection> sections;

  const Testament({
    required this.title,
    required this.description,
    required this.sections,
  });
}

// ==========================================================
// <<< ESTRUTURA COMPLETA DA BÍBLIA >>>
// ==========================================================
const Testament OLD_TESTAMENT_STRUCTURE = Testament(
  title: 'Antigo Testamento',
  description: '',
  sections: [
    BibleSection(
      title: 'Pentateuco (A Lei / Torá)',
      description:
          'Os cinco primeiros livros, atribuídos a Moisés. Contêm a lei de Deus, a história da criação, dos patriarcas e da formação da nação de Israel.',
      bookAbbrevs: ['gn', 'ex', 'lv', 'nm', 'dt'],
    ),
    BibleSection(
      title: 'Livros Históricos',
      description:
          'Narram a história de Israel desde a conquista da terra prometida até o retorno do exílio na Babilônia.',
      bookAbbrevs: [
        'js',
        'jz',
        'rt',
        '1sm',
        '2sm',
        '1rs',
        '2rs',
        '1cr',
        '2cr',
        'ed',
        'ne',
        'et'
      ],
    ),
    BibleSection(
      title: 'Livros Poéticos (Sabedoria)',
      description:
          'Livros escritos em forma de poesia, cânticos e provérbios que expressam a sabedoria divina e a experiência humana com Deus.',
      bookAbbrevs: ['job', 'sl', 'pv', 'ec', 'ct'],
    ),
    BibleSection(
      title: 'Profetas Maiores',
      description:
          'Mensagens de Deus através de seus profetas. A distinção se dá pelo tamanho dos livros, não pela importância.',
      bookAbbrevs: ['is', 'jr', 'lm', 'ez', 'dn'],
    ),
    BibleSection(
      title: 'Profetas Menores',
      description:
          'Doze livros proféticos mais curtos, com advertências, exortações e promessas para Israel e outras nações.',
      bookAbbrevs: [
        'os',
        'jl',
        'am',
        'ob',
        'jn',
        'mq',
        'na',
        'hc',
        'sf',
        'ag',
        'zc',
        'ml'
      ],
    ),
  ],
);

const Testament NEW_TESTAMENT_STRUCTURE = Testament(
  title: 'Novo Testamento',
  description: '',
  sections: [
    BibleSection(
      title: 'Evangelhos',
      description:
          'Quatro relatos da vida, morte e ressurreição de Jesus Cristo, cada um com uma perspectiva única.',
      bookAbbrevs: ['mt', 'mc', 'lc', 'jo'],
    ),
    BibleSection(
      title: 'Livro Histórico',
      description:
          'Narra o surgimento e a expansão da igreja cristã após a ascensão de Jesus, focando nos ministérios de Pedro e Paulo.',
      bookAbbrevs: ['at'],
    ),
    BibleSection(
      title: 'Epístolas Paulinas',
      description:
          'Cartas escritas pelo apóstolo Paulo para congregações ou indivíduos, tratando de questões teológicas, doutrinárias e práticas.',
      bookAbbrevs: [
        'rm',
        '1co',
        '2co',
        'gl',
        'ef',
        'fp',
        'cl',
        '1ts',
        '2ts',
        '1tm',
        '2tm',
        'tt',
        'fm'
      ],
    ),
    BibleSection(
      title: 'Epístolas Gerais',
      description:
          'Cartas escritas por outros apóstolos e líderes da igreja primitiva para a igreja em geral.',
      bookAbbrevs: ['hb', 'tg', '1pe', '2pe', '1jo', '2jo', '3jo', 'jd'],
    ),
    BibleSection(
      title: 'Livro Profético (Apocalíptico)',
      description:
          'O último livro da Bíblia, que revela, através de linguagem simbólica, os eventos do fim dos tempos e a vitória final de Cristo.',
      bookAbbrevs: ['ap'],
    ),
  ],
);
