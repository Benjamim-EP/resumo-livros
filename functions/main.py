# functions/main.py
import os
import stripe # Biblioteca oficial do Stripe
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, auth, credentials
from firebase_functions import https_fn, options
from datetime import datetime, timedelta, timezone
import asyncio
import traceback # Import para loggar traceback completo

# --- Configuração ---
# As chaves serão lidas de os.environ DENTRO das funções

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
         if "The default Firebase app already exists" in str(e_val): print("Firebase Admin SDK já inicializado (detectado por ValueError).")
         else: print(f"Erro de valor durante a inicialização do Firebase Admin: {e_val}"); raise
    except Exception as e_init: print(f"Erro inesperado durante a inicialização do Firebase Admin: {e_init}"); raise
else: print("Firebase Admin SDK já inicializado (detectado por _apps).")

# --- FIM DA INICIALIZAÇÃO ---

# Obtém o cliente Firestore
db = None
try:
    db = firestore.client()
except Exception as e:
     print(f"ERRO ao obter cliente Firestore: {e}. Verifique a inicialização do Firebase Admin.")
     db = None

# Define a região global
options.set_global_options(region=options.SupportedRegion.SOUTHAMERICA_EAST1) # Ex: São Paulo

# --- Constantes de Preços (Exemplo - Ajuste com seus IDs reais de teste) ---
STRIPE_PRICE_ID_MONTHLY = "price_1QuborEKXwg5KYoEMaset6VY"
STRIPE_PRICE_ID_RECURRING = "price_1QuboKEKXwg5KYoEtlbkQLR1"
STRIPE_PRICE_ID_QUARTERLY = "price_1QubpLEKXwg5KYoE5Z2kR3sN"

# --- Funções Auxiliares (Firestore - Async) ---

async def find_user_id_by_stripe_customer_id(stripe_customer_id: str) -> str | None:
    """Busca o UID do usuário no Firestore usando o stripeCustomerId."""
    if db is None: print("ERRO Firestore (find_user_id): Cliente Firestore não inicializado."); return None
    try:
        users_ref = db.collection('users')
        query = users_ref.where('stripeCustomerId', '==', stripe_customer_id).limit(1).stream()
        async for doc in query: print(f"Usuário encontrado no Firestore: {doc.id} para Customer {stripe_customer_id}"); return doc.id
        print(f"AVISO Firestore: Usuário não encontrado para Stripe Customer {stripe_customer_id}"); return None
    except Exception as e: print(f"ERRO Firestore (find_user_id_by_stripe_customer_id): {e}"); return None

async def update_user_subscription_status(user_id: str, status: str, customer_id: str, subscription_id: str | None = None, end_date_unix: int | None = None, price_id: str | None = None):
    """Atualiza o status da assinatura do usuário no Firestore."""
    if db is None: print("ERRO Firestore (update_status): Cliente Firestore não inicializado."); return
    try:
        user_ref = db.collection('users').document(user_id) # Referência ao DOCUMENTO
        update_data = {'stripeCustomerId': customer_id, 'subscriptionStatus': status}
        update_data['stripeSubscriptionId'] = subscription_id if subscription_id else firestore.DELETE_FIELD
        update_data['subscriptionEndDate'] = datetime.fromtimestamp(end_date_unix, timezone.utc) if end_date_unix else firestore.DELETE_FIELD
        update_data['activePriceId'] = price_id if price_id else firestore.DELETE_FIELD
        final_update_payload = {k: v for k, v in update_data.items() if v != firestore.DELETE_FIELD}
        fields_to_delete = [k for k, v in update_data.items() if v == firestore.DELETE_FIELD]
        for field in fields_to_delete: final_update_payload[field] = firestore.DELETE_FIELD
        if not final_update_payload: print(f"AVISO Firestore (update_status): Nenhum dado para usuário {user_id}."); return
        user_ref.set(final_update_payload, merge=True) # REMOVIDO AWAIT
        print(f"Firestore: Status atualizado para usuário {user_id}: Status='{status}' End='{final_update_payload.get('subscriptionEndDate')}'")
    except Exception as e: print(f"ERRO Firestore (update_user_subscription_status) para {user_id}: {e}")

