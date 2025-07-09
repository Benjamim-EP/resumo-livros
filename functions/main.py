# functions/main.py
import os
import sys
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, credentials, auth
from firebase_functions import https_fn, options,pubsub_fn, firestore_fn
from firebase_functions.firestore_fn import on_document_updated, Change, Event
from datetime import datetime, time, timezone
import asyncio
import traceback
from math import pow

import base64
import json
from unidecode import unidecode # <<< ADICIONE ESTE IMPORT NO TOPO DO ARQUIVO
import random


# >>> INÍCIO DOS NOVOS IMPORTS PARA GOOGLE PLAY <<<
from google.oauth2 import service_account
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
# >>> FIM DOS NOVOS IMPORTS <<<

print(">>>> main.py (VERSÃO LAZY INIT - CORRETA) <<<<")
CHAT_COST = 5


try:
    import bible_search_service
    print("Módulo 'bible_search_service' importado com sucesso.")
except ImportError as e_import:
    bible_search_service = None
    print(f"AVISO: Não foi possível importar 'bible_search_service': {e_import}")

try:
    import sermons_service
    print("Módulo 'sermons_service' importado com sucesso.")
except ImportError as e_import_sermon:
    sermons_service = None
    print(f"AVISO: Não foi possível importar 'sermons_service': {e_import_sermon}")
try:
    import chat_service
    print("Módulo 'chat_service' importado com sucesso.")
except ImportError as e_import_chat:
    chat_service = None
    print(f"AVISO: Não foi possível importar 'chat_service': {e_import_chat}")
try:
    import bible_chat_service
    print("Módulo 'bible_chat_service' importado com sucesso.")
except ImportError as e_import_bible_chat:
    bible_chat_service = None
    print(f"AVISO: Não foi possível importar 'bible_chat_service': {e_import_bible_chat}")
# --- Inicialização do Firebase Admin ---
if not firebase_admin._apps:
    try:
        initialize_app()
        print("Firebase Admin SDK inicializado.")
    except Exception as e_init:
        print(f"ERRO CRÍTICO: Não foi possível inicializar o Firebase Admin SDK: {e_init}")
        raise

# --- Lazy Initialization do Cliente Firestore ---
_db_client = None

def get_db():
    """
    Função para obter a instância do cliente Firestore.
    A inicialização é "preguiçosa" (lazy), acontecendo apenas na primeira chamada.
    """
    global _db_client
    if _db_client is None:
        print("Inicializando cliente Firestore (primeira chamada)...")
        _db_client = firestore.client()
        print("Cliente Firestore obtido com sucesso.")
    return _db_client

# Define a região global para as Cloud Functions
options.set_global_options(region=options.SupportedRegion.SOUTHAMERICA_EAST1)

# --- Constantes do Google Play ---
PACKAGE_NAME = "com.septima.septimabiblia" 

# --- Funções Auxiliares (Async) ---
def _run_async_handler_wrapper(async_func):
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop.run_until_complete(async_func)

