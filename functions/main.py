# functions/main.py
import os
import stripe # Biblioteca oficial do Stripe
import firebase_admin
import google.auth # Import necessário
from firebase_admin import initialize_app, firestore, auth, credentials # Import necessário
from firebase_functions import https_fn, options
from datetime import datetime, timedelta, timezone
import asyncio

# --- Configuração ---
# Lê das variáveis de ambiente que serão populadas pelo Secret Manager via 'secrets=[...]'
# Acessar as variáveis aqui pode ser problemático no escopo global antes da função ser invocada.
# É mais seguro acessá-las dentro das funções que as declaram em secrets.
# stripe.api_key = os.environ.get("STRIPE_SECRET_KEY") # Mover para dentro das funções
# webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET") # Mover para dentro das funções

# --- Inicialização Explícita do Firebase Admin ---
if not firebase_admin._apps:
    try:
        app_creds, project_id = google.auth.default()
        print(f"Credenciais ADC encontradas para projeto: {project_id}")
        initialize_app(credential=credentials.ApplicationDefault())
        print("Firebase Admin SDK inicializado com Application Default Credentials.")
    except google.auth.exceptions.DefaultCredentialsError:
        print("ERRO CRÍTICO: Não foi possível encontrar as Default Credentials.")
        try:
            print("Tentando inicialização padrão do Firebase Admin SDK como fallback...")
            initialize_app()
            print("Firebase Admin SDK inicializado com credenciais padrão (fallback).")
        except Exception as e_fallback:
            print(f"Falha na inicialização padrão também: {e_fallback}")
            raise RuntimeError("Não foi possível inicializar o Firebase Admin SDK.") from e_fallback
    except ValueError as e_val:
         if "The default Firebase app already exists" in str(e_val):
              print("Firebase Admin SDK já inicializado (detectado por ValueError).")
         else:
              print(f"Erro de valor durante a inicialização do Firebase Admin: {e_val}")
              raise
    except Exception as e_init:
        print(f"Erro inesperado durante a inicialização do Firebase Admin: {e_init}")
        raise
else:
     print("Firebase Admin SDK já inicializado (detectado por _apps).")

# --- FIM DA INICIALIZAÇÃO ---

# Obtém o cliente Firestore
db = None # Inicializa como None
try:
    db = firestore.client()
except Exception as e:
     print(f"ERRO ao obter cliente Firestore: {e}. Verifique a inicialização do Firebase Admin.")
     # Funções que dependem de 'db' precisarão verificar se é None

# Define a região global
options.set_global_options(region=options.SupportedRegion.SOUTHAMERICA_EAST1)

# --- Funções Auxiliares (Firestore) ---

async def find_user_id_by_stripe_customer_id(stripe_customer_id: str) -> str | None:
    if db is None:
         print("ERRO Firestore (find_user_id): Cliente Firestore não inicializado.")
         return None
    try:
        # ... (código como antes) ...
        users_ref = db.collection('users')
        query = users_ref.where('stripeCustomerId', '==', stripe_customer_id).limit(1).stream()
        async for doc in query:
            print(f"Usuário encontrado no Firestore: {doc.id} para Customer {stripe_customer_id}")
            return doc.id
        print(f"AVISO Firestore: Usuário não encontrado para Stripe Customer {stripe_customer_id}")
        return None
    except Exception as e:
        print(f"ERRO Firestore (find_user_id_by_stripe_customer_id): {e}")
        return None


