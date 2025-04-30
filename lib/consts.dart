const String stripePublishableKey =
    "pk_test_51MQfXdEKXwg5KYoEc3wTnfg06SZm9WSSEcoDkZ5sR6adcExjGUm59pbmotMXeWA7No8r6TpAfsshTnJ4BAsF2VxH00zRDnMeuv";
const String stripeSecretKey =
    "sk_test_51MQfXdEKXwg5KYoEt4rIlFNA5zEi0q2fyFQ8LCHQmdvLpPTzYXmtQLKfEzNBnBjinsFIYivdUpA9UigBgz4Snaoa00AlgYk41g";

// --- Stripe Product/Price IDs (Exemplos - Substitua pelos seus IDs reais do Stripe Test) ---
const String stripePriceIdMonthly =
    "price_1QubnvEKXwg5KYoEy37AgPZq"; // ID do Preço Mensal (Pagamento Único ou Primeiro da Assinatura)
const String stripePriceIdRecurring =
    "price_1QuboKEKXwg5KYoEtlbkQLR1"; // ID do Preço da Assinatura Recorrente
const String stripePriceIdQuarterly =
    "price_1QuborEKXwg5KYoEMaset6VY"; // ID do Preço Trimestral (Pagamento Único)

// Mapeamento para facilitar (opcional)
const Map<String, String> stripeProductPriceMap = {
  'monthly': stripePriceIdMonthly,
  'recurring': stripePriceIdRecurring,
  'quarterly': stripePriceIdQuarterly,
};

// Mapeamento de IDs de Preço para valores em centavos (para criar PaymentIntent - REMOVER EM PRODUÇÃO)
// Isso deve ser determinado no backend baseado no Price ID
const Map<String, int> stripePriceAmountMap = {
  stripePriceIdMonthly: 1999, // R$ 19.99
  stripePriceIdRecurring: 1999, // R$ 19.99
  stripePriceIdQuarterly: 4797, // R$ 47.97
};
