// lib/consts/bible_constants.dart

// Mapeamento de abreviação do livro para o Testamento
const Map<String, String> BOOK_TO_TESTAMENT_MAP = {
  "gn": "Antigo", "ex": "Antigo", "lv": "Antigo", "nm": "Antigo",
  "dt": "Antigo",
  "js": "Antigo", "jz": "Antigo", "rt": "Antigo",
  "1sm": "Antigo", "2sm": "Antigo", "1rs": "Antigo", "2rs": "Antigo",
  "1cr": "Antigo", "2cr": "Antigo", "ed": "Antigo", "ne": "Antigo",
  "et": "Antigo",
  "job": "Antigo", // Jó
  "sl": "Antigo", "pv": "Antigo", "ec": "Antigo", "ct": "Antigo",
  "is": "Antigo", "jr": "Antigo", "lm": "Antigo", "ez": "Antigo",
  "dn": "Antigo",
  "os": "Antigo", "jl": "Antigo", "am": "Antigo", "ob": "Antigo",
  "jn": "Antigo",
  "mq": "Antigo", "na": "Antigo", "hc": "Antigo", "sf": "Antigo",
  "ag": "Antigo",
  "zc": "Antigo", "ml": "Antigo",
  "mt": "Novo", "mc": "Novo", "lc": "Novo", "jo": "Novo", // João
  "at": "Novo", "rm": "Novo",
  "1co": "Novo", "2co": "Novo", "gl": "Novo", "ef": "Novo", "fp": "Novo",
  "cl": "Novo", "1ts": "Novo", "2ts": "Novo",
  "1tm": "Novo", "2tm": "Novo", "tt": "Novo", "fm": "Novo", "hb": "Novo",
  "tg": "Novo", "1pe": "Novo", "2pe": "Novo",
  "1jo": "Novo", "2jo": "Novo", "3jo": "Novo", "jd": "Novo", "ap": "Novo"
};

// Ordem canônica dos livros da Bíblia (usando as abreviações)
const List<String> CANONICAL_BOOK_ORDER = [
  // Antigo Testamento
  "gn", "ex", "lv", "nm", "dt", // Pentateuco
  "js", "jz", "rt", // Históricos
  "1sm", "2sm", "1rs", "2rs", "1cr", "2cr", "ed", "ne", "et", // Históricos
  "job", "sl", "pv", "ec", "ct", // Poéticos e Sapienciais
  "is", "jr", "lm", "ez", "dn", // Profetas Maiores
  "os", "jl", "am", "ob", "jn", "mq", "na", "hc", "sf", "ag", "zc",
  "ml", // Profetas Menores
  // Novo Testamento
  "mt", "mc", "lc", "jo", // Evangelhos
  "at", // Histórico
  "rm", "1co", "2co", "gl", "ef", "fp", "cl", // Epístolas Paulinas
  "1ts", "2ts", "1tm", "2tm", "tt",
  "fm", // Epístolas Paulinas (Pastorais e Pessoal)
  "hb", // Epístola aos Hebreus
  "tg", "1pe", "2pe", "1jo", "2jo", "3jo", "jd", // Epístolas Gerais (Católicas)
  "ap" // Apocalíptico
];

// Mapeamento de abreviação para nome completo (opcional, mas pode ser útil ter aqui)
// Se você já tem isso em BiblePageHelper.loadBooksMap() ou _localBooksMap em UserPage,
// pode não precisar duplicar, mas ter como constante pode ser útil em alguns contextos.
const Map<String, String> ABBREV_TO_FULL_NAME_MAP = {
  "gn": "Gênesis", "ex": "Êxodo", "lv": "Levítico", "nm": "Números",
  "dt": "Deuteronômio",
  "js": "Josué", "jz": "Juízes", "rt": "Rute",
  "1sm": "1 Samuel", "2sm": "2 Samuel", "1rs": "1 Reis", "2rs": "2 Reis",
  "1cr": "1 Crônicas", "2cr": "2 Crônicas", "ed": "Esdras", "ne": "Neemias",
  "et": "Ester",
  "job": "Jó",
  "sl": "Salmos", "pv": "Provérbios", "ec": "Eclesiastes",
  "ct": "Cantares de Salomão", // Ou só "Cantares"
  "is": "Isaías", "jr": "Jeremias",
  "lm": "Lamentações de Jeremias", // Ou só "Lamentações"
  "ez": "Ezequiel", "dn": "Daniel",
  "os": "Oseias", "jl": "Joel", "am": "Amós", "ob": "Obadias", "jn": "Jonas",
  "mq": "Miqueias", "na": "Naum", "hc": "Habacuque", "sf": "Sofonias",
  "ag": "Ageu",
  "zc": "Zacarias", "ml": "Malaquias",
  "mt": "Mateus", "mc": "Marcos", "lc": "Lucas", "jo": "João",
  "at": "Atos dos Apóstolos", // Ou só "Atos"
  "rm": "Romanos",
  "1co": "1 Coríntios", "2co": "2 Coríntios", "gl": "Gálatas", "ef": "Efésios",
  "fp": "Filipenses",
  "cl": "Colossenses", "1ts": "1 Tessalonicenses", "2ts": "2 Tessalonicenses",
  "1tm": "1 Timóteo", "2tm": "2 Timóteo", "tt": "Tito", "fm": "Filemom",
  "hb": "Hebreus", "tg": "Tiago", "1pe": "1 Pedro", "2pe": "2 Pedro",
  "1jo": "1 João", "2jo": "2 João", "3jo": "3 João", "jd": "Judas",
  "ap": "Apocalipse de João" // Ou só "Apocalipse"
};