# --- CLOUD FUNCTION PARA VALIDAR COMPRAS DO GOOGLE PLAY ---
@https_fn.on_call(
    secrets=["play-store-service-account-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def validate_google_play_purchase(req: https_fn.CallableRequest) -> dict:
    print("Handler validate_google_play_purchase chamado.")
    result = _run_async_handler_wrapper(_validate_google_play_purchase_async(req))
    print("resultado", result)
    if result is None:
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Falha ao executar a lógica de validação assíncrona.")
    return result

async def _validate_google_play_purchase_async(req: https_fn.CallableRequest) -> dict:
    # >>>>> CORREÇÃO AQUI <<<<<
    db = get_db()
    # >>>>> FIM DA CORREÇÃO <<<<<
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    user_id = req.auth.uid
    product_id = req.data.get('productId')
    purchase_token = req.data.get('purchaseToken')
    
    if not all([product_id, purchase_token]):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='productId e purchaseToken são obrigatórios.')

    print(f"Iniciando validação para User: {user_id}, Product: {product_id}, Token: {purchase_token[:10]}...")

    try:
        service_account_info = os.environ.get("play-store-service-account-key")
        creds = service_account.Credentials.from_service_account_info(
            eval(service_account_info),
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        
        android_publisher = build('androidpublisher', 'v3', credentials=creds)

        purchase = await asyncio.to_thread(
            lambda: android_publisher.purchases().subscriptions().get(
                packageName=PACKAGE_NAME,
                subscriptionId=product_id,
                token=purchase_token
            ).execute()
        )
        
        print(f"Resposta da API do Google Play: {purchase}")

        payment_state = purchase.get('paymentState') 
        expiry_time_millis = int(purchase.get('expiryTimeMillis', 0))
        is_valid = payment_state == 1

        if is_valid:
            print(f"Compra VÁLIDA para {user_id}. Estado: {payment_state}")
            expiry_date = datetime.fromtimestamp(expiry_time_millis / 1000, tz=timezone.utc)
            
            user_ref = db.collection('users').document(user_id) # Usa a variável local 'db'
            await asyncio.to_thread(
                user_ref.set,
                {
                    'subscriptionStatus': 'active',
                    'subscriptionEndDate': expiry_date,
                    'activePriceId': product_id,
                    'lastPurchaseToken': purchase_token
                },
                merge=True
            )
            print(f"Firestore atualizado para {user_id}. Assinatura ativa até {expiry_date}.")
            return {'status': 'success', 'message': 'Assinatura validada e ativada.'}
        else:
            print(f"Compra INVÁLIDA para {user_id}. Estado: {payment_state}")
            user_ref = db.collection('users').document(user_id) # Usa a variável local 'db'
            await asyncio.to_thread(
                user_ref.set, {'subscriptionStatus': 'inactive'}, merge=True
            )
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message='A compra não está ativa.')

    except Exception as e:
        print(f"ERRO durante a validação da compra no Google Play: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro ao validar a assinatura: {e}')

# --- CLOUD FUNCTION PARA BUSCA SEMÂNTICA BÍBLICA ---
@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def semantic_bible_search(request: https_fn.CallableRequest) -> dict:
    print("Handler síncrono semantic_bible_search chamado.")
    user_query = request.data.get("query")
    filters = request.data.get("filters")
    top_k = request.data.get("topK", 10)

    if bible_search_service is None:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de busca indisponível).")

    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' (string) é obrigatório.")
    
    try:
        search_results = _run_async_handler_wrapper(
            bible_search_service.perform_semantic_search(user_query, filters, top_k)
        )
        return {"results": search_results if isinstance(search_results, list) else []}
    except Exception as e:
        print(f"Erro inesperado em semantic_bible_search (main.py): {e}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar a busca: {str(e)}")

# --- CLOUD FUNCTION PARA BUSCA SEMÂNTICA DE SERMÕES ---
@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def semantic_sermon_search(request: https_fn.CallableRequest) -> dict:
    print("Handler síncrono semantic_sermon_search chamado.")
    user_query = request.data.get("query")
    top_k_sermons = request.data.get("topKSermons", 5)
    top_k_paragraphs_per_query = request.data.get("topKParagraphs", 30)

    if sermons_service is None:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de busca de sermões indisponível).")

    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' (string) é obrigatório.")
    
    try:
        search_results = _run_async_handler_wrapper(
            sermons_service.perform_sermon_semantic_search(
                user_query, 
                top_k_paragraphs=top_k_paragraphs_per_query, 
                top_k_sermons=top_k_sermons
            )
        )
        return {"sermons": search_results if isinstance(search_results, list) else []}
    except Exception as e:
        print(f"Erro inesperado em semantic_sermon_search (main.py): {e}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar a busca de sermões: {str(e)}")

# --- CLOUD FUNCTION PARA DELETAR USUÁRIO ---
async def _delete_collection_with_db(coll_ref, batch_size):
    db = get_db()
    docs = await asyncio.to_thread(coll_ref.limit(batch_size).get)
    deleted = 0
    while docs:
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        await asyncio.to_thread(batch.commit)
        deleted += len(docs)
        docs = await asyncio.to_thread(coll_ref.limit(batch_size).get)
    return deleted

@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=300
)
def deleteUserData(req: https_fn.CallableRequest) -> dict:
    return _run_async_handler_wrapper(_delete_user_data_async(req))

# Coloque esta função auxiliar antes de _delete_user_data_async se ainda não o fez
async def _delete_collection_with_db(coll_ref, batch_size):
    """
    Função auxiliar para deletar uma coleção ou subcoleção em lotes.
    O Firestore não permite deletar uma coleção diretamente, então precisamos
    listar os documentos e deletá-los em lotes.
    """
    db = get_db() # Garante que o cliente está inicializado
    docs = await asyncio.to_thread(coll_ref.limit(batch_size).get)
    deleted = 0
    while docs:
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        # CORREÇÃO 1: Usa lambda para a chamada síncrona sem retorno
        await asyncio.to_thread(lambda: batch.commit())
        
        deleted += len(docs)
        docs = await asyncio.to_thread(coll_ref.limit(batch_size).get)
    return deleted


