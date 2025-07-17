# functions/main.py
import os
import sys
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, credentials, auth, messaging
from firebase_functions import https_fn, options,pubsub_fn, firestore_fn, scheduler_fn
from firebase_functions.firestore_fn import on_document_updated, Change, Event
from firebase_admin.firestore import transactional
from datetime import datetime, time, timezone, timedelta
import asyncio
import traceback
from math import pow

import base64
import json
from unidecode import unidecode # <<< ADICIONE ESTE IMPORT NO TOPO DO ARQUIVO
import random
import requests
import google.auth
import google.auth.transport.requests

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

try:
    import book_search_service
    print("Módulo 'book_search_service' importado com sucesso.")
except ImportError as e_import_book:
    book_search_service = None
    print(f"AVISO: Não foi possível importar 'book_search_service': {e_import_book}")


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
    
    # 1. Validação de Autenticação e Parâmetros
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
        # 2. Lógica de Custo e Verificação de Assinatura
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        
        # Lógica robusta para verificar se a assinatura está ativa
        is_premium = False
        if subscription_status == 'active':
            subscription_end_date = user_data.get('subscriptionEndDate')
            if subscription_end_date:
                end_date_aware = None
                if isinstance(subscription_end_date, datetime):
                    end_date_aware = subscription_end_date.replace(tzinfo=timezone.utc)
                elif isinstance(subscription_end_date, firestore.firestore.Timestamp):
                    end_date_aware = subscription_end_date.to_datetime().replace(tzinfo=timezone.utc)
                
                if end_date_aware and end_date_aware > datetime.now(timezone.utc):
                    is_premium = True

        if not is_premium:
            print(f"Usuário {user_id} não é Premium. Verificando moedas.")
            
            # --- Lógica de Custo Atualizada ---
            reward_coins = user_data.get('weeklyRewardCoins', 0)
            reward_expiration_raw = user_data.get('rewardExpiration')
            
            has_valid_reward = False
            if reward_expiration_raw and isinstance(reward_coins, int) and reward_coins >= CHAT_COST:
                expiration_dt_aware = None
                if isinstance(reward_expiration_raw, datetime):
                    expiration_dt_aware = reward_expiration_raw.replace(tzinfo=timezone.utc)
                elif isinstance(reward_expiration_raw, firestore.firestore.Timestamp):
                    expiration_dt_aware = reward_expiration_raw.to_datetime().replace(tzinfo=timezone.utc)
                
                if expiration_dt_aware and expiration_dt_aware > datetime.now(timezone.utc):
                    has_valid_reward = True

            if has_valid_reward:
                print(f"Usando moedas de recompensa. Saldo: {reward_coins}. Custo: {CHAT_COST}")
                new_reward_coins = reward_coins - CHAT_COST
                user_ref.update({'weeklyRewardCoins': new_reward_coins})
            else:
                print("Sem moedas de recompensa válidas. Verificando moedas normais.")
                current_coins = user_data.get('userCoins', 0)
                if current_coins < CHAT_COST:
                    print(f"Moedas normais insuficientes para {user_id}. Possui: {current_coins}, Custo: {CHAT_COST}")
                    raise https_fn.HttpsError(
                        code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                        message=f"Moedas insuficientes. Você precisa de {CHAT_COST} moedas para enviar uma mensagem."
                    )
                
                print(f"Deduzindo {CHAT_COST} moedas normais de {user_id}.")
                new_coin_total = current_coins - CHAT_COST
                user_ref.update({'userCoins': new_coin_total})
            # --- Fim da Lógica de Custo ---
        else:
            print(f"Usuário {user_id} é Premium. Chat gratuito.")

        # 3. PROSSEGUE COM A LÓGICA DO CHAT (após a verificação de custo)
        chat_result = _run_async_handler_wrapper(
            chat_service.get_rag_chat_response(user_query, chat_history)
        )
        
        return {
            "success": True,
            "response": chat_result.get("response"),
            "sources": chat_result.get("sources", [])
        }

    except https_fn.HttpsError as e:
        # Relança os erros esperados (como moedas insuficientes) para o cliente
        raise e
    except Exception as e:
        print(f"Erro inesperado em chatWithSermons (main.py): {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro interno ao processar o chat: {str(e)}")

