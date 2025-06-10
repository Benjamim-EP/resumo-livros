# functions/main.py
import os
import sys # Para manipulação de path, se necessário para imports locais
import stripe
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, auth, credentials
from firebase_functions import https_fn, options # options para configuração global
from datetime import datetime, timedelta, timezone
import asyncio
import traceback

print(">>>> main.py (VERSÃO COMPLETA - TENTATIVA DE CORREÇÃO DE CHAVE) <<<<") # Nova lin
try:
    import bible_search_service
    print("Módulo 'bible_search_service' importado com sucesso.")
except ImportError as e_import:
    print(f"ERRO CRÍTICO: Falha ao importar 'bible_search_service': {e_import}")
    # Em um cenário real, você pode querer que o deploy falhe aqui se este módulo é essencial.
    # No entanto, para depuração, podemos permitir que continue e as funções que dependem dele falharão.
    bible_search_service = None # Define como None para verificações posteriores
except Exception as e_generic_import:
    print(f"ERRO CRÍTICO INESPERADO ao importar 'bible_search_service': {e_generic_import}")
    bible_search_service = None

try:
    import sermons_service # NOVO
    print("Módulo 'sermons_service' importado com sucesso.")
except ImportError as e_import_sermon:
    print(f"ERRO CRÍTICO: Falha ao importar 'sermons_service': {e_import_sermon}")
    sermons_service = None
except Exception as e_generic_import_sermon:
    print(f"ERRO CRÍTICO INESPERADO ao importar 'sermons_service': {e_generic_import_sermon}")
    sermons_service = None


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

# Obtém o cliente Firestore
db = None
try:
    db = firestore.client()
    print("Cliente Firestore obtido com sucesso.")
except Exception as e:
     print(f"ERRO ao obter cliente Firestore: {e}. Verifique a inicialização do Firebase Admin.")
     db = None

# Define a região global para as Cloud Functions
options.set_global_options(region=options.SupportedRegion.SOUTHAMERICA_EAST1)
print(f"Região global das Firebase Functions definida para: {options.SupportedRegion.SOUTHAMERICA_EAST1}")

# --- Constantes de Preços (Ajuste com seus IDs reais de teste do Stripe) ---
STRIPE_PRICE_ID_MONTHLY = "price_1QuborEKXwg5KYoEMaset6VY"
STRIPE_PRICE_ID_RECURRING = "price_1QuboKEKXwg5KYoEtlbkQLR1"
STRIPE_PRICE_ID_QUARTERLY = "price_1QubpLEKXwg5KYoE5Z2kR3sN"

# --- Funções Auxiliares (Firestore - Async) ---
async def find_user_id_by_stripe_customer_id(stripe_customer_id: str) -> str | None:
    if db is None:
        print("ERRO Firestore (find_user_id): Cliente Firestore não inicializado.")
        return None
    try:
        users_ref = db.collection('users')
        query_snapshot_list = await asyncio.to_thread(
            lambda: list(users_ref.where('stripeCustomerId', '==', stripe_customer_id).limit(1).stream())
        )
        if query_snapshot_list:
            doc = query_snapshot_list[0]
            print(f"Usuário encontrado no Firestore: {doc.id} para Customer {stripe_customer_id}")
            return doc.id
        print(f"AVISO Firestore: Usuário não encontrado para Stripe Customer {stripe_customer_id}")
        return None
    except Exception as e:
        print(f"ERRO Firestore (find_user_id_by_stripe_customer_id): {e}")
        traceback.print_exc()
        return None