# --- Helper Cliente Stripe (Async, usa asyncio.to_thread) ---
async def get_or_create_stripe_customer(email: str, name: str | None, user_id: str) -> str | None:
    """Obtém ou cria um cliente no Stripe e salva o ID no Firestore."""
    if db is None: print("ERRO (get_or_create_stripe_customer): Cliente Firestore não inicializado."); return None
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key: print("ERRO (get_or_create_stripe_customer): Chave Stripe não disponível."); return None

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
            customer = await asyncio.to_thread(stripe.Customer.create, email=email, name=name, metadata={'userId': user_id})
            customer_id = customer.id
            print(f"Novo cliente Stripe criado: {customer_id}")

        user_ref = db.collection('users').document(user_id) # <- Usa document()
        print(f"DEBUG: user_ref obtida: {user_ref}")
        try: print(f"DEBUG: user_ref path: {user_ref.path}")
        except AttributeError: print("ERRO DEBUG: user_ref NÃO tem 'path'.")
        except Exception as e_debug: print(f"ERRO DEBUG: Erro ao acessar path: {e_debug}")

        user_ref.set({'stripeCustomerId': customer_id}, merge=True) # REMOVIDO AWAIT
        print(f"Firestore: stripeCustomerId {customer_id} salvo/confirmado para usuário {user_id}")

        return customer_id

    except stripe.error.StripeError as e: print(f"ERRO Stripe (get_or_create_stripe_customer): {e}"); return None
    except Exception as e: print(f"ERRO Geral (get_or_create_stripe_customer): {e}"); traceback.print_exc(); return None # Adicionado traceback aqui também


# --- Callable Function Wrapper (Síncrono) ---
@https_fn.on_call(secrets=["STRIPE_SECRET_KEY"])
def create_stripe_checkout(request: https_fn.CallableRequest) -> dict:
    """Handler síncrono que chama a lógica async."""
    print("Handler síncrono create_stripe_checkout chamado.")
    result = _run_async_handler(_create_stripe_checkout_async(request)) # Chama a função async
    if result is None:
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Falha ao executar a lógica assíncrona.")
    return result