@https_fn.on_call(
    secrets=["openai-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=120
)
def chatWithBibleSection(request: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    # 1. Validação de Autenticação e Parâmetros
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
        # 2. Lógica de Custo e Verificação de Assinatura
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        
        # Lógica para verificar se a assinatura está ativa
        is_premium = False
        if subscription_status == 'active':
            subscription_end_date = user_data.get('subscriptionEndDate')
            if subscription_end_date:
                # Converte para datetime com timezone para comparação segura
                end_date_aware = subscription_end_date.replace(tzinfo=timezone.utc)
                if end_date_aware > datetime.now(timezone.utc):
                    is_premium = True

        if use_strongs and not is_premium:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="A análise etimológica é um recurso Premium."
            )
        
        if not is_premium:
            print(f"Usuário {user_id} não é Premium. Verificando moedas.")
            
            # --- INÍCIO DA LÓGICA DE CUSTO ATUALIZADA ---
            reward_coins = user_data.get('weeklyRewardCoins', 0)
            reward_expiration = user_data.get('rewardExpiration') # Pode ser Timestamp
            
            has_valid_reward = False
            if reward_expiration and isinstance(reward_expiration, firestore.firestore.Timestamp):
                 if reward_expiration.to_datetime().replace(tzinfo=timezone.utc) > datetime.now(timezone.utc):
                     has_valid_reward = True

            if has_valid_reward and reward_coins >= CHAT_COST:
                print(f"Usando moedas de recompensa. Saldo: {reward_coins}. Custo: {CHAT_COST}")
                new_reward_coins = reward_coins - CHAT_COST
                user_ref.update({'weeklyRewardCoins': new_reward_coins})
            else:
                print("Sem moedas de recompensa válidas. Verificando moedas normais.")
                current_coins = user_data.get('userCoins', 0)
                if current_coins < CHAT_COST:
                    print(f"Moedas normais insuficientes para {user_id}. Possui: {current_coins}, Custo: {CHAT_COST}")
                    raise https_fn.HttpsError(
                        code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                        message=f"Moedas insuficientes. Você precisa de {CHAT_COST} moedas."
                    )
                
                print(f"Deduzindo {CHAT_COST} moedas normais de {user_id}.")
                new_coin_total = current_coins - CHAT_COST
                user_ref.update({'userCoins': new_coin_total})
            # --- FIM DA LÓGICA DE CUSTO ATUALIZADA ---
        else:
            print(f"Usuário {user_id} é Premium. Chat da Bíblia gratuito.")
        
        # 3. Execução da Lógica Principal do Chat
        if bible_chat_service is None:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de chat da Bíblia indisponível).")

        final_response = _run_async_handler_wrapper(
            bible_chat_service.get_bible_chat_response(
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
    """
    Acionado sempre que um documento em 'userBibleProgress' é atualizado.
    Calcula e atualiza o 'rankingScore' do usuário com base no tempo de leitura
    e no progresso geral da leitura da Bíblia.
    """
    if event.data is None:
        print("calculateUserScore: Evento sem dados. Encerrando.")
        return

    # Pega os dados do documento antes e depois da atualização
    data_before = event.data.before.to_dict() if event.data.before and event.data.before.exists else {}
    data_after = event.data.after.to_dict() if event.data.after and event.data.after.exists else {}
    
    # Se não houver dados após a atualização, não há o que fazer
    if not data_after:
        print("calculateUserScore: Documento deletado ou vazio. Encerrando.")
        return

    # Otimização: Se os campos relevantes não mudaram, não recalcula.
    raw_time_before = data_before.get('rawReadingTime', 0)
    raw_time_after = data_after.get('rawReadingTime', 0)
    books_before = data_before.get('books', {})
    books_after = data_after.get('books', {})
    
    if raw_time_after == raw_time_before and books_after == books_before:
        print(f"calculateUserScore: Nenhuma mudança relevante para User ID {event.params['userId']}. Encerrando.")
        return

    print(f"calculateUserScore: Mudança detectada para o usuário {event.params['userId']}. Iniciando cálculo.")
    
    metadata = _load_bible_metadata()
    if not metadata or 'total_secoes_biblia' not in metadata:
        print("ERRO em calculateUserScore: Metadados da Bíblia não estão disponíveis.")
        return

    total_bible_sections = metadata.get('total_secoes_biblia', 1)
    if total_bible_sections <= 0:
        print(f"ERRO em calculateUserScore: total_secoes_biblia é {total_bible_sections}, o que é inválido.")
        return

    # Calcula o total de seções lidas a partir do mapa 'books'
    total_read_sections = sum(len(progress.get('readSections', [])) for progress in books_after.values() if isinstance(progress, dict))
    
    # Calcula a porcentagem de progresso atual
    current_progress_percent = (total_read_sections / total_bible_sections) * 100
    
    bible_completion_count = data_after.get('bibleCompletionCount', 0)
    update_payload = {}
    
    # Verifica se o usuário completou a leitura
    if current_progress_percent >= 100.0:
        print(f"calculateUserScore: Usuário {event.params['userId']} completou a Bíblia! (Leitura #{bible_completion_count + 1})")
        
        # Incrementa o contador de conclusões
        bible_completion_count += 1
        
        # Reseta o progresso para a próxima leitura
        update_payload['books'] = {} 
        update_payload['currentProgressPercent'] = 0.0
    else:
        # Se não completou, apenas atualiza a porcentagem
        update_payload['currentProgressPercent'] = round(current_progress_percent, 2)

    update_payload['bibleCompletionCount'] = bible_completion_count

    # Calcula o score final
    # Multiplicador que valoriza o progresso e as conclusões anteriores
    progress_for_multiplier = update_payload['currentProgressPercent']
    progress_multiplier = (1 + (progress_for_multiplier / 100)) * (1 + (bible_completion_count * 0.5))
    
    # Score = tempo total lido * multiplicador de progresso
    ranking_score = raw_time_after * progress_multiplier
    update_payload['rankingScore'] = round(ranking_score, 2)
    
    print(f"calculateUserScore: Atualizando documento para {event.params['userId']} com payload: {update_payload}")
    try:
        # Pega a referência do documento que foi atualizado e aplica as novas mudanças
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
    

    # --- FUNÇÃO AGENDADA PARA O RANKING SEMANAL ---

@scheduler_fn.on_schedule(
    schedule="every sunday 00:01", # Roda todo Domingo à 00:01
    timezone=scheduler_fn.Timezone("America/Sao_Paulo"), # Fuso horário de São Paulo
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512, # Memória suficiente para processar lotes de usuários
    timeout_sec=540 # Timeout de 9 minutos para garantir a conclusão
)
def processWeeklyRanking(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Processa o ranking semanal. Esta função faz o seguinte:
    1. Busca os 200 melhores usuários da semana com base no 'rankingScore'.
    2. Para cada um desses usuários, salva sua posição final no campo 'previousRank' no documento da coleção 'users'.
    3. Para os 10 primeiros, distribui moedas de recompensa ('weeklyRewardCoins') com uma data de expiração de 7 dias.
    4. Reseta os campos 'rawReadingTime' e 'rankingScore' para 0 em TODOS os documentos da coleção 'userBibleProgress' para iniciar a nova semana.
    """
    print("Iniciando o processamento do ranking semanal...")
    db = get_db()
    
    # Mapeamento de recompensas: Posição -> Moedas
    rewards = {
        1: 700, 2: 300, 3: 100, 4: 80, 5: 70,
        6: 60, 7: 50, 8: 40, 9: 30, 10: 20
    }
    
    try:
        # --- ETAPA 1: Obter o ranking da semana e preparar as atualizações ---
        
        # Busca os 200 melhores scores da coleção de progresso para salvar suas posições finais.
        # Limitamos a 200 para manter a performance, mas você pode ajustar este número.
        weekly_ranking_query = db.collection('userBibleProgress').order_by('rankingScore', direction=firestore.Query.DESCENDING).limit(200)
        weekly_ranking_docs = list(weekly_ranking_query.stream())
        
        if not weekly_ranking_docs:
            print("Nenhum usuário com rankingScore encontrado. Encerrando o processamento da semana.")
            return

        print(f"Encontrados {len(weekly_ranking_docs)} usuários no ranking desta semana para processamento.")
        
        # Prepara a distribuição de recompensas e o salvamento do rank anterior em um único batch
        batch = db.batch()
        now = datetime.now(timezone.utc)
        expiration_date = now + timedelta(days=7) # Moedas expiram em 7 dias
        
        for i, progress_doc in enumerate(weekly_ranking_docs):
            rank = i + 1
            user_id = progress_doc.id
            user_ref = db.collection('users').document(user_id) # Referência ao doc na coleção 'users'
            
            # A. Salva a posição da semana como 'previousRank' para a próxima semana
            batch.update(user_ref, {'previousRank': rank})
            
            # B. Distribui recompensas para os 10 primeiros
            reward_amount = rewards.get(rank)
            if reward_amount:
                batch.update(user_ref, {
                    'weeklyRewardCoins': reward_amount,
                    'rewardExpiration': expiration_date
                })
                print(f"Recompensa de {reward_amount} moedas preparada para o usuário {user_id} (Rank {rank}).")
        
        # Executa o batch de recompensas e salvamento de rank
        batch.commit()
        print("Recompensas e posições anteriores ('previousRank') salvas com sucesso.")

        # --- ETAPA 2: Resetar o tempo de leitura de TODOS os usuários ---
        
        print("Iniciando reset do 'rawReadingTime' e 'rankingScore' para todos os usuários...")
        all_users_progress_ref = db.collection('userBibleProgress')
        
        # Processa o reset em lotes para evitar problemas de memória e timeout
        docs_stream = all_users_progress_ref.stream()
        
        reset_batch = db.batch()
        docs_processed = 0
        for doc in docs_stream:
            # Reseta apenas os campos da competição semanal
            reset_batch.update(doc.reference, {
                'rawReadingTime': 0,
                'rankingScore': 0
            })
            docs_processed += 1
            
            # O Firestore limita um batch a 500 operações. Usamos 400 por segurança.
            if docs_processed % 400 == 0:
                reset_batch.commit()
                reset_batch = db.batch() # Inicia um novo batch
                print(f"{docs_processed} documentos tiveram o score resetado...")

        # Executa o último batch com os documentos restantes
        reset_batch.commit()
        
        print(f"Reset concluído para um total de {docs_processed} usuários.")
        print("Processamento do ranking semanal finalizado com sucesso.")

    except Exception as e:
        print(f"ERRO CRÍTICO durante o processamento do ranking semanal: {e}")
        traceback.print_exc()

@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512, # Memória suficiente para múltiplas chamadas de IA
    timeout_sec=90 # Timeout maior por causa das múltiplas chamadas
)
def semanticBookSearch(request: https_fn.CallableRequest) -> dict:
    """
    Recebe a query do usuário, chama o serviço de busca de livros e retorna as recomendações.
    """
    print("Handler semanticBookSearch chamado.")
    
    # Verifica se o serviço foi importado corretamente
    if book_search_service is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Erro interno do servidor (módulo de busca de livros indisponível)."
        )

    user_query = request.data.get("query")
    if not user_query or not isinstance(user_query, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'query' (string) é obrigatório."
        )
    
    try:
        # A função _run_async_handler_wrapper executa nossa lógica assíncrona
        recommendations = _run_async_handler_wrapper(
            book_search_service.get_book_recommendations(user_query, top_k=5) # Busca os 5 melhores
        )
        
        print(f"semanticBookSearch: Retornando {len(recommendations)} recomendações para o cliente.")
        return {"recommendations": recommendations if isinstance(recommendations, list) else []}
        
    except Exception as e:
        print(f"Erro inesperado em semanticBookSearch (main.py): {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Erro ao buscar recomendações de livros: {str(e)}"
        )

@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256,
    secrets=["play-store-service-account-key"] # Necessário para autenticar a chamada HTTP do FCM
)
def sendFriendRequest(req: https_fn.CallableRequest) -> dict:
    """
    Permite que um usuário autenticado envie um pedido de amizade para outro usuário.
    - É transacional para garantir consistência.
    - Cria uma notificação in-app para o usuário alvo.
    - Envia uma notificação push (FCM) para o dispositivo do usuário alvo.
    """
    db = get_db()

    # 1. Validação de Autenticação e Parâmetros de Entrada
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )

    current_user_id = req.auth.uid
    target_user_id = req.data.get("targetUserId")

    if not target_user_id or not isinstance(target_user_id, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'targetUserId' (string) é obrigatório."
        )

    if current_user_id == target_user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Você não pode enviar um pedido de amizade para si mesmo."
        )

    # 2. Referências aos documentos dos usuários no Firestore
    current_user_ref = db.collection('users').document(current_user_id)
    target_user_ref = db.collection('users').document(target_user_id)

    # 3. Definição da Transação Atômica
    # Isso garante que as leituras e escritas nos documentos dos usuários
    # aconteçam como uma única operação, prevenindo inconsistências.
    @firestore.transactional
    def _send_request_transaction(transaction):
        # Lê os documentos dentro da transação para ter os dados mais atuais
        current_user_doc = current_user_ref.get(transaction=transaction)
        target_user_doc = target_user_ref.get(transaction=transaction)

        if not current_user_doc.exists:
             raise Exception(f"Documento do requisitante não encontrado: {current_user_id}")
        if not target_user_doc.exists:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="O usuário alvo não foi encontrado."
            )
        
        # Converte os documentos para dicionários para fácil acesso
        current_user_data = current_user_doc.to_dict() or {}
        target_user_data = target_user_doc.to_dict() or {}
        
        # Verificações de estado para evitar operações redundantes
        friends_list = current_user_data.get('friends', [])
        sent_requests = current_user_data.get('friendRequestsSent', [])

        if target_user_id in friends_list:
            return {"status": "already_friends"}
        if target_user_id in sent_requests:
            return {"status": "request_already_sent"}

        # Atualiza os arrays de pedidos nos dois documentos
        transaction.update(current_user_ref, {
            'friendRequestsSent': firestore.ArrayUnion([target_user_id])
        })
        transaction.update(target_user_ref, {
            'friendRequestsReceived': firestore.ArrayUnion([current_user_id])
        })

        # Retorna os dados necessários para as próximas etapas (notificações)
        return {
            "status": "success",
            "requester_name": current_user_data.get("nome", "Alguém"),
            "target_tokens": target_user_data.get("fcmTokens", [])
        }

    # 4. Execução Principal da Lógica
    try:
        # Executa a transação definida acima
        transaction_result = _send_request_transaction(db.transaction())

        # Se a transação retornou um status de "já amigos" ou "pedido já enviado", encerramos aqui.
        if transaction_result.get("status") in ["already_friends", "request_already_sent"]:
             print(f"Operação não necessária: {transaction_result.get('status')}")
             return {"status": "success", "message": "Operação não necessária."}

        # Se a transação foi bem-sucedida, prosseguimos para as notificações.
        requester_name = transaction_result["requester_name"]
        target_tokens = transaction_result["target_tokens"]
        
        # 4a. Criação da Notificação In-App (persistente no Firestore)
        try:
            current_user_doc = current_user_ref.get()
            current_user_data = current_user_doc.to_dict() or {}
            
            target_user_notifications_ref = target_user_ref.collection('notifications')
            target_user_notifications_ref.add({
                "type": "friend_request",
                "fromUserId": current_user_id,
                "fromUserName": current_user_data.get("nome", "Usuário"),
                "fromUserPhotoUrl": current_user_data.get("photoURL", ""),
                "timestamp": firestore.SERVER_TIMESTAMP,
                "isRead": False
            })
            print(f"Documento de notificação 'friend_request' criado para o usuário {target_user_id}.")
        except Exception as in_app_notification_error:
            print(f"AVISO: Falha ao criar a notificação in-app: {in_app_notification_error}")

        # 4b. Envio da Notificação Push (FCM)
        if target_tokens:
            try:
                # Obtenção de credenciais de autenticação
                creds, project_id = google.auth.default(scopes=['https://www.googleapis.com/auth/firebase.messaging'])
                auth_req = google.auth.transport.requests.Request()
                creds.refresh(auth_req)
                access_token = creds.token
                
                headers = {'Authorization': f'Bearer {access_token}', 'Content-Type': 'application/json'}
                url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
                
                # Envio da notificação para cada dispositivo do usuário
                for token in target_tokens:
                    body = {
                        "message": {
                            "token": token,
                            "notification": {
                                "title": "Novo Pedido de Amizade!",
                                "body": f"{requester_name} quer ser seu amigo no Septima."
                            },
                            "data": {"type": "friend_request", "screen": "/friends"}
                        }
                    }
                    response = requests.post(url, headers=headers, json=body)
                    if response.status_code == 200:
                        print(f"Notificação push enviada com sucesso para o token: {token[:20]}...")
                    else:
                        print(f"ERRO ao enviar notificação push. Status: {response.status_code}, Resposta: {response.text}")
            
            except Exception as push_notification_error:
                print(f"AVISO: Falha no envio da notificação push: {push_notification_error}")
        else:
            print(f"Usuário alvo ({target_user_id}) não possui tokens FCM. Nenhuma notificação push foi enviada.")
        
        # 5. Retorno de Sucesso para o Cliente
        return {"status": "success", "message": "Pedido de amizade enviado com sucesso."}

    except Exception as e:
        print(f"ERRO CRÍTICO em sendFriendRequest: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao enviar o pedido: {e}"
        )
    
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def acceptFriendRequest(req: https_fn.CallableRequest) -> dict:
    """
    Permite que o usuário atual aceite um pedido de amizade de outro usuário.
    É transacional para remover os pedidos e adicionar à lista de amigos de ambos.
    """
    db = get_db()
    
    # 1. Validação
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )

    current_user_id = req.auth.uid
    requester_user_id = req.data.get("requesterUserId")

    if not requester_user_id or not isinstance(requester_user_id, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'requesterUserId' (string) é obrigatório."
        )

    # 2. Referências aos documentos
    current_user_ref = db.collection('users').document(current_user_id)
    requester_user_ref = db.collection('users').document(requester_user_id)

    # 3. Transação
    @transactional
    def _accept_request_transaction(transaction):
        # Lê os documentos
        current_user_doc = current_user_ref.get(transaction=transaction)
        requester_user_doc = requester_user_ref.get(transaction=transaction)

        if not current_user_doc.exists or not requester_user_doc.exists:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="Usuário não encontrado."
            )
        
        # Verifica se o pedido realmente existe
        current_user_data = current_user_doc.to_dict() or {}
        received_requests = current_user_data.get('friendRequestsReceived', [])

        if requester_user_id not in received_requests:
             raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="Nenhum pedido de amizade deste usuário para aceitar."
            )
        
        # 4. Atualiza os documentos de ambos os usuários
        # Remove o pedido das listas de "pendentes"
        transaction.update(current_user_ref, {
            'friendRequestsReceived': firestore.ArrayRemove([requester_user_id])
        })
        transaction.update(requester_user_ref, {
            'friendRequestsSent': firestore.ArrayRemove([current_user_id])
        })
        
        # Adiciona um ao outro na lista de amigos de ambos
        transaction.update(current_user_ref, {
            'friends': firestore.ArrayUnion([requester_user_id])
        })
        transaction.update(requester_user_ref, {
            'friends': firestore.ArrayUnion([current_user_id])
        })

        return {"status": "success", "message": "Amizade aceita!"}

    # Inicia a transação
    try:
        result = _accept_request_transaction(db.transaction())
        return result
    except Exception as e:
        print(f"ERRO em acceptFriendRequest: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao aceitar a amizade: {e}"
        )

@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def findUserBySeptimaId(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    septima_id = req.data.get("septimaId")
    print(f"Buscando pelo Septima ID: {septima_id}")  # <-- LOG ADICIONADO

    if not septima_id or "#" not in septima_id:
        print("Erro: Formato de ID inválido.") # <-- LOG ADICIONADO
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O formato do Septima ID é inválido. Use 'username#1234'."
        )
    
    username, discriminator = septima_id.split('#', 1)
    print(f"Username extraído: '{username}', Discriminator: '{discriminator}'") # <-- LOG ADICIONADO

    try:
        query = db.collection('users').where('username', '==', username).where('discriminator', '==', discriminator).limit(1)
        docs = list(query.stream())
        
        if not docs:
            print("Resultado da busca: Nenhum documento encontrado.") # <-- LOG ADICIONADO
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="Nenhum usuário encontrado com este ID."
            )
        
        user_data = docs[0].to_dict()
        user_id = docs[0].id
        print(f"Usuário encontrado! ID: {user_id}, Nome: {user_data.get('nome')}") # <-- LOG ADICIONADO

        response_payload = {
            "status": "success",
            "user": {
                "userId": user_id,
                "nome": user_data.get("nome"),
                "photoURL": user_data.get("photoURL"),
                "descrição": user_data.get("descrição")
            }
        }
        
        print(f"Retornando payload de sucesso: {response_payload}") # <-- LOG ADICIONADO
        return response_payload

    except https_fn.HttpsError as e:
        # Se for um erro que nós mesmos geramos (como NOT_FOUND), apenas relance.
        raise e
    except Exception as e:
        print(f"ERRO INTERNO em findUserBySeptimaId: {e}")
        traceback.print_exc() # Imprime o stack trace completo nos logs para depuração
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao buscar o usuário: {e}"
        )

@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def declineFriendRequest(req: https_fn.CallableRequest) -> dict:
    """
    Permite que o usuário atual recuse um pedido de amizade.
    """
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    current_user_id = req.auth.uid
    requester_user_id = req.data.get("requesterUserId")

    if not requester_user_id or not isinstance(requester_user_id, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="'requesterUserId' é obrigatório.")

    current_user_ref = db.collection('users').document(current_user_id)
    requester_user_ref = db.collection('users').document(requester_user_id)

    @transactional
    def _decline_request_transaction(transaction):
        # Remove o pedido da lista de recebidos do usuário atual
        transaction.update(current_user_ref, {
            'friendRequestsReceived': firestore.ArrayRemove([requester_user_id])
        })
        # Remove o pedido da lista de enviados do outro usuário
        transaction.update(requester_user_ref, {
            'friendRequestsSent': firestore.ArrayRemove([current_user_id])
        })
        return {"status": "success", "message": "Pedido de amizade recusado."}

    try:
        result = _decline_request_transaction(db.transaction())
        return result
    except Exception as e:
        print(f"ERRO em declineFriendRequest: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro ao recusar o pedido: {e}")