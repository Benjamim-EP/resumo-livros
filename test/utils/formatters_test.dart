// test/utils/formatters_test.dart

import 'package:flutter_test/flutter_test.dart';
// Precisaremos instanciar a classe para acessar o método não estático
import 'package:septima_biblia/components/buttons/reward_cooldown_timer.dart';
// A função aqui é estática, então podemos chamar diretamente
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';

void main() {
  group('formatDuration', () {
    // ✅ CORREÇÃO: Não precisamos mais de uma instância. Chamamos o método estático diretamente.

    test('deve formatar durações menores que um minuto em segundos', () {
      expect(
          RewardCooldownTimer.formatDuration(const Duration(seconds: 0)), '1s');
      expect(
          RewardCooldownTimer.formatDuration(const Duration(seconds: 1)), '2s');
      expect(RewardCooldownTimer.formatDuration(const Duration(seconds: 59)),
          '60s');
    });

    test(
        'deve formatar durações entre um minuto e uma hora em minutos e segundos',
        () {
      expect(RewardCooldownTimer.formatDuration(const Duration(seconds: 60)),
          '1m 0s');
      expect(RewardCooldownTimer.formatDuration(const Duration(seconds: 70)),
          '1m 10s');
      expect(
          RewardCooldownTimer.formatDuration(
              const Duration(minutes: 59, seconds: 30)),
          '59m 30s');
    });

    test('deve formatar durações maiores que uma hora em horas e minutos', () {
      expect(RewardCooldownTimer.formatDuration(const Duration(hours: 1)),
          '1h 0m');
      expect(
          RewardCooldownTimer.formatDuration(
              const Duration(hours: 2, minutes: 15)),
          '2h 15m');
      expect(
          RewardCooldownTimer.formatDuration(
              const Duration(hours: 5, minutes: 59, seconds: 59)),
          '5h 59m');
    });
  });

  group('cleanLexiconEntry', () {
    test('deve remover prefixos numéricos simples', () {
      expect(
          BiblePageWidgets.cleanLexiconEntry('1) governantes'), 'governantes');
      expect(BiblePageWidgets.cleanLexiconEntry('2. juízes'), 'juízes');
    });

    test('deve remover prefixos com letras', () {
      expect(BiblePageWidgets.cleanLexiconEntry('1a) anjos'), 'anjos');
      expect(BiblePageWidgets.cleanLexiconEntry('2b. deuses'), 'deuses');
    });

    test('deve remover prefixos com parênteses', () {
      expect(BiblePageWidgets.cleanLexiconEntry('(c) plural'), 'plural');
      expect(BiblePageWidgets.cleanLexiconEntry('(1d) Deus'), 'Deus');
    });

    test('deve remover prefixos múltiplos e complexos', () {
      expect(BiblePageWidgets.cleanLexiconEntry('2) 1a) governantes, juízes'),
          'governantes, juízes');
      expect(BiblePageWidgets.cleanLexiconEntry('   (3). b.  texto limpo'),
          'texto limpo');
    });

    test('não deve alterar texto que não tem prefixo', () {
      expect(BiblePageWidgets.cleanLexiconEntry('Texto sem prefixo'),
          'Texto sem prefixo');
      expect(BiblePageWidgets.cleanLexiconEntry('Deus'), 'Deus');
    });
  });
}