async def update_user_subscription_status(
    user_id: str, status: str, customer_id: str,
    subscription_id: str | None = None,
    end_date_unix: int | None = None,
    price_id: str | None = None
):
    if db is None:
        print("ERRO Firestore (update_status): Cliente Firestore não inicializado.")
        return
    try:
        user_ref = db.collection('users').document(user_id)
        update_data = {
            'stripeCustomerId': customer_id,
            'subscriptionStatus': status
        }
        update_data['stripeSubscriptionId'] = subscription_id if subscription_id else firestore.DELETE_FIELD
        update_data['subscriptionEndDate'] = datetime.fromtimestamp(end_date_unix, timezone.utc) if end_date_unix else firestore.DELETE_FIELD
        update_data['activePriceId'] = price_id if price_id else firestore.DELETE_FIELD

        final_update_payload = {}
        fields_to_delete_explicitly = ['stripeSubscriptionId', 'subscriptionEndDate', 'activePriceId']
        for k, v in update_data.items():
            if v is not firestore.DELETE_FIELD:
                final_update_payload[k] = v
            elif k in fields_to_delete_explicitly:
                final_update_payload[k] = firestore.DELETE_FIELD

        if not final_update_payload:
            print(f"AVISO Firestore (update_status): Nenhum dado efetivo para atualizar para usuário {user_id}.")
            return

        await asyncio.to_thread(user_ref.set, final_update_payload, merge=True)
        print(f"Firestore: Status atualizado para usuário {user_id}: Status='{status}', EndDate='{final_update_payload.get('subscriptionEndDate')}', SubId='{final_update_payload.get('stripeSubscriptionId')}', PriceId='{final_update_payload.get('activePriceId')}'")

    except Exception as e:
        print(f"ERRO Firestore (update_user_subscription_status) para {user_id}: {e}")
        traceback.print_exc()

async def get_or_create_stripe_customer(email: str, name: str | None, user_id: str) -> str | None:
    if db is None:
        print("ERRO (get_or_create_stripe_customer): Cliente Firestore não inicializado.")
        return None
    stripe.api_key = os.environ.get("STRIPE_SECRET") # Config: stripe.secret
    if not stripe.api_key:
        print("ERRO (get_or_create_stripe_customer): Chave Stripe (STRIPE_SECRET) não disponível no ambiente.")
        return None

    try:
        customers_response = await asyncio.to_thread(stripe.Customer.list, email=email, limit=1)
        customers = customers_response.data
        customer_id: str | None = None

        if customers:
            customer_id = customers[0].id
            print(f"Cliente Stripe encontrado: {customer_id}")
            if customers[0].metadata.get('userId') != user_id:
                 await asyncio.to_thread(stripe.Customer.modify, customer_id, metadata={'userId': user_id})
                 print(f"Metadata do cliente Stripe {customer_id} atualizado com userId {user_id}")
        else:
            print(f"Criando novo cliente Stripe para: {email}")
            customer_creation_params = {'email': email, 'metadata': {'userId': user_id}}
            if name: customer_creation_params['name'] = name
            customer = await asyncio.to_thread(stripe.Customer.create, **customer_creation_params)
            customer_id = customer.id
            print(f"Novo cliente Stripe criado: {customer_id}")

        user_ref = db.collection('users').document(user_id)
        await asyncio.to_thread(user_ref.set, {'stripeCustomerId': customer_id}, merge=True)
        print(f"Firestore: stripeCustomerId {customer_id} salvo/confirmado para usuário {user_id}")
        return customer_id
    except stripe.error.StripeError as e_stripe:
        print(f"ERRO Stripe (get_or_create_stripe_customer): {e_stripe}")
        return None
    except Exception as e:
        print(f"ERRO Geral (get_or_create_stripe_customer): {e}")
        traceback.print_exc()
        return None

# --- Wrapper para executar funções async de forma síncrona ---
def _run_async_handler_wrapper(async_func):
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    if asyncio.iscoroutine(async_func):
        return loop.run_until_complete(async_func)
    else:
        print(f"Erro: _run_async_handler_wrapper recebeu um objeto que não é uma coroutine: {type(async_func)}")
        return None

# --- Callable Function para Stripe Checkout ---
@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def create_stripe_checkout(request: https_fn.CallableRequest) -> dict:
    print("Handler síncrono create_stripe_checkout chamado.")
    result = _run_async_handler_wrapper(_create_stripe_checkout_async(request))
    if result is None:
         print("ERRO: _create_stripe_checkout_async retornou None ou não é uma coroutine.")
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Falha ao executar a lógica assíncrona do checkout.")
    return result