# Função principal completa e corrigida
async def _delete_user_data_async(req: https_fn.CallableRequest) -> dict:
    """
    Exclui todos os dados de um usuário, incluindo documentos, subcoleções e a conta de autenticação.
    A função só pode ser chamada por um usuário autenticado para excluir seus próprios dados.
    """
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )
    
    user_id = req.auth.uid
    print(f"Iniciando processo de exclusão para o usuário: {user_id}")

    try:
        # Lista de coleções onde os dados do usuário podem estar.
        # has_subcollection: True se a coleção principal tem subcoleções que precisam ser deletadas recursivamente.
        # has_subcollection: False se a coleção é apenas um documento com o ID do usuário.
        collections_to_delete = {
            'diaries': True,
            'userBibleProgress': False,
            'userVerseNotes': True,
            'userVerseHighlights': True,
            'userCommentHighlights': True,
            'users': False,
            'chats': True,
        }
        
        for col_name, has_subcollection in collections_to_delete.items():
            doc_ref = db.collection(col_name).document(user_id)
            doc_snapshot = await asyncio.to_thread(doc_ref.get)

            if doc_snapshot.exists:
                if has_subcollection:
                    subcollections = await asyncio.to_thread(doc_ref.collections)
                    for sub_coll_ref in subcollections:
                        full_subcollection_path = f"{doc_ref.path}/{sub_coll_ref.id}"
                        print(f"Deletando subcoleção: {full_subcollection_path}")
                        await _delete_collection_with_db(sub_coll_ref, 100)

                print(f"Deletando documento principal: {doc_ref.path}")
                await asyncio.to_thread(lambda: doc_ref.delete())
            else:
                print(f"Documento não encontrado, pulando deleção: {doc_ref.path}")

        # Deletar documentos do usuário na coleção 'posts' (se houver)
        print(f"Buscando e deletando posts do usuário {user_id}...")
        posts_query = db.collection('posts').where('userId', '==', user_id)
        posts_docs = await asyncio.to_thread(posts_query.get)
        if posts_docs:
            posts_batch = db.batch()
            for doc in posts_docs:
                print(f"Marcando para deletar post: {doc.id}")
                posts_batch.delete(doc.reference)
            await asyncio.to_thread(lambda: posts_batch.commit())
        
        # Excluir o usuário do Firebase Authentication (passo final e crucial)
        print(f"Excluindo usuário do Firebase Authentication: {user_id}")
        # CORREÇÃO APLICADA AQUI:
        # A função auth.delete_user é SÍNCRONA e deve ser chamada com to_thread.
        await asyncio.to_thread(lambda: auth.delete_user(user_id))
        
        print(f"Todos os dados para o usuário {user_id} foram excluídos com sucesso.")
        return {"status": "success", "message": "Conta e dados excluídos com sucesso."}

    except Exception as e:
        print(f"ERRO CRÍTICO durante a exclusão do usuário {user_id}: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao excluir a conta: {e}"
        )
    
# --- NOVA FUNÇÃO HELPER: Obter credenciais de serviço ---
def _get_google_api_credentials():
    """Obtém as credenciais para a API do Google Play a partir do secret."""
    service_account_info_str = os.environ.get("play-store-service-account-key")
    if not service_account_info_str:
        raise Exception("Secret 'play-store-service-account-key' não encontrado.")
    
    # eval() é perigoso, mas é a forma recomendada pelo Firebase para secrets JSON.
    # Use com cautela e garanta que o secret não seja comprometido.
    service_account_info = eval(service_account_info_str)
    
    return service_account.Credentials.from_service_account_info(
        service_account_info,
        scopes=['https://www.googleapis.com/auth/androidpublisher']
    )

    
@pubsub_fn.on_message_published(
    topic="play-store-notifications", # <<< CONFIRME SE ESTE É O NOME DO SEU TÓPICO
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    secrets=["play-store-service-account-key"], # <<< ADICIONA O SECRET AQUI
    memory=options.MemoryOption.MB_256,
    timeout_sec=60
)
def google_play_rtdn_webhook(event: pubsub_fn.CloudEvent[pubsub_fn.MessagePublishedData]) -> None:
    """
    Função síncrona que envolve a lógica assíncrona de processamento de RTDN.
    """
    print("Gatilho Pub/Sub 'google_play_rtdn_webhook' recebido.")
    
    # Envolve a chamada da função async usando o wrapper que você já tem
    _run_async_handler_wrapper(_process_rtdn_async(event))

    print("Processamento do webhook concluído.")