# --- Função Lógica Principal (Privada e Async) ---
async def _create_stripe_checkout_async(data: https_fn.CallableRequest) -> dict:
    """Contém a lógica async para criar Payment Intent ou Subscription."""
    try:
        # --- Verificações Iniciais ---
        if db is None: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Servidor não inicializado (Firestore).')
        stripe.api_key = os.environ.get("STRIPE_SECRET_KEY") # Acessa chave aqui
        if not stripe.api_key: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Chave Stripe não configurada.')
        if not data.auth or not data.auth.uid: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

        user_id = data.auth.uid
        price_id = data.data.get('priceId')
        is_subscription = data.data.get('isSubscription', False)

        print(f"--- _create_stripe_checkout_async INVOCADA ---")
        print(f"Usuário Autenticado (UID): {user_id}")
        print(f"Dados Recebidos (data.data): {repr(data.data)}")

        if price_id is not None and not isinstance(price_id, str): print(f"ERRO: priceId tipo inválido: {type(price_id)}"); raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='priceId inválido.')
        if not isinstance(is_subscription, bool): print(f"ERRO: isSubscription tipo inválido: {type(is_subscription)}"); raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='isSubscription inválido.')
        if not price_id: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='priceId é obrigatório.')

        # --- Lógica Principal ---
        print(f"Iniciando busca/criação de usuário e cliente para UID: {user_id}")
        try: user_record = await auth.get_user(user_id) # Tenta await direto
        except TypeError: print(f"AVISO: await auth.get_user falhou, tentando com asyncio.to_thread..."); user_record = await asyncio.to_thread(auth.get_user, user_id) # Fallback
        except Exception as e_auth: print(f"ERRO Crítico: Falha ao buscar usuário Auth: {e_auth}"); traceback.print_exc(); raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao verificar informações do usuário.')

        email = user_record.email; name = user_record.display_name
        if not email: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message='Email do usuário não encontrado.')
        print(f"Email do usuário: {email}")

        customer_id = await get_or_create_stripe_customer(email, name, user_id) # <- await
        if not customer_id: raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao obter/criar cliente Stripe.')
        print(f"Stripe Customer ID: {customer_id}")

        response_data: dict[str, str | None] = {"customerId": customer_id}
        client_secret: str | None = None

        response_data: dict[str, str | None] = {"customerId": customer_id}
        client_secret: str | None = None

        if is_subscription:
            print(f"Processando Assinatura para priceId: {price_id}")
            subscription = await asyncio.to_thread(
                stripe.Subscription.create,
                customer=customer_id, items=[{'price': price_id}],
                payment_behavior='default_incomplete',
                payment_settings={'save_default_payment_method': 'on_subscription'},
                metadata={'priceId': price_id}
            )
            print(f"Assinatura criada: {subscription.id}, Status: {subscription.status}")

            response_data['subscriptionId'] = subscription.id
            response_data['status'] = subscription.status

            # --- LÓGICA FINAL: Obter client_secret do PI da Fatura ---
            if subscription.status == 'incomplete' and subscription.latest_invoice:
                 latest_invoice_id = subscription.latest_invoice if isinstance(subscription.latest_invoice, str) else getattr(subscription.latest_invoice, 'id', None)

                 if latest_invoice_id:
                      print(f"Assinatura incomplete. Buscando fatura {latest_invoice_id}...")
                      try:
                           invoice = await asyncio.to_thread(stripe.Invoice.retrieve, latest_invoice_id)
                           # --- VERIFICA SE 'payment_intent' EXISTE ANTES DE ACESSAR ---
                           payment_intent_id_or_obj = getattr(invoice, 'payment_intent', None)
                           # -----------------------------------------------------------

                           if payment_intent_id_or_obj:
                                payment_intent_id = payment_intent_id_or_obj if isinstance(payment_intent_id_or_obj, str) else None
                                # Se for um objeto já (improvável sem expand), tenta pegar o ID
                                if not payment_intent_id and isinstance(payment_intent_id_or_obj, dict):
                                     payment_intent_id = payment_intent_id_or_obj.get('id')
                                elif not payment_intent_id and hasattr(payment_intent_id_or_obj,'id'):
                                     payment_intent_id = payment_intent_id_or_obj.id

                                if payment_intent_id and isinstance(payment_intent_id, str):
                                     print(f"Payment Intent ID encontrado: {payment_intent_id}. Buscando PI...")
                                     payment_intent = await asyncio.to_thread(stripe.PaymentIntent.retrieve, payment_intent_id)
                                     if payment_intent and hasattr(payment_intent, 'client_secret') and payment_intent.client_secret:
                                          client_secret = payment_intent.client_secret
                                          print(f"Client Secret obtido do PI recuperado: {client_secret[:10]}...")
                                     else: print(f"AVISO: PI {payment_intent_id} recuperado sem client_secret válido.")
                                else: print(f"AVISO: Payment Intent ID não é string ou não encontrado no objeto Invoice.")
                           else:
                                print(f"AVISO: Atributo 'payment_intent' não encontrado na fatura {latest_invoice_id}")

                      except stripe.error.StripeError as e_invoice: print(f"AVISO: Erro ao buscar fatura/PI para sub {subscription.id}: {e_invoice}")
                      except Exception as e_inv_generic: print(f"ERRO Geral ao buscar fatura/PI para sub {subscription.id}: {e_inv_generic}"); traceback.print_exc()

            elif subscription.status == 'active':
                 print("Assinatura já está ativa.")
                 client_secret = None

            # Se ainda não temos client_secret e status é incomplete, lançamos erro (após tentativas)
            if client_secret is None and subscription.status == 'incomplete':
                 print(f"ERRO CRÍTICO: Não foi possível obter o client_secret para a assinatura incompleta {subscription.id} via fatura.")
                 raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Falha ao obter detalhes de pagamento para iniciar assinatura.')

            response_data['clientSecret'] = client_secret

        else: # Pagamento Único
            # ... (Lógica do Payment Intent como antes) ...
            print(f"Processando Pagamento Único para priceId: {price_id}")
            try:
                price_object = await asyncio.to_thread(stripe.Price.retrieve, price_id)
                amount = price_object.unit_amount; currency = price_object.currency
                if not amount: raise ValueError("Preço sem valor unitário.")
                print(f"Detalhes preço: Amount={amount}, Currency={currency}")
            except stripe.error.StripeError as e_price: print(f"ERRO ao buscar preço {price_id}: {e_price}"); raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message='Erro ao obter detalhes do preço.')

            print(f"Criando PaymentIntent para customer {customer_id}, amount {amount}")
            payment_intent = await asyncio.to_thread(stripe.PaymentIntent.create, amount=amount, currency=currency, customer=customer_id, payment_method_types=['card'], metadata={'priceId': price_id})
            print(f"PaymentIntent criado: {payment_intent.id}")
            response_data['clientSecret'] = payment_intent.client_secret

        print(f"Retornando dados para o cliente: {response_data}")
        return response_data

    except stripe.error.StripeError as e_stripe: print(f"ERRO Stripe Capturado (_async): {e_stripe}"); raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro Stripe: {getattr(e_stripe, "user_message", str(e_stripe))}')
    except Exception as e_general: print(f"ERRO Geral Capturado (_async): {e_general}"); traceback.print_exc(); raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro interno inesperado: {str(e_general)}')
    