async def update_user_subscription_status(user_id: str, status: str, customer_id: str, subscription_id: str | None = None, end_date_unix: int | None = None, price_id: str | None = None):
    if db is None:
         print("ERRO Firestore (update_status): Cliente Firestore não inicializado.")
         return
    try:
        # ... (código como antes, usando firestore.DELETE_FIELD onde apropriado) ...
        user_ref = db.collection('users').doc(user_id)
        update_data = {
            'stripeCustomerId': customer_id,
            'subscriptionStatus': status,
        }
        if subscription_id: update_data['stripeSubscriptionId'] = subscription_id
        else: update_data['stripeSubscriptionId'] = firestore.DELETE_FIELD

        if end_date_unix: update_data['subscriptionEndDate'] = datetime.fromtimestamp(end_date_unix, timezone.utc)
        else: update_data['subscriptionEndDate'] = firestore.DELETE_FIELD

        if price_id: update_data['activePriceId'] = price_id
        else: update_data['activePriceId'] = firestore.DELETE_FIELD

        # Remove chaves com valor DELETE_FIELD se o campo já não existir,
        # ou apenas usa o mapa como está se quiser garantir a remoção.
        # A forma mais simples é deixar o Firestore lidar com None ou usar DELETE_FIELD

        await user_ref.set(update_data, merge=True) # Usa set com merge
        print(f"Firestore: Status da assinatura atualizado para usuário {user_id}: Status='{status}' End='{update_data.get('subscriptionEndDate')}'")

    except Exception as e:
        print(f"ERRO Firestore (update_user_subscription_status) para usuário {user_id}: {e}")


async def get_or_create_stripe_customer(email: str, name: str | None, user_id: str) -> str | None:
    if db is None:
         print("ERRO (get_or_create_stripe_customer): Cliente Firestore não inicializado.")
         return None
    # Acessa a chave API aqui, pois a função on_call garante que ela está disponível
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key:
         print("ERRO (get_or_create_stripe_customer): Chave Stripe não disponível.")
         return None # Ou lançar erro
    try:
        # ... (código como antes) ...
        customers = stripe.Customer.list(email=email, limit=1).data
        customer_id: str | None = None

        if customers:
            customer_id = customers[0].id
            print(f"Cliente Stripe encontrado: {customer_id}")
            if customers[0].metadata.get('userId') != user_id:
                 stripe.Customer.modify(customer_id, metadata={'userId': user_id})
                 print(f"Metadata do cliente Stripe {customer_id} atualizado com userId {user_id}")
        else:
            print(f"Criando novo cliente Stripe para: {email}")
            customer = stripe.Customer.create(email=email, name=name, metadata={'userId': user_id})
            customer_id = customer.id
            print(f"Novo cliente Stripe criado: {customer_id}")

        # Salva/Atualiza o ID no Firestore
        user_ref = db.collection('users').doc(user_id)
        await user_ref.set({'stripeCustomerId': customer_id}, merge=True)
        print(f"Firestore: stripeCustomerId {customer_id} salvo/confirmado para usuário {user_id}")

        return customer_id

    except stripe.error.StripeError as e:
        print(f"ERRO Stripe (get_or_create_stripe_customer): {e}")
        return None
    except Exception as e:
        print(f"ERRO Geral (get_or_create_stripe_customer): {e}")
        return None


# --- Callable Function (Chamada pelo App Flutter) ---