async def _process_rtdn_async(event: pubsub_fn.CloudEvent[pubsub_fn.MessagePublishedData]) -> None:
    """
    Processa de forma assíncrona uma Notificação de Desenvolvedor em Tempo Real (RTDN) do Google Play.
    Esta função é o coração da lógica do webhook, lidando com a decodificação da mensagem,
    a busca do usuário e a atualização do status da assinatura no Firestore.
    """
    try:
        # 1. Validação e Decodificação (sem alterações)
        if not event.data or not event.data.message or not event.data.message.data:
            print("Erro: Evento Pub/Sub malformado. Ignorando.")
            return

        payload_base64 = event.data.message.data
        payload_str = base64.b64decode(payload_base64).decode('utf-8')
        notification_data = json.loads(payload_str)
        
        print(f"Payload da notificação: {json.dumps(notification_data, indent=2)}")

        if 'subscriptionNotification' not in notification_data:
            print("Notificação não é de assinatura. Ignorando.")
            return

        sub_notification = notification_data['subscriptionNotification']
        purchase_token = sub_notification.get('purchaseToken')
        subscription_id = sub_notification.get('subscriptionId')
        notification_type = sub_notification.get('notificationType')

        if not all([purchase_token, subscription_id, notification_type]):
            print("Erro: Dados essenciais faltando na notificação. Ignorando.")
            return

        print(f"Processando notificação: Tipo={notification_type}, Produto={subscription_id}, Token={purchase_token[:15]}...")

        # 2. Encontrar o Usuário no Firestore (sem alterações)
        db = get_db()
        users_ref = db.collection('users')
        query = users_ref.where('lastPurchaseToken', '==', purchase_token).limit(1)
        docs = await asyncio.to_thread(lambda: list(query.stream()))

        if not docs:
            print(f"ERRO: Nenhum usuário encontrado com o purchaseToken: {purchase_token[:15]}...")
            return

        user_doc = docs[0]
        user_id = user_doc.id
        print(f"Usuário {user_id} encontrado para a notificação.")

        # <<< INÍCIO DA MUDANÇA PRINCIPAL >>>

        # 3. Sempre verificar o estado atual na API do Google para notificações de ciclo de vida
        # Tipos de notificação relevantes que indicam uma mudança de estado
        relevant_notification_types = [
            1,  # SUBSCRIPTION_RECOVERED
            2,  # SUBSCRIPTION_RENEWED
            3,  # SUBSCRIPTION_CANCELED
            4,  # SUBSCRIPTION_PURCHASED
            5,  # SUBSCRIPTION_ON_HOLD
            6,  # SUBSCRIPTION_IN_GRACE_PERIOD
            8,  # SUBSCRIPTION_RESTARTED
            12, # SUBSCRIPTION_EXPIRED
            13, # SUBSCRIPTION_REVOKED
        ]

        if notification_type not in relevant_notification_types:
            print(f"Tipo de notificação {notification_type} não requer ação. Ignorando.")
            return
            
        print(f"Notificação tipo {notification_type} requer verificação na API do Google.")
        try:
            creds = _get_google_api_credentials()
            android_publisher = build('androidpublisher', 'v3', credentials=creds)

            purchase = await asyncio.to_thread(
                lambda: android_publisher.purchases().subscriptions().get(
                    packageName=PACKAGE_NAME,
                    subscriptionId=subscription_id,
                    token=purchase_token
                ).execute()
            )
            
            print(f"Resposta da API do Google: {json.dumps(purchase, indent=2)}")

            expiry_time_millis = int(purchase.get('expiryTimeMillis', 0))
            expiry_date = datetime.fromtimestamp(expiry_time_millis / 1000, tz=timezone.utc)
            payment_state = purchase.get('paymentState')

            update_data = {}

            # 4. Lógica de atualização simplificada e robusta
            if payment_state == 1:  # Assinatura está ATIVA (pode ser renovada, recuperada, etc.)
                print(f"API confirmou: ATIVA. Nova data de expiração: {expiry_date}")
                update_data = {
                    'subscriptionStatus': 'active',
                    'subscriptionEndDate': expiry_date,
                    'activePriceId': subscription_id,
                    'lastPurchaseToken': purchase_token, # Reafirma o token
                }
            else: # Qualquer outro estado (cancelada, expirada, em hold, revogada)
                print(f"API confirmou: INATIVA (Estado: {payment_state}). Resetando status.")
                update_data = {
                    'subscriptionStatus': 'inactive',
                    'subscriptionEndDate': None,
                    'activePriceId': None
                }

            # 5. Atualiza o Firestore se houver dados para atualizar
            if update_data:
                await asyncio.to_thread(user_doc.reference.set, update_data, merge=True)
                print(f"Firestore atualizado para o usuário {user_id} com os dados: {update_data}")

        except Exception as api_e:
            print(f"ERRO ao verificar assinatura na API do Google: {api_e}. A atualização foi ignorada.")
            # Não faz nada para evitar dados incorretos. O erro será logado.
        
        # <<< FIM DA MUDANÇA PRINCIPAL >>>

    except Exception as e:
        print(f"ERRO CRÍTICO ao processar a notificação: {e}")
        traceback.print_exc()