async def _create_stripe_checkout_async(data_request: https_fn.CallableRequest) -> dict:
    try:
        if db is None: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Servidor não inicializado (Firestore).')
        stripe.api_key = os.environ.get("STRIPE_SECRET") # Config: stripe.secret
        if not stripe.api_key: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Chave Stripe (STRIPE_SECRET) não configurada no ambiente.')
        if not data_request.auth or not data_request.auth.uid: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

        user_id = data_request.auth.uid
        price_id = data_request.data.get('priceId')
        is_subscription = data_request.data.get('isSubscription', False)

        print(f"--- _create_stripe_checkout_async INVOCADA para UID: {user_id} ---")
        print(f"Dados Recebidos: priceId='{price_id}', isSubscription={is_subscription}")

        if not price_id or not isinstance(price_id, str): raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='priceId inválido ou ausente.')
        if not isinstance(is_subscription, bool): raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='isSubscription inválido.')

        user_record = await asyncio.to_thread(auth.get_user, user_id)
        email = user_record.email; name = user_record.display_name
        if not email: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message='Email do usuário não encontrado.')

        customer_id = await get_or_create_stripe_customer(email, name, user_id)
        if not customer_id: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao obter/criar cliente Stripe.')

        response_data: dict[str, str | None] = {"customerId": customer_id}
        client_secret: str | None = None

        if is_subscription:
            print(f"Processando Assinatura para priceId: {price_id}")
            subscription_params = {
                'customer': customer_id, 'items': [{'price': price_id}],
                'payment_behavior': 'default_incomplete',
                'payment_settings': {'save_default_payment_method': 'on_subscription'},
                'expand': ['latest_invoice.payment_intent', 'pending_setup_intent'],
                'metadata': {'priceId': price_id, 'userId': user_id}
            }
            subscription = await asyncio.to_thread(stripe.Subscription.create, **subscription_params)
            print(f"Assinatura Stripe criada: ID={subscription.id}, Status={subscription.status}")
            response_data['subscriptionId'] = subscription.id
            response_data['status'] = subscription.status

            if subscription.status == 'incomplete':
                if subscription.pending_setup_intent and hasattr(subscription.pending_setup_intent, 'client_secret') and subscription.pending_setup_intent.client_secret:
                    client_secret = subscription.pending_setup_intent.client_secret
                elif subscription.latest_invoice and hasattr(subscription.latest_invoice, 'payment_intent') and \
                     subscription.latest_invoice.payment_intent and hasattr(subscription.latest_invoice.payment_intent, 'client_secret') and \
                     subscription.latest_invoice.payment_intent.client_secret:
                    client_secret = subscription.latest_invoice.payment_intent.client_secret
                else:
                    print(f"ERRO CRÍTICO: Assinatura {subscription.id} 'incomplete' mas sem client_secret direto.")
                    if subscription.latest_invoice and isinstance(subscription.latest_invoice, str): # Se for apenas o ID da fatura
                        try:
                            invoice = await asyncio.to_thread(stripe.Invoice.retrieve, subscription.latest_invoice, expand=['payment_intent'])
                            if invoice.payment_intent and hasattr(invoice.payment_intent, 'client_secret') and invoice.payment_intent.client_secret:
                                client_secret = invoice.payment_intent.client_secret
                        except Exception as e_inv_fb: print(f"AVISO: Falha ao buscar PI da fatura {subscription.latest_invoice} (fallback): {e_inv_fb}")
                    if not client_secret: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Falha ao obter detalhes para iniciar assinatura.')
            elif subscription.status == 'active' or subscription.status == 'trialing': client_secret = None
            response_data['clientSecret'] = client_secret
        else: # Pagamento Único
            print(f"Processando Pagamento Único para priceId: {price_id}")
            try:
                price_object = await asyncio.to_thread(stripe.Price.retrieve, price_id)
                amount = price_object.unit_amount; currency = price_object.currency
                if amount is None: raise ValueError(f"Preço {price_id} sem 'unit_amount'.")
            except stripe.error.StripeError as e_price: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message=f'Detalhes do preço {price_id} inválidos.')
            payment_intent_params = {'amount':amount, 'currency':currency, 'customer':customer_id, 'payment_method_types':['card'], 'metadata': {'priceId': price_id, 'userId': user_id}}
            payment_intent = await asyncio.to_thread(stripe.PaymentIntent.create, **payment_intent_params)
            response_data['clientSecret'] = payment_intent.client_secret
        print(f"Retornando dados para o cliente: {response_data}")
        return response_data
    except stripe.error.StripeError as e_stripe:
        print(f"ERRO Stripe Capturado (_async): {e_stripe}"); traceback.print_exc()
        user_message = getattr(e_stripe, "user_message", None) or str(e_stripe)
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro Stripe: {user_message}')
    except Exception as e_general:
        print(f"ERRO Geral Capturado (_async): {e_general}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro interno inesperado: {str(e_general)}')

# --- Webhook Handler do Stripe ---
@https_fn.on_request() # Removido argumento 'secrets'
def stripe_webhook_handler(req: https_fn.Request) -> https_fn.Response:
    if db is None: print("ERRO Webhook: Cliente Firestore não inicializado."); return https_fn.Response("Erro interno.", status=500)
    stripe.api_key = os.environ.get("STRIPE_SECRET") # Config: stripe.secret
    webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET") # Config: stripe.webhook_secret
    if not stripe.api_key or not webhook_secret: print("ERRO Webhook: Configuração Stripe (STRIPE_SECRET ou STRIPE_WEBHOOK_SECRET) incompleta."); return https_fn.Response("Erro config.", status=500)

    signature = req.headers.get("stripe-signature"); payload_bytes = req.data
    if not signature: print("ERRO Webhook: Assinatura ausente."); return https_fn.Response("Assinatura ausente.", status=400)

    try: event = stripe.Webhook.construct_event(payload_bytes, signature, webhook_secret)
    except Exception as e: print(f"ERRO Webhook: Falha na verificação do evento - {e}"); return https_fn.Response("Verificação falhou.", status=400)

    print(f"Webhook VERIFICADO: ID={event.id}, Tipo={event.type}")
    event_data = event.data.object; customer_id_str = str(event_data.get('customer', ''))
    user_id: str | None = None
    if customer_id_str: user_id = _run_async_handler_wrapper(find_user_id_by_stripe_customer_id(customer_id_str))
    else: print(f"Aviso Webhook: Evento {event.type} ({event_data.get('id')}) sem customerId.")

    if not user_id and event.type not in ['checkout.session.completed']:
        print(f"AVISO Webhook: Usuário não encontrado para evento {event.type} (Customer: {customer_id_str}). Ignorando.");
        return https_fn.Response(status=200, json_body={'status': 'user_not_found_or_not_needed_for_event_type'})

    try:
        if event.type == 'payment_intent.succeeded':
            print(f"Processando payment_intent.succeeded: PI ID={event_data.get('id')}")
            metadata = event_data.get('metadata', {}); price_id = metadata.get('priceId')
            is_setup_intent_pi = event_data.get('setup_future_usage') is not None or event_data.get('invoice') is not None or event_data.get('subscription') is not None
            if user_id and customer_id_str and price_id and not is_setup_intent_pi:
                end_date_unix: int | None = None; now_utc = datetime.now(timezone.utc)
                if price_id == STRIPE_PRICE_ID_MONTHLY: end_date_unix = int((now_utc + timedelta(days=31)).timestamp())
                elif price_id == STRIPE_PRICE_ID_QUARTERLY: end_date_unix = int((now_utc + timedelta(days=92)).timestamp())
                else: print(f"AVISO: PI {event_data.get('id')} sucedido com priceId ({price_id}) não mapeado para pag. único.")
                if end_date_unix: _run_async_handler_wrapper(update_user_subscription_status(user_id=user_id, status='active', customer_id=customer_id_str, end_date_unix=end_date_unix, price_id=price_id, subscription_id=None))
            elif is_setup_intent_pi: print(f"INFO: PI {event_data.get('id')} sucedido (provavelmente de assinatura).")
            else: print(f"AVISO Webhook: Dados incompletos para payment_intent.succeeded {event_data.get('id')}")
        elif event.type == 'invoice.paid':
            print(f"Processando invoice.paid: Invoice ID={event_data.get('id')}")
            subscription_id_str = str(event_data.get('subscription', ''))
            if user_id and customer_id_str and subscription_id_str:
                try:
                    subscription = stripe.Subscription.retrieve(subscription_id_str)
                    price_id = subscription.items.data[0].price.id if subscription.items and subscription.items.data else None
                    _run_async_handler_wrapper(update_user_subscription_status(user_id=user_id, status=subscription.status, customer_id=customer_id_str, subscription_id=subscription.id, end_date_unix=subscription.current_period_end, price_id=price_id))
                except stripe.error.StripeError as e: print(f"ERRO ao buscar assinatura {subscription_id_str} (invoice.paid): {e}")
            else: print(f"AVISO Webhook: Dados incompletos para invoice.paid {event_data.get('id')}.")
        elif event.type in ['customer.subscription.created', 'customer.subscription.updated']:
            print(f"Processando {event.type}: Sub ID={event_data.get('id')}")
            subscription_id_str = str(event_data.get('id', '')); status_str = str(event_data.get('status', '')); period_end_unix = event_data.get('current_period_end')
            price_id: str | None = None; items_data = event_data.get('items', {}).get('data', [])
            if items_data and isinstance(items_data, list) and len(items_data) > 0:
                price_data = items_data[0].get('price');
                if price_data and isinstance(price_data, dict): price_id = price_data.get('id')
            if user_id and customer_id_str and subscription_id_str and status_str:
                _run_async_handler_wrapper(update_user_subscription_status(user_id=user_id, status=status_str, customer_id=customer_id_str, subscription_id=subscription_id_str, end_date_unix=int(period_end_unix) if period_end_unix is not None else None, price_id=price_id))
            else: print(f"AVISO Webhook: Dados incompletos para {event.type} {event_data.get('id')}.")
        elif event.type == 'customer.subscription.deleted':
            print(f"Processando customer.subscription.deleted: Sub ID={event_data.get('id')}")
            subscription_id_str = str(event_data.get('id', ''))
            if user_id and customer_id_str and subscription_id_str:
                _run_async_handler_wrapper(update_user_subscription_status(user_id=user_id, status='canceled', customer_id=customer_id_str, subscription_id=subscription_id_str, end_date_unix=None, price_id=None))
            else: print(f"AVISO Webhook: Dados incompletos para customer.subscription.deleted {event_data.get('id')}.")
        else: print(f'Webhook não tratado explicitamente: {event.type}')
        return https_fn.Response(status=200, json_body={'status': 'received_verified', 'event_type': event.type})
    except Exception as e:
        event_type_str = event.type if 'event' in locals() and hasattr(event, 'type') else 'DESCONHECIDO'
        print(f"ERRO Webhook: Erro GERAL ao processar evento {event_type_str} - {e}"); traceback.print_exc()
        return https_fn.Response(status=200, json_body={'status': 'error_processing_event', 'event_type': event_type_str})

# --- NOVA CLOUD FUNCTION PARA BUSCA SEMÂNTICA BÍBLICA ---
@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"], # Nomes das secrets no Secret Manager
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def semantic_bible_search(request: https_fn.CallableRequest) -> dict:
    print("Handler síncrono semantic_bible_search chamado (VERSÃO COMPLETA).")
    user_query = request.data.get("query")
    filters = request.data.get("filters")
    top_k = request.data.get("topK", 10) # Padrão para 10 se não fornecido

    print(f"Query recebida: '{user_query}', Filtros: {filters}, TopK: {top_k}")

    if bible_search_service is None:
        print("ERRO FATAL: Módulo bible_search_service não foi importado corretamente.")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de busca indisponível).")

    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' (string) é obrigatório.")
    if filters is not None and not isinstance(filters, dict):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'filters' deve ser um objeto (dicionário) se fornecido.")
    if not isinstance(top_k, int) or top_k <= 0:
        print(f"AVISO: topK inválido ({top_k}), usando padrão 10."); top_k = 10

    try:
        print("Tentando chamar bible_search_service.perform_semantic_search...")
        search_results = _run_async_handler_wrapper(
            bible_search_service.perform_semantic_search(user_query, filters, top_k)
        )
        print(f"Retorno de perform_semantic_search: {type(search_results)}, {len(search_results) if isinstance(search_results, list) else 'N/A'} itens.")
        return {"results": search_results if isinstance(search_results, list) else []}
    except ValueError as ve:
        print(f"Erro de valor (ValueError) na busca semântica: {ve}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message=str(ve))
    except ConnectionError as ce:
        print(f"Erro de conexão (ConnectionError) na busca semântica: {ce}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAVAILABLE, message=f"Serviço externo indisponível durante a busca: {ce}")
    except Exception as e: # Captura outras exceções de perform_semantic_search ou _run_async_handler_wrapper
        print(f"Erro inesperado em semantic_bible_search (main.py) ao chamar o serviço: {e}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar a busca semântica: {str(e)}")
    

# --- NOVA CLOUD FUNCTION PARA BUSCA SEMÂNTICA DE SERMÕES ---
@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"], # Reutiliza as mesmas secrets
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512, # Pode precisar de mais memória se o processamento for intenso
    timeout_sec=60 # Aumentar o timeout se a busca e o agrupamento demorarem
)
def semantic_sermon_search(request: https_fn.CallableRequest) -> dict:
    print("Handler síncrono semantic_sermon_search chamado.")
    user_query = request.data.get("query")
    # Você pode adicionar filtros específicos para sermões se necessário no futuro
    # filters = request.data.get("filters") 
    top_k_sermons = request.data.get("topKSermons", 5)
    top_k_paragraphs_per_query = request.data.get("topKParagraphs", 30) # Quantos parágrafos buscar inicialmente

    print(f"Query de sermão recebida: '{user_query}', TopKSermons: {top_k_sermons}, TopKParagraphs: {top_k_paragraphs_per_query}")

    if sermons_service is None:
        print("ERRO FATAL: Módulo sermons_service não foi importado corretamente.")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de busca de sermões indisponível).")

    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' (string) é obrigatório.")
    
    # Validação dos top_k
    if not isinstance(top_k_sermons, int) or top_k_sermons <= 0: top_k_sermons = 5
    if not isinstance(top_k_paragraphs_per_query, int) or top_k_paragraphs_per_query <= 0: top_k_paragraphs_per_query = 30


    try:
        print("Tentando chamar sermons_service.perform_sermon_semantic_search...")
        search_results = _run_async_handler_wrapper(
            sermons_service.perform_sermon_semantic_search(
                user_query, 
                top_k_paragraphs=top_k_paragraphs_per_query, 
                top_k_sermons=top_k_sermons
            )
        )
        print(f"Retorno de perform_sermon_semantic_search: {len(search_results) if isinstance(search_results, list) else 'N/A'} sermões agrupados.")
        return {"sermons": search_results if isinstance(search_results, list) else []}
    except ValueError as ve:
        print(f"Erro de valor (ValueError) na busca de sermões: {ve}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message=str(ve))
    except ConnectionError as ce:
        print(f"Erro de conexão (ConnectionError) na busca de sermões: {ce}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAVAILABLE, message=f"Serviço externo indisponível durante a busca de sermões: {ce}")
    except Exception as e:
        print(f"Erro inesperado em semantic_sermon_search (main.py): {e}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar a busca de sermões: {str(e)}")