@https_fn.on_call(secrets=["STRIPE_SECRET_KEY"]) # Garante que a chave estará no ambiente
async def create_stripe_checkout(data: https_fn.CallableRequest) -> dict:
    if db is None: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Servidor não inicializado corretamente (Firestore).')
    # Acessa a chave API DENTRO da função, pois 'secrets' garante que está disponível
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Chave Stripe não configurada no servidor.')

    if not data.auth or not data.auth.uid: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    user_id = data.auth.uid
    price_id = data.data.get('priceId')
    is_subscription = data.data.get('isSubscription', False)

    if not price_id: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='priceId é obrigatório.')

    try:
        user_record = auth.get_user(user_id)
        email = user_record.email
        name = user_record.display_name
        if not email: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message='Email do usuário não encontrado.')

        customer_id = await get_or_create_stripe_customer(email, name, user_id)
        if not customer_id: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao obter/criar cliente Stripe.')

        response_data: dict[str, str | None] = {"customerId": customer_id}

        if is_subscription:
            # ... (Lógica de criar assinatura como antes) ...
            print(f"Criando assinatura para customer {customer_id} com price {price_id}")
            subscription = stripe.Subscription.create(
                customer=customer_id, items=[{'price': price_id}],
                payment_behavior='default_incomplete',
                payment_settings={'save_default_payment_method': 'on_subscription'},
                expand=['latest_invoice.payment_intent'], metadata={'priceId': price_id}
            )
            print(f"Assinatura criada: {subscription.id}, Status: {subscription.status}")

            latest_invoice = subscription.latest_invoice
            payment_intent = latest_invoice.payment_intent if latest_invoice else None
            client_secret = payment_intent.client_secret if payment_intent and hasattr(payment_intent, 'client_secret') else None

            response_data['subscriptionId'] = subscription.id
            response_data['status'] = subscription.status
            if client_secret: response_data['clientSecret'] = client_secret
            elif subscription.status != 'active':
                 print(f"ERRO: Assinatura {subscription.id} criada com status {subscription.status} mas sem client_secret.")
                 raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao obter detalhes de pagamento da assinatura.')
        else:
            # ... (Lógica de criar PaymentIntent como antes) ...
            try:
                price_object = stripe.Price.retrieve(price_id)
                amount = price_object.unit_amount
                currency = price_object.currency
                if not amount: raise ValueError("Preço sem valor unitário.")
            except stripe.error.StripeError as e:
                print(f"ERRO ao buscar preço {price_id} no Stripe: {e}")
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao obter detalhes do preço.')

            print(f"Criando PaymentIntent para customer {customer_id}, price {price_id}, amount {amount}")
            payment_intent = stripe.PaymentIntent.create(
                amount=amount, currency=currency, customer=customer_id,
                payment_method_types=['card'], metadata={'priceId': price_id}
            )
            print(f"PaymentIntent criado: {payment_intent.id}")
            response_data['clientSecret'] = payment_intent.client_secret


        return response_data

    except stripe.error.StripeError as e:
        print(f"ERRO Stripe (create_stripe_checkout): {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro Stripe: {e.user_message or str(e)}')
    except Exception as e:
        print(f"ERRO Geral (create_stripe_checkout): {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Ocorreu um erro interno: {str(e)}')


# --- HTTP Function (Webhook Handler) ---

def _run_async_handler(async_func):
    try: loop = asyncio.get_running_loop()
    except RuntimeError: loop = asyncio.new_event_loop(); asyncio.set_event_loop(loop)
    return loop.run_until_complete(async_func)


@https_fn.on_request(secrets=["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"]) # Garante que ambas estarão no ambiente
def stripe_webhook_handler(req: https_fn.Request) -> https_fn.Response:
    if db is None: print("ERRO Webhook: Cliente Firestore não inicializado."); return https_fn.Response("Erro interno.", status=500)

    # Acessa as variáveis DENTRO da função
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET")

    if not stripe.api_key: print("ERRO Webhook: Chave API Stripe não carregada."); return https_fn.Response("Erro config.", status=500)
    if not webhook_secret: print("ERRO Webhook: Segredo Webhook não carregado."); return https_fn.Response("Erro config.", status=500)

    signature = req.headers.get("stripe-signature")
    if not signature: print("ERRO Webhook: Assinatura ausente."); return https_fn.Response("Assinatura ausente.", status=400)

    try:
        event = stripe.Webhook.construct_event(
            req.data, signature, webhook_secret
        )
        print(f"Webhook recebido e VERIFICADO: ID={event.id}, Tipo={event.type}")
    except ValueError as e: print(f"ERRO Webhook: Payload inválido - {e}"); return https_fn.Response("Payload inválido.", status=400)
    except stripe.error.SignatureVerificationError as e: print(f"ERRO Webhook: Falha na verificação da assinatura - {e}"); return https_fn.Response("Assinatura inválida.", status=400)
    except Exception as e: print(f"ERRO Webhook: Erro construção evento - {e}"); return https_fn.Response("Erro interno.", status=500)

    # --- Processamento de Eventos ---
    event_data = event.data.object
    customer_id = event_data.get('customer') # Mais seguro usar .get()
    user_id = None # Inicializa user_id

    if customer_id:
         user_id = _run_async_handler(find_user_id_by_stripe_customer_id(str(customer_id)))
    else:
         print(f"Aviso Webhook: Evento {event.type} ({event_data.get('id')}) sem customerId.")
         # Alguns eventos podem não ter customer (ex: checkout.session.completed sem customer pré-definido)
         # Você pode precisar buscar o customer de outra forma nesses casos se necessário.

    if not user_id and event.type not in ['checkout.session.completed']: # Ignora se não achar user_id (exceto checkout talvez)
        print(f"AVISO Webhook: Não foi possível encontrar usuário para evento {event.type}. Ignorando atualização.")
        return https_fn.Response(status=200, body='{"user_not_found_or_not_needed": true}')

    try:
        if event.type == 'payment_intent.succeeded':
            print(f"Processando payment_intent.succeeded: {event_data.get('id')}")
            price_id = event_data.get('metadata', {}).get('priceId')
            if user_id: # Garante que temos o user_id
                 end_date_unix = None
                 # Adicione sua lógica para calcular end_date_unix baseado no price_id
                 # Exemplo placeholder:
                 if price_id: end_date_unix = int((datetime.now(timezone.utc) + timedelta(days=30)).timestamp())

                 _run_async_handler(update_user_subscription_status(
                     user_id=user_id, status='active', customer_id=str(customer_id),
                     end_date_unix=end_date_unix, price_id=price_id
                 ))

        elif event.type == 'invoice.paid':
            print(f"Processando invoice.paid: {event_data.get('id')}")
            subscription_id = event_data.get('subscription')
            if user_id and subscription_id:
                try:
                    subscription = stripe.Subscription.retrieve(str(subscription_id))
                    price_id = subscription.items.data[0].price.id if subscription.items.data else None
                    _run_async_handler(update_user_subscription_status(
                        user_id=user_id, status=subscription.status, customer_id=str(customer_id),
                        subscription_id=str(subscription_id), end_date_unix=subscription.current_period_end,
                        price_id=price_id
                    ))
                except stripe.error.StripeError as e: print(f"ERRO ao buscar assinatura {subscription_id} após invoice.paid: {e}")
            elif not user_id: print(f"AVISO Webhook: Usuário não encontrado para invoice.paid {event_data.get('id')}.")
            elif not subscription_id : print(f"AVISO Webhook: invoice.paid {event_data.get('id')} sem subscriptionId.")


        elif event.type == 'customer.subscription.updated':
            print(f"Processando customer.subscription.updated: {event_data.get('id')}")
            subscription_id = event_data.get('id')
            status = event_data.get('status')
            period_end = event_data.get('current_period_end')
            price_id = event_data.get('items', {}).get('data', [{}])[0].get('price', {}).get('id') # Acesso mais seguro
            if user_id and subscription_id and status and period_end:
                _run_async_handler(update_user_subscription_status(
                    user_id=user_id, status=str(status), customer_id=str(customer_id),
                    subscription_id=str(subscription_id), end_date_unix=int(period_end),
                    price_id=price_id
                ))
            elif not user_id: print(f"AVISO Webhook: Usuário não encontrado para customer.subscription.updated {event_data.get('id')}.")
            else: print(f"AVISO Webhook: Dados incompletos para customer.subscription.updated {event_data.get('id')}.")


        elif event.type == 'customer.subscription.deleted':
            print(f"Processando customer.subscription.deleted: {event_data.get('id')}")
            subscription_id = event_data.get('id')
            status = event_data.get('status') # 'canceled'
            if user_id and subscription_id and status:
                 _run_async_handler(update_user_subscription_status(
                    user_id=user_id, status=str(status), customer_id=str(customer_id),
                    subscription_id=str(subscription_id), end_date_unix=None, price_id=None
                ))
            elif not user_id: print(f"AVISO Webhook: Usuário não encontrado para customer.subscription.deleted {event_data.get('id')}.")
            else: print(f"AVISO Webhook: Dados incompletos para customer.subscription.deleted {event_data.get('id')}.")


        else: print(f'Webhook não tratado: {event.type}')

        return https_fn.Response(status=200, body='{"received_verified": true}')

    except Exception as e:
         print(f"ERRO Webhook: Erro ao processar evento {event.type} - {e}")
         # Retornar 200 mesmo em erro de processamento para evitar retentativas do Stripe
         # a menos que seja um erro que você queira que ele tente novamente.
         return https_fn.Response(status=200, body='{"error_processing": true}')