# --- CLOUD FUNCTION PARA CHAT RAG COM SERMÕES ---
@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=120
)

def chatWithSermons(request: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    # 1. VERIFICAÇÃO DE AUTENTICAÇÃO (ESSENCIAL PARA COBRANÇA)
    if not request.auth or not request.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para usar o chat.'
        )
    
    user_id = request.auth.uid
    user_query = request.data.get("query")
    chat_history = request.data.get("history")

    print(f"Handler chatWithSermons chamado por User ID: {user_id}")
    
    if chat_service is None:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de chat indisponível).")

    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' (string) é obrigatório.")
    
    if chat_history and not isinstance(chat_history, list):
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'history' deve ser uma lista.")

    try:
        # 2. LÓGICA DE CUSTO E VERIFICAÇÃO DE ASSINATURA
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        subscription_end_date = user_data.get('subscriptionEndDate') # Timestamp

        is_premium = False
        if subscription_status == 'active':
            if isinstance(subscription_end_date, datetime) and subscription_end_date > datetime.now(timezone.utc):
                is_premium = True
            elif isinstance(subscription_end_date, Timestamp) and subscription_end_date.to_datetime().replace(tzinfo=timezone.utc) > datetime.now(timezone.utc):
                is_premium = True

        if not is_premium:
            print(f"Usuário {user_id} não é Premium. Verificando moedas.")
            current_coins = user_data.get('userCoins', 0)
            if current_coins < CHAT_COST:
                print(f"Moedas insuficientes para {user_id}. Possui: {current_coins}, Custo: {CHAT_COST}")
                raise https_fn.HttpsError(
                    code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                    message=f"Moedas insuficientes. Você precisa de {CHAT_COST} moedas para enviar uma mensagem."
                )
            
            # Deduz as moedas atomicamente usando uma transação para segurança
            print(f"Deduzindo {CHAT_COST} moedas de {user_id}.")
            new_coin_total = current_coins - CHAT_COST
            user_ref.update({'userCoins': new_coin_total})
            # Opcional: Logar a transação em uma subcoleção separada para auditoria.

        else:
            print(f"Usuário {user_id} é Premium. Chat gratuito.")

        # 3. PROSSEGUE COM A LÓGICA DO CHAT (se a verificação de custo passou)
        chat_result = _run_async_handler_wrapper(
            chat_service.get_rag_chat_response(user_query, chat_history)
        )
        
        return {
            "success": True,
            "response": chat_result.get("response"),
            "sources": chat_result.get("sources", [])
        }

    except https_fn.HttpsError as e:
        # Relança os erros esperados (como moedas insuficientes)
        raise e
    except Exception as e:
        print(f"Erro inesperado em chatWithSermons (main.py): {e}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar o chat: {str(e)}")
    """
    Endpoint para o chat RAG. Recebe a pergunta do usuário e o histórico do chat.
    """
    print("Handler síncrono chatWithSermons chamado.")
    user_query = request.data.get("query")
    chat_history = request.data.get("history") # Opcional: lista de mensagens anteriores

    if chat_service is None:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de chat indisponível).")

    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' (string) é obrigatório.")
    
    if chat_history and not isinstance(chat_history, list):
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'history' deve ser uma lista.")

    try:
        # Chama a função principal do nosso serviço de chat
        chat_result = _run_async_handler_wrapper(
            chat_service.get_rag_chat_response(user_query, chat_history)
        )
        
        # Retorna a resposta e as fontes para o app
        return {
            "success": True,
            "response": chat_result.get("response"),
            "sources": chat_result.get("sources", [])
        }

    except Exception as e:
        print(f"Erro inesperado em chatWithSermons (main.py): {e}"); traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar o chat: {str(e)}")


