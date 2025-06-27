// --- Google Play Product IDs ---
const String googlePlayMonthlyProductId =
    "premium_monthly_v1"; // ID REAL DO PLAY CONSOLE
const String googlePlayQuarterlyProductId =
    "premium_quarterly_v1"; // ID REAL DO PLAY CONSOLE

// Mapeamento dos produtos para exibição na UI
const List<Map<String, String>> availableSubscriptions = [
  {
    'id': googlePlayMonthlyProductId,
    'title': 'Plano Premium Mensal',
    'description': 'Acesso a todos os recursos premium com renovação mensal.',
  },
  {
    'id': googlePlayQuarterlyProductId,
    'title': 'Plano Premium Trimestral',
    'description': 'Economize com 3 meses de acesso premium.',
  },
];

const String guestUserCoinsPrefsKey = 'global_guest_user_coins_balance';
