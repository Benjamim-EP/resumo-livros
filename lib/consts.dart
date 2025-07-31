// lib/consts.dart

// --- IDs de Produto para GOOGLE PLAY ---
const String googlePlayMonthlyProductId = "premium_monthly_v1";
const String googlePlayQuarterlyProductId = "premium_quarterly_v1";

// --- IDs de Preço para STRIPE (MODO DE TESTE) ---
const String stripeMonthlyPriceId = "price_1Rqx5GEKXwg5KYoEJFLzoGPd";
const String stripeQuarterlyPriceId = "price_1Rqx5qEKXwg5KYoE32jofD84";

// Mapeamento dos produtos para exibição na UI
// AGORA ESTE MAPA SERÁ DINÂMICO
List<Map<String, String>> getAvailableSubscriptions(bool isPlayStoreBuild) {
  if (isPlayStoreBuild) {
    return [
      {
        'id': googlePlayMonthlyProductId,
        'title': 'Plano Premium Mensal',
        'description':
            'Acesso a todos os recursos premium com renovação mensal.',
        'price': 'R\$ 19,99 / mês', // Adicione o preço para UI
      },
      {
        'id': googlePlayQuarterlyProductId,
        'title': 'Plano Premium Trimestral',
        'description': 'Economize com 3 meses de acesso premium.',
        'price': 'R\$ 47,99 / 3 meses', // Adicione o preço para UI
      },
    ];
  } else {
    // Versão do Site (Stripe)
    return [
      {
        'id': stripeMonthlyPriceId, // <<< USA O ID DA STRIPE
        'title': 'Plano Premium Mensal',
        'description':
            'Acesso a todos os recursos premium com renovação mensal.',
        'price': 'R\$ 19,99 / mês',
      },
      {
        'id': stripeQuarterlyPriceId, // <<< USA O ID DA STRIPE
        'title': 'Plano Premium Trimestral',
        'description': 'Economize com 3 meses de acesso premium.',
        'price': 'R\$ 47,99 / 3 meses',
      },
    ];
  }
}

const String guestUserCoinsPrefsKey = 'global_guest_user_coins_balance';