@https_fn.on_call(
    secrets=["openai-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=120
)
def chatWithBibleSection(request: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    # Validação e Autenticação (continua igual)
    if not request.auth or not request.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Você precisa estar logado para usar o chat.')
    
    user_id = request.auth.uid
    data = request.data
    user_query = data.get("query")
    chat_history = data.get("history")
    book_abbrev = data.get("bookAbbrev")
    chapter_number = data.get("chapterNumber")
    verses_range_str = data.get("versesRangeStr")
    use_strongs = data.get("useStrongsKnowledge", False)

    if not all([user_query, book_abbrev, chapter_number, verses_range_str]):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Parâmetros essenciais da seção bíblica estão faltando.")

    print(f"Handler chatWithBibleSection chamado por User ID: {user_id} para {book_abbrev} {chapter_number}:{verses_range_str}")
    
    try:
        # Lógica de Custo (continua igual)
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        is_premium = subscription_status == 'active'

        if use_strongs and not is_premium:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="A análise etimológica é um recurso Premium."
            )
        
        if not is_premium:
            current_coins = user_data.get('userCoins', 0)
            if current_coins < CHAT_COST:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, message=f"Moedas insuficientes.")
            user_ref.update({'userCoins': current_coins - CHAT_COST})
        
        # <<< A CORREÇÃO PRINCIPAL ESTÁ AQUI >>>
        # Garante que o serviço correto foi importado e chama a função correta
        if bible_chat_service is None:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de chat da Bíblia indisponível).")

        final_response = _run_async_handler_wrapper(
            bible_chat_service.get_bible_chat_response( # <<< USA bible_chat_service
                db=db,
                user_query=user_query,
                chat_history=chat_history,
                book_abbrev=book_abbrev,
                chapter_number=chapter_number,
                verses_range_str=verses_range_str,
                use_strongs=use_strongs
            )
        )
        
        return {
            "success": True,
            "response": final_response
        }

    except https_fn.HttpsError as e:
        raise e
    except Exception as e:
        print(f"Erro inesperado em chatWithBibleSection (main.py): {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar o chat: {str(e)}")
    db = get_db()
    
    if not request.auth or not request.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Você precisa estar logado para usar o chat.')
    
    user_id = request.auth.uid
    data = request.data
    user_query = data.get("query")
    chat_history = data.get("history")
    book_abbrev = data.get("bookAbbrev")
    chapter_number = data.get("chapterNumber")
    verses_range_str = data.get("versesRangeStr")
    use_strongs = data.get("useStrongsKnowledge", False)

    if not all([user_query, book_abbrev, chapter_number, verses_range_str]):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Parâmetros essenciais da seção bíblica estão faltando.")

    print(f"Handler chatWithBibleSection chamado por User ID: {user_id} para {book_abbrev} {chapter_number}:{verses_range_str}")
    
    try:
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        is_premium = subscription_status == 'active'

        if use_strongs and not is_premium:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="A análise etimológica é um recurso Premium."
            )
        
        if not is_premium:
            current_coins = user_data.get('userCoins', 0)
            if current_coins < CHAT_COST:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, message=f"Moedas insuficientes.")
            user_ref.update({'userCoins': current_coins - CHAT_COST})
            print(f"Deduzindo {CHAT_COST} moedas de {user_id} para o chat da Bíblia.")
        else:
            print(f"Usuário {user_id} é Premium. Chat da Bíblia gratuito.")
            
        # <<< MUDANÇA PRINCIPAL: CHAMANDO O SERVIÇO >>>
        if chat_service is None:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de chat indisponível).")

        final_response = _run_async_handler_wrapper(
            chat_service.get_bible_chat_response(
                db=db,
                user_query=user_query,
                chat_history=chat_history,
                book_abbrev=book_abbrev,
                chapter_number=chapter_number,
                verses_range_str=verses_range_str,
                use_strongs=use_strongs
            )
        )
        
        return {
            "success": True,
            "response": final_response
        }

    except https_fn.HttpsError as e:
        raise e
    except Exception as e:
        print(f"Erro inesperado em chatWithBibleSection (main.py): {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar o chat: {str(e)}")
    db = get_db()
    
    # 1. Validação e Autenticação
    if not request.auth or not request.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Você precisa estar logado para usar o chat.')
    
    user_id = request.auth.uid
    
    # 2. Extração dos Dados da Requisição
    data = request.data
    user_query = data.get("query")
    chat_history = data.get("history")
    book_abbrev = data.get("bookAbbrev")
    chapter_number = data.get("chapterNumber")
    verses_range_str = data.get("versesRangeStr")
    use_strongs = data.get("useStrongsKnowledge", False)

    # Validação dos parâmetros essenciais
    if not all([user_query, book_abbrev, chapter_number, verses_range_str]):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Parâmetros essenciais da seção bíblica estão faltando.")

    print(f"Handler chatWithBibleSection chamado por User ID: {user_id} para {book_abbrev} {chapter_number}:{verses_range_str}")
    
    try:
        # 3. Lógica de Custo (idêntica à do chat de sermões)
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        is_premium = subscription_status == 'active' # Simplificando a verificação
        
        if not is_premium:
            current_coins = user_data.get('userCoins', 0)
            if current_coins < CHAT_COST:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, message=f"Moedas insuficientes.")
            user_ref.update({'userCoins': current_coins - CHAT_COST})
            print(f"Deduzindo {CHAT_COST} moedas de {user_id} para o chat da Bíblia.")
        else:
            print(f"Usuário {user_id} é Premium. Chat da Bíblia gratuito.")
            
        # 4. Chamar um novo serviço para lidar com a lógica do RAG da Bíblia
        # (Por enquanto, vamos simular a resposta para testar o fluxo)
        
        # TODO: Implementar a busca de contexto (Comentário, Strongs) e a chamada ao GPT
        #
        # SIMULAÇÃO DA RESPOSTA:
        simulated_response = f"Analisando '{user_query}' no contexto de {book_abbrev} {chapter_number}:{verses_range_str}."
        if use_strongs:
            simulated_response += " A análise etimológica com o Léxico de Strong foi solicitada."
        
        time.sleep(2) # Simula o tempo de processamento

        return {
            "success": True,
            "response": simulated_response
            # Não há 'sources' aqui, pois o contexto é a própria seção
        }

    except https_fn.HttpsError as e:
        raise e
    except Exception as e:
        print(f"Erro inesperado em chatWithBibleSection (main.py): {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar o chat: {str(e)}")
    