# --- HTTP Function (Webhook Handler - Síncrona, usa _run_async_handler) ---
def _run_async_handler(async_func):
    try: loop = asyncio.get_running_loop()
    except RuntimeError: loop = asyncio.new_event_loop(); asyncio.set_event_loop(loop)
    if asyncio.iscoroutine(async_func): return loop.run_until_complete(async_func)
    else: print(f"Erro: _run_async_handler recebeu não coroutine: {type(async_func)}"); return None

@https_fn.on_request(secrets=["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"])
def stripe_webhook_handler(req: https_fn.Request) -> https_fn.Response:
    if db is None: print("ERRO Webhook: Cliente Firestore não inicializado."); return https_fn.Response("Erro interno.", status=500)
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY"); webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
    if not stripe.api_key: print("ERRO Webhook: Chave API Stripe não carregada."); return https_fn.Response("Erro config.", status=500)
    if not webhook_secret: print("ERRO Webhook: Segredo Webhook não carregado."); return https_fn.Response("Erro config.", status=500)

    signature = req.headers.get("stripe-signature"); payload = req.data
    if not signature: print("ERRO Webhook: Assinatura ausente."); return https_fn.Response("Assinatura ausente.", status=400)

    try: event = stripe.Webhook.construct_event(payload, signature, webhook_secret); print(f"Webhook recebido e VERIFICADO: ID={event.id}, Tipo={event.type}")
    except ValueError as e: print(f"ERRO Webhook: Payload inválido - {e}"); return https_fn.Response("Payload inválido.", status=400)
    except stripe.error.SignatureVerificationError as e: print(f"ERRO Webhook: Falha na assinatura - {e}"); return https_fn.Response("Assinatura inválida.", status=400)
    except Exception as e: print(f"ERRO Webhook: Erro construção evento - {e}"); return https_fn.Response("Erro interno.", status=500)

    event_data = event.data.object; customer_id = event_data.get('customer'); user_id = None
    if customer_id: user_id = _run_async_handler(find_user_id_by_stripe_customer_id(str(customer_id)))
    else: print(f"Aviso Webhook: Evento {event.type} ({event_data.get('id')}) sem customerId.")

    if not user_id and event.type not in ['checkout.session.completed']: print(f"AVISO Webhook: Usuário não encontrado para evento {event.type}. Ignorando."); return https_fn.Response(status=200, body='{"user_not_found_or_not_needed": true}')

    try:
        if event.type == 'payment_intent.succeeded':
            print(f"Processando payment_intent.succeeded: {event_data.get('id')}")
            price_id = event_data.get('metadata', {}).get('priceId')
            if user_id and customer_id:
                 end_date_unix = None; now_utc = datetime.now(timezone.utc)
                 if price_id == STRIPE_PRICE_ID_MONTHLY: end_date_unix = int((now_utc + timedelta(days=31)).timestamp())
                 elif price_id == STRIPE_PRICE_ID_QUARTERLY: end_date_unix = int((now_utc + timedelta(days=92)).timestamp())
                 elif event_data.get('invoice') is None and event_data.get('subscription') is None: print(f"AVISO: PI sucedido com priceId ({price_id}) não mapeado. Default 31 dias."); end_date_unix = int((now_utc + timedelta(days=31)).timestamp())
                 else: print(f"INFO: PI {event_data.get('id')} sucedido (provavelmente de assinatura). Ignorando."); end_date_unix = None
                 if end_date_unix is not None: _run_async_handler(update_user_subscription_status(user_id=user_id, status='active', customer_id=str(customer_id), end_date_unix=end_date_unix, price_id=price_id, subscription_id=None))

        elif event.type == 'invoice.paid':
             print(f"Processando invoice.paid: {event_data.get('id')}")
             subscription_id = event_data.get('subscription')
             if user_id and customer_id and subscription_id:
                 try:
                     subscription = stripe.Subscription.retrieve(str(subscription_id)) # Síncrono OK aqui
                     price_id = subscription.items.data[0].price.id if subscription.items and subscription.items.data else None
                     _run_async_handler(update_user_subscription_status(user_id=user_id, status=subscription.status, customer_id=str(customer_id), subscription_id=str(subscription_id), end_date_unix=subscription.current_period_end, price_id=price_id))
                 except stripe.error.StripeError as e: print(f"ERRO ao buscar assinatura {subscription_id} após invoice.paid: {e}")
             else: print(f"AVISO Webhook: Dados incompletos para invoice.paid {event_data.get('id')}.")

        elif event.type == 'customer.subscription.updated':
             print(f"Processando customer.subscription.updated: {event_data.get('id')}")
             subscription_id = event_data.get('id'); status = event_data.get('status'); period_end = event_data.get('current_period_end'); price_id = None
             if event_data.get('items') and event_data['items'].get('data'):
                 items_data = event_data['items']['data']; price_data = items_data[0].get('price') if items_data and isinstance(items_data, list) and len(items_data) > 0 else None
                 if price_data and isinstance(price_data, dict): price_id = price_data.get('id')
             if user_id and customer_id and subscription_id and status: _run_async_handler(update_user_subscription_status(user_id=user_id, status=str(status), customer_id=str(customer_id), subscription_id=str(subscription_id), end_date_unix=int(period_end) if period_end else None, price_id=price_id))
             else: print(f"AVISO Webhook: Dados incompletos para customer.subscription.updated {event_data.get('id')}.")

        elif event.type == 'customer.subscription.deleted':
            print(f"Processando customer.subscription.deleted: {event_data.get('id')}")
            subscription_id = event_data.get('id'); status = event_data.get('status') # 'canceled'
            if user_id and customer_id and subscription_id and status: _run_async_handler(update_user_subscription_status(user_id=user_id, status=str(status), customer_id=str(customer_id), subscription_id=str(subscription_id), end_date_unix=None, price_id=None))
            else: print(f"AVISO Webhook: Dados incompletos para customer.subscription.deleted {event_data.get('id')}.")

        else: print(f'Webhook não tratado: {event.type}')
        return https_fn.Response(status=200, body='{"received_verified": true}')

    except Exception as e:
         print(f"ERRO Webhook: Erro GERAL ao processar evento {event.type} - {e}")
         traceback.print_exc()
         return https_fn.Response(status=200, body='{"error_processing": true}')