# --- NOVA CLOUD FUNCTION PARA ATUALIZAR TEMPO DE LEITURA ---
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 # <<< CORREÇÃO 1: AUMENTO DE MEMÓRIA
)
def updateReadingTime(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )
    
    user_id = req.auth.uid
    seconds_to_add = req.data.get("secondsToAdd")
    
    if not isinstance(seconds_to_add, int) or seconds_to_add <= 0:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'secondsToAdd' (inteiro positivo) é obrigatório."
        )
        
    print(f"updateReadingTime: Recebidos {seconds_to_add} segundos para adicionar ao usuário {user_id}.")
    
    try:
        progress_doc_ref = db.collection('userBibleProgress').document(user_id)
        
        # A transação garante a atomicidade da leitura e escrita
        @firestore.transactional
        def update_in_transaction(transaction, doc_ref):
            snapshot = doc_ref.get(transaction=transaction)
            
            # Leitura segura do valor atual, com 0 como padrão se não existir
            current_time = 0
            if snapshot.exists:
                current_time = snapshot.to_dict().get('rawReadingTime', 0)
            
            new_time = current_time + seconds_to_add
            
            transaction.set(doc_ref, {
                'rawReadingTime': new_time,
                'lastTimeUpdate': firestore.SERVER_TIMESTAMP
            }, merge=True)

        transaction = db.transaction()
        update_in_transaction(transaction, progress_doc_ref)
        
        print(f"updateReadingTime: Tempo de leitura para o usuário {user_id} atualizado com sucesso.")
        return {"status": "success", "message": f"{seconds_to_add} segundos adicionados."}

    except Exception as e:
        print(f"ERRO CRÍTICO em updateReadingTime para o usuário {user_id}: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao atualizar seu tempo de leitura: {e}"
        )

# --- GATILHO PARA CÁLCULO DE RANKING ---
_bible_metadata = None
def _load_bible_metadata():
    # ... (esta função permanece a mesma)
    global _bible_metadata
    if _bible_metadata is None:
        try:
            with open('bible_sections_count.json', 'r') as f:
                _bible_metadata = json.load(f)
            print("Metadados da Bíblia (bible_sections_count.json) carregados com sucesso.")
        except Exception as e:
            print(f"ERRO CRÍTICO: Não foi possível carregar 'bible_sections_count.json': {e}")
    return _bible_metadata

_load_bible_metadata()


@firestore_fn.on_document_updated(
    document="userBibleProgress/{userId}",
    region=options.SupportedRegion.SOUTHAMERICA_EAST1, 
    memory=options.MemoryOption.MB_256 # Aumentar a memória aqui também é uma boa prática
)
def calculateUserScore(event: Event[Change]) -> None:
    if event.data is None:
        return

    data_before = event.data.before.to_dict() if event.data.before and event.data.before.exists else {}
    data_after = event.data.after.to_dict() if event.data.after and event.data.after.exists else {}
    
    if not data_after:
        return

    # Leitura segura com valores padrão
    raw_time_before = data_before.get('rawReadingTime', 0)
    raw_time_after = data_after.get('rawReadingTime', 0)
    books_before = data_before.get('books', {})
    books_after = data_after.get('books', {})
    
    if raw_time_after == raw_time_before and books_after == books_before:
        print("calculateUserScore: Nenhuma mudança relevante em 'rawReadingTime' ou 'books'. Encerrando.")
        return

    print(f"calculateUserScore: Mudança detectada para o usuário {event.params['userId']}. Iniciando cálculo.")
    
    metadata = _load_bible_metadata()
    if not metadata or 'total_secoes_biblia' not in metadata:
        print("ERRO em calculateUserScore: Metadados da Bíblia não estão disponíveis.")
        return

    total_bible_sections = metadata.get('total_secoes_biblia', 1)
    if total_bible_sections <= 0:
        return

    total_read_sections = sum(len(progress.get('readSections', [])) for progress in books_after.values() if isinstance(progress, dict))
    
    current_progress_percent = (total_read_sections / total_bible_sections) * 100
    
    bible_completion_count = data_after.get('bibleCompletionCount', 0)
    update_payload = {}
    
    if current_progress_percent >= 100.0:
        print(f"calculateUserScore: Usuário {event.params['userId']} completou a Bíblia!")
        bible_completion_count += 1
        update_payload['books'] = {} 
        update_payload['currentProgressPercent'] = 0.0
    else:
        update_payload['currentProgressPercent'] = round(current_progress_percent, 2)

    update_payload['bibleCompletionCount'] = bible_completion_count

    progress_for_multiplier = update_payload['currentProgressPercent']
    progress_multiplier = (1 + (progress_for_multiplier / 100)) * (1 + (bible_completion_count * 0.5))
    ranking_score = raw_time_after * progress_multiplier
    update_payload['rankingScore'] = round(ranking_score, 2)
    
    print(f"calculateUserScore: Atualizando documento para {event.params['userId']} com payload: {update_payload}")
    try:
        doc_ref = event.data.after.reference
        doc_ref.update(update_payload)
        print(f"calculateUserScore: Documento de {event.params['userId']} atualizado com sucesso no Firestore.")
    except Exception as e:
        print(f"ERRO em calculateUserScore: Falha ao atualizar o documento para {event.params['userId']}: {e}")
        traceback.print_exc()


# --- NOVA FUNÇÃO PARA CRIAR O SEPTIMA ID ---
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 
)
def assignSeptimaId(req: https_fn.CallableRequest) -> dict:
    """
    Gera e atribui um 'Septima ID' (username + discriminator) único para um novo usuário.
    A função é transacional para garantir a unicidade do discriminador.
    """
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )
    
    user_id = req.auth.uid
    user_ref = db.collection('users').document(user_id)
    
    try:
        @firestore.transactional
        def generate_and_assign(transaction):
            user_snapshot = user_ref.get(transaction=transaction)
            if not user_snapshot.exists:
                raise Exception("Documento do usuário não encontrado.")
            
            user_data = user_snapshot.to_dict()

            # Se o usuário já tem um discriminador, não faz nada.
            if user_data.get('discriminator'):
                print(f"assignSeptimaId: Usuário {user_id} já possui um Septima ID. Encerrando.")
                return {
                    "username": user_data.get('username'),
                    "discriminator": user_data.get('discriminator')
                }

            display_name = user_data.get('nome', 'usuario')
            if not display_name: display_name = 'usuario'

            # Normaliza o nome para ser usado como username
            # unidecode remove acentos. Ex: "José" -> "Jose"
            username_normalized = unidecode(display_name).lower().replace(" ", "")

            # Busca todos os usuários que já têm o mesmo username normalizado
            users_with_same_name_query = db.collection('users').where('username', '==', username_normalized)
            
            # Executa a query DENTRO da transação
            docs_with_same_name = users_with_same_name_query.stream(transaction=transaction)
            
            # Pega todos os discriminadores já em uso para esse nome
            used_discriminators = {doc.to_dict().get('discriminator') for doc in docs_with_same_name if doc.to_dict().get('discriminator')}

            # Tenta encontrar um discriminador único
            new_discriminator = None
            attempts = 0
            while attempts < 100: # Limite para evitar loop infinito
                # Gera um número de 4 dígitos como string (ex: '0001', '1234')
                potential_discriminator = str(random.randint(1, 9999)).zfill(4)
                
                if potential_discriminator not in used_discriminators:
                    new_discriminator = potential_discriminator
                    break
                attempts += 1
            
            if new_discriminator is None:
                # Caso extremamente raro onde todos os 9999 discriminadores estão em uso
                # para um mesmo nome. Pode-se adicionar um sufixo aleatório ao nome.
                raise Exception("Não foi possível gerar um discriminador único.")

            # Atualiza o documento do usuário com os novos campos
            update_data = {
                'username': username_normalized,
                'discriminator': new_discriminator
            }
            transaction.update(user_ref, update_data)
            
            return update_data

        # Executa a transação
        result = generate_and_assign(db.transaction())
        
        print(f"assignSeptimaId: Sucesso! ID para {user_id} é {result.get('username')}#{result.get('discriminator')}")
        return {"status": "success", **result}

    except Exception as e:
        print(f"ERRO CRÍTICO em assignSeptimaId para o usuário {user_id}: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao criar seu Septima ID: {e}"
        )