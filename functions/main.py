# functions/main.py

import stripe
import os
import sys
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, credentials, auth, messaging
from firebase_functions import https_fn, options,pubsub_fn, firestore_fn, scheduler_fn
from firebase_functions.firestore_fn import on_document_updated, Change, Event
from firebase_admin.firestore import transactional
from datetime import datetime, time, timezone, timedelta
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

import asyncio
import httpx
import traceback
from math import pow
from werkzeug.security import generate_password_hash, check_password_hash

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

from openai import OpenAI

import mercadopago
from mercadopago.config import RequestOptions
from datetime import datetime, timedelta, timezone

print(">>>> main.py (VERSÃO LAZY INIT - CORRETA) <<<<")
CHAT_COST = 5


try:
    import bible_search_service
    import sermons_service
    import chat_service
    import bible_chat_service
    import book_search_service
    import community_search_service
    print("Módulos de serviço importados com sucesso.")
except ImportError as e_import:
    print(f"AVISO: Falha na importação de um ou mais módulos de serviço: {e_import}")
    # Definir como None para verificações de segurança
    bible_search_service = sermons_service = chat_service = bible_chat_service = book_search_service = None


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
    memory=options.MemoryOption.MB_256 
)
def updateReadingTime(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )
    
    user_id = req.auth.uid
    seconds_to_add_raw = req.data.get("secondsToAdd")
    
    print('Payload recebido para secondsToAdd:', seconds_to_add_raw) # Log para depuração

    # ✅ INÍCIO DA CORREÇÃO DEFINITIVA
    processed_seconds = 0
    if isinstance(seconds_to_add_raw, dict) and 'value' in seconds_to_add_raw:
        # Caso 1: Recebeu o objeto Protobuf {'@type': ..., 'value': '20'}
        try:
            # O valor vem como string, então convertemos para int
            processed_seconds = int(seconds_to_add_raw['value'])
        except (ValueError, TypeError):
            processed_seconds = 0 # Valor inválido dentro do objeto
    elif isinstance(seconds_to_add_raw, (int, float)):
        # Caso 2: Recebeu um número normal (para robustez)
        processed_seconds = int(seconds_to_add_raw)
    
    # Agora, validamos o número que extraímos
    if processed_seconds <= 0:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=f"O parâmetro 'secondsToAdd' é inválido ou não é positivo. Valor processado: {processed_seconds}"
        )
    
    seconds_to_add = processed_seconds
    # ✅ FIM DA CORREÇÃO DEFINITIVA

    print(f"updateReadingTime: Recebidos {seconds_to_add} segundos para adicionar ao usuário {user_id}.")
    
    try:
        progress_doc_ref = db.collection('userBibleProgress').document(user_id)
        
        progress_doc_ref.set({
            'rawReadingTime': firestore.Increment(seconds_to_add),
            'lastTimeUpdate': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
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
    schedule="every sunday 00:01",
    timezone=scheduler_fn.Timezone("America/Sao_Paulo"),
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=540
)
def processWeeklyRanking(event: scheduler_fn.ScheduledEvent) -> None:
    print("Iniciando o processamento do ranking semanal...")
    db = get_db()
    
    rewards = {
        1: 700, 2: 300, 3: 100, 4: 80, 5: 70,
        6: 60, 7: 50, 8: 40, 9: 30, 10: 20
    }
    
    try:
        # --- ETAPA 1: Obter o ranking e preparar as atualizações ---
        
        weekly_ranking_query = db.collection('userBibleProgress').order_by('rankingScore', direction=firestore.Query.DESCENDING).limit(200)
        weekly_ranking_docs = list(weekly_ranking_query.stream())
        
        if not weekly_ranking_docs:
            print("Nenhum usuário com rankingScore encontrado. Encerrando.")
            return

        print(f"Encontrados {len(weekly_ranking_docs)} usuários no ranking para processamento.")
        
        batch = db.batch()
        now = datetime.now(timezone.utc)
        expiration_date = now + timedelta(days=7)
        
        # <<< INÍCIO DA CORREÇÃO >>>
        # Pega todos os IDs dos usuários do ranking para verificar sua existência
        user_ids_in_ranking = [doc.id for doc in weekly_ranking_docs]
        
        # Busca todos os documentos correspondentes na coleção 'users' de uma só vez
        users_ref = db.collection('users')
        users_snapshot = users_ref.where(firestore.firestore.FieldPath.document_id(), 'in', user_ids_in_ranking).get()
        
        # Cria um conjunto (Set) com os IDs dos usuários que REALMENTE existem
        existing_user_ids = {doc.id for doc in users_snapshot}
        print(f"Verificação de existência concluída. {len(existing_user_ids)} usuários válidos encontrados na coleção 'users'.")
        # <<< FIM DA CORREÇÃO >>>

        for i, progress_doc in enumerate(weekly_ranking_docs):
            rank = i + 1
            user_id = progress_doc.id

            # <<< CORREÇÃO AQUI: Verifica se o usuário existe antes de tentar atualizar >>>
            if user_id in existing_user_ids:
                user_ref = db.collection('users').document(user_id)
                
                batch.update(user_ref, {'previousRank': rank})
                
                reward_amount = rewards.get(rank)
                if reward_amount:
                    batch.update(user_ref, {
                        'weeklyRewardCoins': reward_amount,
                        'rewardExpiration': expiration_date
                    })
                    print(f"Recompensa de {reward_amount} moedas preparada para o usuário {user_id} (Rank {rank}).")
            else:
                # Se o usuário não existe, apenas loga um aviso e continua para o próximo
                print(f"AVISO: O usuário {user_id} (Rank {rank}) existe em 'userBibleProgress', mas não na coleção 'users'. A atualização foi pulada.")
        
        batch.commit()
        print("Recompensas e posições anteriores ('previousRank') salvas com sucesso para usuários válidos.")

        # --- ETAPA 2: Resetar o tempo de leitura de TODOS os usuários ---
        # (Esta parte do código já está correta e não precisa de alterações)
        
        print("Iniciando reset do 'rawReadingTime' e 'rankingScore'...")
        all_users_progress_ref = db.collection('userBibleProgress')
        docs_stream = all_users_progress_ref.stream()
        
        reset_batch = db.batch()
        docs_processed = 0
        for doc in docs_stream:
            reset_batch.update(doc.reference, {
                'rawReadingTime': 0,
                'rankingScore': 0
            })
            docs_processed += 1
            
            if docs_processed % 400 == 0:
                reset_batch.commit()
                reset_batch = db.batch()
                print(f"{docs_processed} documentos tiveram o score resetado...")

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
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    current_user_id = req.auth.uid
    requester_user_id = req.data.get("requesterUserId")

    if not requester_user_id or not isinstance(requester_user_id, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="'requesterUserId' é obrigatório.")

    current_user_ref = db.collection('users').document(current_user_id)
    requester_user_ref = db.collection('users').document(requester_user_id)
    notifications_ref = current_user_ref.collection('notifications')

    try:
        @transactional
        def _accept_request_transaction(transaction):
            # --- FASE 1: LEITURA DE TODOS OS DOCUMENTOS ---
            current_user_doc = current_user_ref.get(transaction=transaction)
            requester_user_doc = requester_user_ref.get(transaction=transaction)
            
            notif_query = notifications_ref.where('fromUserId', '==', requester_user_id).where('type', '==', 'friend_request').where('isRead', '==', False).limit(1)
            notif_docs = list(notif_query.stream(transaction=transaction))
            
            # --- FASE 2: VERIFICAÇÃO E LÓGICA DE NEGÓCIOS ---
            if not current_user_doc.exists or not requester_user_doc.exists:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Usuário não encontrado.")
            
            current_user_data = current_user_doc.to_dict() or {}
            received_requests = current_user_data.get('friendRequestsReceived', [])

            if requester_user_id not in received_requests:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message="Nenhum pedido de amizade deste usuário para aceitar.")
            
            # --- FASE 3: ESCRITA DE TODOS OS DOCUMENTOS ---
            # Atualiza amizades e pedidos
            transaction.update(current_user_ref, {'friendRequestsReceived': firestore.ArrayRemove([requester_user_id])})
            transaction.update(requester_user_ref, {'friendRequestsSent': firestore.ArrayRemove([current_user_id])})
            transaction.update(current_user_ref, {'friends': firestore.ArrayUnion([requester_user_id])})
            transaction.update(requester_user_ref, {'friends': firestore.ArrayUnion([current_user_id])})
            
            # Atualiza a notificação
            if notif_docs:
                notif_to_update_ref = notif_docs[0].reference
                print(f"Encontrada notificação {notif_to_update_ref.id} para marcar como lida.")
                transaction.update(notif_to_update_ref, {"isRead": True})
            else:
                print(f"AVISO: Nenhuma notificação não lida encontrada para o pedido de {requester_user_id}.")

            return {"status": "success", "message": "Amizade aceita!"}

        result = _accept_request_transaction(db.transaction())
        return result
        
    except Exception as e:
        print(f"ERRO em acceptFriendRequest: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro ao aceitar a amizade: {e}")
    
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 
)
def getRandomUsers(req: https_fn.CallableRequest) -> dict:
    """
    Retorna uma lista paginada de usuários para a tela 'Encontrar Amigos',
    usando o ID do documento para uma busca pseudo-aleatória estável.
    """
    db = get_db()
    
    limit = req.data.get("limit", 20)
    if not isinstance(limit, int):
        print(f"AVISO: O parâmetro 'limit' não é um inteiro (tipo: {type(limit)}). Usando o padrão 20.")
        limit = 20

    start_after_id = req.data.get("startAfter")

    try:
        users_ref = db.collection('users')
        query = users_ref.order_by('__name__')

        if start_after_id:
            last_doc_snapshot = users_ref.document(start_after_id).get()
            if last_doc_snapshot.exists:
                query = query.start_after(last_doc_snapshot)
        else:
            # ✅✅✅ CORREÇÃO CRÍTICA AQUI ✅✅✅
            # 1. Geramos uma REFERÊNCIA de documento, não apenas o ID string.
            random_doc_ref = users_ref.document()
            
            # 2. Usamos a referência completa na query.
            # Também usamos a sintaxe com 'filter=' que o warning sugere.
            query = query.where(filter=FieldFilter('__name__', '>=', random_doc_ref))

        query = query.limit(limit)
        docs = list(query.stream())
        
        # Lógica de fallback (sem alterações)
        if len(docs) < limit and not start_after_id:
            print(f"Busca inicial retornou {len(docs)}/{limit}. Buscando mais do início para completar.")
            remaining_limit = limit - len(docs)
            existing_ids = {doc.id for doc in docs}
            query_from_start = users_ref.order_by('__name__').limit(remaining_limit)
            additional_docs = list(query_from_start.stream())
            for doc in additional_docs:
                if doc.id not in existing_ids:
                    docs.append(doc)

        # Formata a lista final (sem alterações)
        users_list = []
        for doc in docs:
            user_data = doc.to_dict()
            users_list.append({
                "userId": doc.id,
                "nome": user_data.get("nome"),
                "photoURL": user_data.get("photoURL"),
                "denomination": user_data.get("denomination")
            })

        print(f"Retornando {len(users_list)} usuários.")
        return {"users": users_list}

    except Exception as e:
        print(f"ERRO em getRandomUsers: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro ao buscar usuários.")

    
# =================================================================
# <<< FUNÇÃO findUserBySeptimaId ATUALIZADA E RENOMEADA >>>
# =================================================================
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def findUsers(req: https_fn.CallableRequest) -> dict: # <<< NOME ALTERADO
    """
    Busca usuários por ID Septima (nome#1234) ou por nome (prefix search).
    Retorna sempre uma lista de resultados.
    """
    db = get_db()
    
    query_text = req.data.get("query")
    print(f"Buscando por: '{query_text}'")

    if not query_text:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'query' é obrigatório."
        )

    docs = []
    try:
        # Lógica para buscar por ID Septima
        if "#" in query_text:
            username, discriminator = query_text.split('#', 1)
            query = db.collection('users').where('username', '==', username).where('discriminator', '==', discriminator).limit(1)
            docs = list(query.stream())
        
        # Lógica para buscar por nome (prefix search)
        else:
            search_term = query_text.lower()
            # O caractere \uf8ff é um ponto de código Unicode alto que funciona como um "fim"
            # para strings, permitindo uma busca por prefixo eficiente no Firestore.
            end_term = search_term + '\uf8ff'
            
            query = db.collection('users').where('nome', '>=', search_term).where('nome', '<=', end_term).limit(10)
            docs = list(query.stream())
        
        if not docs:
            print("Nenhum usuário encontrado.")
            return {"users": []}

        # Formata os resultados para retornar uma lista consistente
        users_list = []
        for doc in docs:
            user_data = doc.to_dict()
            users_list.append({
                "userId": doc.id,
                "nome": user_data.get("nome"),
                "photoURL": user_data.get("photoURL"),
                "descrição": user_data.get("descrição"),
                "denomination": user_data.get("denomination")
            })

        print(f"Encontrados {len(users_list)} usuários.")
        return {"users": users_list}

    except Exception as e:
        print(f"ERRO INTERNO em findUsers: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao buscar usuários: {e}"
        )

@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def declineFriendRequest(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    current_user_id = req.auth.uid
    requester_user_id = req.data.get("requesterUserId")

    if not requester_user_id or not isinstance(requester_user_id, str):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="'requesterUserId' é obrigatório.")

    current_user_ref = db.collection('users').document(current_user_id)
    requester_user_ref = db.collection('users').document(requester_user_id)
    notifications_ref = current_user_ref.collection('notifications')

    try:
        @transactional
        def _decline_request_transaction(transaction):
            # --- FASE 1: LEITURA ---
            notif_query = notifications_ref.where('fromUserId', '==', requester_user_id).where('type', '==', 'friend_request').where('isRead', '==', False).limit(1)
            notif_docs = list(notif_query.stream(transaction=transaction))

            # --- FASE 2: LÓGICA E ESCRITA ---
            # Remove o pedido das listas
            transaction.update(current_user_ref, {'friendRequestsReceived': firestore.ArrayRemove([requester_user_id])})
            transaction.update(requester_user_ref, {'friendRequestsSent': firestore.ArrayRemove([current_user_id])})
            
            # Marca a notificação como lida
            if notif_docs:
                notif_to_update_ref = notif_docs[0].reference
                print(f"Encontrada notificação {notif_to_update_ref.id} para marcar como lida (recusa).")
                transaction.update(notif_to_update_ref, {"isRead": True})
            
            return {"status": "success", "message": "Pedido de amizade recusado."}

        result = _decline_request_transaction(db.transaction())
        return result

    except Exception as e:
        print(f"ERRO em declineFriendRequest: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro ao recusar o pedido: {e}")

@firestore_fn.on_document_created(
    document="posts/{postId}/replies/{replyId}",
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def onNewReply(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    db = get_db()
    
    post_id = event.params.get("postId")
    reply_data = event.data.to_dict() if event.data else {}
    
    reply_author_id = reply_data.get("authorId")
    reply_author_name = reply_data.get("authorName", "Alguém")

    if not post_id or not reply_author_id: return

    try:
        post_ref = db.collection("posts").document(post_id)
        post_doc = post_ref.get()
        if not post_doc.exists: return

        post_data = post_doc.to_dict()
        original_post_author_id = post_data.get("authorId")
        post_title = post_data.get("title", "sua pergunta")

        if original_post_author_id == reply_author_id: return

        post_author_doc = db.collection("users").document(original_post_author_id).get()
        if not post_author_doc.exists: return

        target_tokens = post_author_doc.to_dict().get("fcmTokens", [])
        if not target_tokens: return

        messages = [
            messaging.Message(
                notification=messaging.Notification(
                    title="Sua pergunta foi respondida!",
                    body=f"{reply_author_name} respondeu à sua pergunta: '{post_title[:50]}...'",
                ),
                data={"type": "post_reply", "screen": f"/post/{post_id}"},
                token=token,
            )
            for token in target_tokens
        ]

        if messages:
            # ✅ CORREÇÃO AQUI
            messaging.send_each(messages)
            print(f"Notificação de nova resposta enviada com sucesso para {original_post_author_id}.")

    except Exception as e:
        print(f"ERRO em onNewReply para post {post_id}: {e}")
        traceback.print_exc()


@firestore_fn.on_document_updated(
    document="posts/{postId}",
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def onBestAnswerMarked(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    db = get_db()
    
    post_id = event.params.get("postId")
    data_before = event.data.before.to_dict() if event.data.before else {}
    data_after = event.data.after.to_dict() if event.data.after else {}

    best_answer_id_before = data_before.get("bestAnswerId")
    best_answer_id_after = data_after.get("bestAnswerId")

    if best_answer_id_after is None or best_answer_id_after == best_answer_id_before: return

    try:
        post_title = data_after.get("title", "sua pergunta")

        reply_ref = db.collection("posts").document(post_id).collection("replies").document(best_answer_id_after)
        reply_doc = reply_ref.get()
        if not reply_doc.exists: return

        reply_data = reply_doc.to_dict()
        reply_author_id = reply_data.get("authorId")

        if not reply_author_id: return

        reply_author_doc = db.collection("users").document(reply_author_id).get()
        if not reply_author_doc.exists: return

        target_tokens = reply_author_doc.to_dict().get("fcmTokens", [])
        if not target_tokens: return
            
        messages = [
            messaging.Message(
                notification=messaging.Notification(
                    title="Sua resposta foi destaque! ✨",
                    body=f"Sua resposta para a pergunta '{post_title[:50]}...' foi marcada como a melhor!",
                ),
                data={"type": "best_answer", "screen": f"/post/{post_id}"},
                token=token,
            )
            for token in target_tokens
        ]

        if messages:
            # ✅ CORREÇÃO AQUI
            messaging.send_each(messages)
            print(f"Notificação de 'melhor resposta' enviada com sucesso para {reply_author_id}.")

    except Exception as e:
        print(f"ERRO em onBestAnswerMarked para post {post_id}: {e}")
        traceback.print_exc()

@firestore_fn.on_document_created(
    document="posts/{postId}/replies/{replyId}/comments/{commentId}",
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def onNewComment(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """
    Acionado quando um novo comentário é adicionado a uma resposta.
    - Incrementa o contador de respostas no post principal.
    - Envia uma notificação para o autor da resposta "pai".
    """
    db = get_db()
    
    post_id = event.params.get("postId")
    reply_id = event.params.get("replyId")
    comment_data = event.data.to_dict() if event.data else {}
    
    comment_author_id = comment_data.get("authorId")
    comment_author_name = comment_data.get("authorName", "Alguém")

    if not all([post_id, reply_id, comment_author_id]):
        print("onNewComment: Faltando IDs no gatilho. Encerrando.")
        return

    try:
        reply_ref = db.collection("posts").document(post_id).collection("replies").document(reply_id)
        reply_doc = reply_ref.get()
        if not reply_doc.exists: return

        reply_data = reply_doc.to_dict()
        original_reply_author_id = reply_data.get("authorId")
        reply_content_snippet = reply_data.get("content", "sua resposta")[:50]

        if original_reply_author_id != comment_author_id:
            reply_author_doc = db.collection("users").document(original_reply_author_id).get()
            if reply_author_doc.exists:
                target_tokens = reply_author_doc.to_dict().get("fcmTokens", [])
                if target_tokens:
                    # ✅ USANDO A ABORDAGEM CORRETA COM send_each
                    messages = [
                        messaging.Message(
                            notification=messaging.Notification(
                                title=f"{comment_author_name} respondeu ao seu comentário",
                                body=f"Em resposta a '{reply_content_snippet}...'",
                            ),
                            data={"type": "reply_comment", "screen": f"/post/{post_id}"},
                            token=token,
                        )
                        for token in target_tokens
                    ]
                    if messages:
                        messaging.send_each(messages)
                        print(f"Notificação de novo comentário enviada para {original_reply_author_id}.")

        # Lógica para incrementar o contador do post principal
        post_ref = db.collection("posts").document(post_id)
        post_ref.update({"answerCount": firestore.FieldValue.increment(1)})
        print(f"Contador de respostas do post {post_id} incrementado com sucesso.")

    except Exception as e:
        print(f"ERRO em onNewComment para post {post_id}: {e}")
        traceback.print_exc()


@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 
)
def createOrUpdatePost(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    user_id = req.auth.uid
    post_id = req.data.get("postId")
    data = req.data
    is_anonymous = data.get("isAnonymous", False)
    
    post_data = {
        "title": data.get("title"),
        "content": data.get("content"),
        "category": data.get("category"),
        "bibleReference": data.get("bibleReference"),
        "refBook": data.get("refBook"),
        "refChapter": data.get("refChapter"),
        "refVerses": data.get("refVerses"),
        "isPasswordProtected": data.get("isPasswordProtected", False),
        "lastUpdated": firestore.SERVER_TIMESTAMP,
    }
    
    password = data.get("password")
    if post_data["isPasswordProtected"] and password:
        post_data["passwordHash"] = generate_password_hash(password)

    try:
        if post_id:
            # --- MODO DE EDIÇÃO ---
            post_ref = db.collection('posts').document(post_id)
            post_doc = post_ref.get()
            if not post_doc.exists or post_doc.to_dict().get("authorId") != user_id:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.PERMISSION_DENIED, message="Você não tem permissão para editar este post.")
            
            if "password" in post_data and post_data["password"] is None:
                del post_data["password"]

            post_ref.update(post_data)

            # <<< INÍCIO DA LÓGICA DE REINDEXAÇÃO NO PINECONE >>>
            try:
                text_to_embed = f"{post_data.get('title', '')}\n\n{post_data.get('content', '')}".strip()
                if text_to_embed:
                    vector = _run_async_handler_wrapper(
                        community_search_service.generate_embedding_for_post_async(text_to_embed)
                    )
                    # Reutiliza os metadados existentes, atualizando apenas o que mudou
                    existing_metadata = post_doc.to_dict()
                    metadata_for_pinecone = {
                        "title": post_data.get("title", existing_metadata.get("title", "")),
                        "category": post_data.get("category", existing_metadata.get("category", "geral")),
                        "authorName": existing_metadata.get("authorName", ""),
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "content_preview": post_data.get("content", "")[:150]
                    }
                    _run_async_handler_wrapper(
                        community_search_service.upsert_post_to_pinecone_async(post_id, vector, metadata_for_pinecone)
                    )
            except Exception as e_pinecone:
                print(f"AVISO: Edição do post {post_id} no Firestore bem-sucedida, mas reindexação no Pinecone falhou: {e_pinecone}")
            # <<< FIM DA LÓGICA DE REINDEXAÇÃO >>>
            
            return {"status": "success", "message": "Post atualizado!", "postId": post_id}
        else:
            # --- MODO DE CRIAÇÃO (Sua lógica existente permanece aqui) ---
            # ... (seu código de criação de post, verificação de limite e indexação inicial) ...
            
            now = datetime.now(timezone.utc)
            twenty_four_hours_ago = now - timedelta(hours=24)
            seven_days_ago = now - timedelta(days=7)
            history_ref = db.collection('users').document(user_id).collection('postCreationHistory')
            weekly_posts_query = history_ref.where('createdAt', '>=', seven_days_ago).stream()
            daily_count = 0
            weekly_count = 0
            for post_record in weekly_posts_query:
                weekly_count += 1
                record_time = post_record.to_dict().get('createdAt')
                if record_time and record_time >= twenty_four_hours_ago:
                    daily_count += 1
            if daily_count >= 2:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, message="Você atingiu o limite de 2 posts por dia.")
            if weekly_count >= 7:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, message="Você atingiu o limite de 7 posts por semana.")

            user_doc = db.collection('users').document(user_id).get()
            user_data = user_doc.to_dict() or {}
            post_data["authorId"] = user_id # post_data["authorId"] = user_id # <<< SEMPRE SALVA O ID REAL

            # <<< INÍCIO DA MUDANÇA: Define nome e foto com base na flag >>>
            if is_anonymous:
                post_data["authorName"] = "Autor Anônimo"
                post_data["authorPhotoUrl"] = "" # URL vazia para usar o avatar padrão
            else:
                post_data["authorName"] = user_data.get('nome', 'Anônimo')
                post_data["authorPhotoUrl"] = user_data.get('photoURL', '')
            # <<< FIM DA MUDANÇA >>>
            
            post_data.update({
                "timestamp": firestore.SERVER_TIMESTAMP,
                "answerCount": 0,
                "upvoteCount": 0,
            })
            
            new_post_ref = db.collection('posts').add(post_data)
            new_post_id = new_post_ref[1].id
            history_ref.document(new_post_id).set({"createdAt": firestore.SERVER_TIMESTAMP})
            try:
                text_to_embed = f"{post_data.get('title', '')}\n\n{post_data.get('content', '')}".strip()
                if text_to_embed:
                    vector = _run_async_handler_wrapper(
                        community_search_service.generate_embedding_for_post_async(text_to_embed)
                    )
                    metadata_for_pinecone = {
                        "title": post_data.get("title", ""),
                        "category": post_data.get("category", "geral"),
                        "authorName": post_data.get("authorName", ""),
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "content_preview": post_data.get("content", "")[:150]
                    }
                    _run_async_handler_wrapper(
                        community_search_service.upsert_post_to_pinecone_async(new_post_id, vector, metadata_for_pinecone)
                    )
            except Exception as e_pinecone:
                print(f"AVISO: Criação do post {new_post_id} bem-sucedida, mas indexação no Pinecone falhou: {e_pinecone}")
                traceback.print_exc()

            return {"status": "success", "message": "Post criado!", "postId": new_post_id}

    except https_fn.HttpsError as e:
        raise e
    except Exception as e:
        print(f"ERRO em createOrUpdatePost: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro ao salvar o post: {e}")

# <<< NOVA FUNÇÃO PARA EXCLUSÃO >>>
@https_fn.on_call(
    secrets=["pinecone-api-key", "openai-api-key"], # Apenas a chave do pinecone é necessária aqui
    region=options.SupportedRegion.SOUTHAMERICA_EAST1
)
def deletePost(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    user_id = req.auth.uid
    post_id = req.data.get("postId")
    
    if not post_id:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="'postId' é obrigatório.")
        
    try:
        post_ref = db.collection('posts').document(post_id)
        post_doc = post_ref.get()

        if not post_doc.exists:
            # Se o post já não existe, consideramos a operação um sucesso.
            print(f"Tentativa de deletar post {post_id} que não existe mais.")
            return {"status": "success", "message": "Post já foi removido."}
        
        # Verificação de segurança: Apenas o autor pode deletar
        if post_doc.to_dict().get("authorId") != user_id:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.PERMISSION_DENIED, message="Você Não tem permissão para excluir este post.")

        # 1. Deletar o post do Firestore
        post_ref.delete()
        print(f"Post {post_id} deletado do Firestore.")
        
        # 2. Deletar o registro de criação do histórico do usuário
        history_ref = db.collection('users').document(user_id).collection('postCreationHistory').document(post_id)
        history_ref.delete()
        print(f"Registro de criação do post {post_id} deletado do histórico do usuário.")

        # 3. Deletar do Pinecone
        _run_async_handler_wrapper(
            community_search_service.delete_post_from_pinecone_async(post_id)
        )
        
        return {"status": "success", "message": "Post excluído com sucesso."}
        
    except Exception as e:
        print(f"ERRO em deletePost: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro ao excluir o post: {e}")
    
@scheduler_fn.on_schedule(
    schedule="every day 03:00", # Roda todo dia às 3 da manhã
    timezone=scheduler_fn.Timezone("America/Sao_Paulo"),
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512
)
def cleanupOldPosts(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Função agendada para limpar posts antigos que não receberam nenhuma resposta.
    """
    print("Iniciando tarefa de limpeza de posts antigos sem respostas...")
    db = get_db()
    
    try:
        # Calcula o timestamp de 7 dias atrás
        seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
        
        # Cria a query para encontrar os posts a serem deletados
        posts_to_delete_query = db.collection('posts') \
            .where('answerCount', '==', 0) \
            .where('timestamp', '<=', seven_days_ago)
            
        posts_snapshot = posts_to_delete_query.stream()
        
        # Usa um batch para deletar os documentos de forma eficiente
        batch = db.batch()
        deleted_count = 0
        
        for doc in posts_snapshot:
            print(f"Marcando post para exclusão: ID={doc.id}, Título='{doc.to_dict().get('title', '')}'")
            batch.delete(doc.reference)
            deleted_count += 1
            
            # O Pinecone não tem uma API de delete em lote barata/fácil via HTTP.
            # A remoção do índice pode ser feita manualmente ou com scripts mais complexos.
            # Por enquanto, a remoção será apenas do Firestore.

        if deleted_count > 0:
            batch.commit()
            print(f"Limpeza concluída. {deleted_count} post(s) foram excluídos.")
        else:
            print("Nenhum post antigo sem resposta para limpar hoje.")

    except Exception as e:
        print(f"ERRO CRÍTICO durante a limpeza de posts: {e}")
        traceback.print_exc()


# 2. FUNÇÃO PARA VERIFICAR A SENHA
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 
)
def verifyPostPassword(req: https_fn.CallableRequest) -> dict:
    db = get_db()

    post_id = req.data.get("postId")
    password = req.data.get("password")
    
    if not post_id or not password:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="postId e password são obrigatórios.")
        
    try:
        post_doc = db.collection('posts').document(post_id).get()
        if not post_doc.exists:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Post não encontrado.")
            
        post_data = post_doc.to_dict()
        password_hash = post_data.get("passwordHash")
        
        if not password_hash:
            # Se o post não tem hash, consideramos sucesso (talvez a proteção foi removida)
            return {"success": True}

        # Compara a senha enviada com o hash armazenado
        is_correct = check_password_hash(password_hash, password)
        
        return {"success": is_correct}
        
    except Exception as e:
        print(f"ERRO em verifyPostPassword: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro: {e}")

# --- NOVA FUNÇÃO AUXILIAR ESPECÍFICA PARA BUSCAR FRASES NO PINECONE ---
async def _query_pinecone_quotes_async(vector: list[float], top_k: int) -> list[dict]:
    """
    Consulta o índice 'septima-quotes' do Pinecone de forma assíncrona.
    """
    # Reutiliza a inicialização de clientes do serviço de sermões (que é genérica)
    sermons_service._initialize_sermon_clients()
    
    # Pega os clientes inicializados
    httpx_client = sermons_service._httpx_client_sermons
    pinecone_api_key = sermons_service._pinecone_api_key_sermons_loaded

    if not httpx_client or not pinecone_api_key:
        raise ConnectionError("Falha na inicialização dos clientes para consulta ao Pinecone.")

    # !!! ESTA É A MUDANÇA MAIS IMPORTANTE !!!
    # Substitua pelo endpoint EXATO do seu índice de frases 'septima-quotes'
    PINECONE_ENDPOINT_QUOTES = "https://septima-quotes-hqija7a.svc.aped-4627-b74a.pinecone.io" 
    
    request_url = f"{PINECONE_ENDPOINT_QUOTES}/query"
    headers = {
        "Api-Key": pinecone_api_key,
        "Content-Type": "application/json", "Accept": "application/json"
    }
    payload = {
        "vector": vector, "topK": top_k,
        "includeMetadata": True, "includeValues": False
    }
    
    print(f"Consultando Pinecone (Frases) em {request_url}")
    try:
        response = await httpx_client.post(request_url, headers=headers, json=payload)
        response.raise_for_status()
        result_data = response.json()
        return result_data.get("matches", [])
    except httpx.HTTPStatusError as e_http:
        print(f"Erro HTTP ao consultar Pinecone (Frases): Status {e_http.response.status_code}, Corpo: {e_http.response.text}")
        raise ConnectionError(f"Falha na comunicação com Pinecone (Frases).")
    except Exception as e_generic:
        print(f"Erro inesperado durante a consulta ao Pinecone (Frases): {e_generic}")
        raise

@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def getBibTokFeed(req: https_fn.CallableRequest) -> dict:
    """
    (Wrapper Síncrono)
    Busca o feed do BibTok chamando a lógica assíncrona interna.
    """
    # Esta função agora apenas chama o _run_async_handler_wrapper
    # com a função async real e seus parâmetros.
    return _run_async_handler_wrapper(
        _getBibTokFeed_async(req)
    )

async def _getBibTokFeed_async(req: https_fn.CallableRequest) -> dict:
    """
    (Lógica Assíncrona Real)
    Gera um feed de frases (BibTok) para um usuário.
    """
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    user_id = req.auth.uid
    search_type = req.data.get("type", "random")
    try:
        count = int(req.data.get("count", 10))
    except (ValueError, TypeError):
        count = 10
    fetch_count = count * 4

    print(f"BibTok Feed (async) chamada para User: {user_id}, Tipo: {search_type}, Contagem: {count}")

    try:
        query_vector = None
        if search_type == "personalized":
            user_doc = await asyncio.to_thread(db.collection('users').document(user_id).get)
            if user_doc.exists:
                user_data = user_doc.to_dict()
                recent_interactions = user_data.get("recentInteractions", [])
                if recent_interactions:
                    profile_text = " ".join([item.get("text", "") for item in recent_interactions])
                    if profile_text.strip():
                        query_vector = await sermons_service._generate_sermon_embedding_async(profile_text)
                        print("Vetor de perfil gerado com sucesso.")
        
        if query_vector is None:
            print("Gerando vetor aleatório para a busca de frases.")
            query_vector = [random.uniform(-1, 1) for _ in range(1536)]

        pinecone_results = await _query_pinecone_quotes_async(vector=query_vector, top_k=fetch_count)
        
        final_quotes = []
        for match in pinecone_results:
            metadata = match.get("metadata", {})
            if "text" in metadata:
                final_quotes.append({
                    "id": match.get("id"),
                    "text": metadata.get("text"),
                    "author": metadata.get("author"),
                    "book": metadata.get("book"),
                    "score": match.get("score", 0.0),
                })
        
        print(f"Retornando {len(final_quotes)} resultados brutos do Pinecone.")
        return {"quotes": final_quotes}

    except Exception as e:
        print(f"ERRO CRÍTICO em _getBibTokFeed_async para o usuário {user_id}: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao buscar frases: {e}"
        )

@https_fn.on_call(
    secrets=["openai-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def generateForumQuestion(req: https_fn.CallableRequest) -> dict:
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='A função deve ser chamada por um usuário autenticado.'
        )

    user_description = req.data.get("user_description")
    if not user_description or not isinstance(user_description, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'user_description' (string) é obrigatório."
        )

    try:
        from book_search_service import _openai_client_books as openai_client
        if openai_client is None:
            from book_search_service import _initialize_book_clients
            _initialize_book_clients()
            from book_search_service import _openai_client_books as openai_client
    except ImportError:
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno do servidor (módulo de IA indisponível).")

    system_prompt = """
    Você é um assistente teológico especializado em criar perguntas instigantes para um fórum de discussão cristão.
    Sua tarefa é, com base na necessidade do usuário, gerar:
    1. Um 'title': Uma pergunta clara, aberta e convidativa para debate.
    2. Um 'content': Um texto curto de 1 a 2 parágrafos que fornece um contexto neutro para a pergunta, preparando o terreno para a discussão sem tomar um lado.

    Retorne a resposta estritamente no formato JSON: {"title": "Sua pergunta gerada aqui", "content": "Seu conteúdo de contexto aqui"}
    """
    user_prompt = f"Necessidade do usuário: '{user_description}'"

    try:
        print(f"Gerando pergunta para a descrição: {user_description}")
        chat_completion = openai_client.chat.completions.create(
            model="gpt-4.1-nano",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7,
            max_tokens=400,
            response_format={"type": "json_object"}
        )

        # ✅✅✅ CORREÇÃO APLICADA AQUI ✅✅✅
        # A resposta já vem como um dicionário Python, não precisamos mais do json.loads()
        parsed_response = chat_completion.choices[0].message.content
        print(f"Resposta da OpenAI já parseada: {parsed_response}")
        
        # Como a resposta já é um objeto, precisamos parsear de novo para garantir que é um dict
        # antes de retornar, pois o OpenAI pode retornar a string de um dict.
        final_data = json.loads(parsed_response)

        return {"status": "success", "data": final_data}

    except Exception as e:
        print(f"ERRO CRÍTICO em generateForumQuestion: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao gerar a pergunta: {e}"
        )
    
@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def semanticCommunitySearch(request: https_fn.CallableRequest) -> dict:
    """
    Busca semanticamente nos posts da comunidade.
    """
    if not request.auth or not request.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    user_query = request.data.get("query")
    if not user_query:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O parâmetro 'query' é obrigatório.")

    try:
        search_results = _run_async_handler_wrapper(
            community_search_service.perform_community_search_async(user_query)
        )
        return {"results": search_results}
    except Exception as e:
        print(f"Erro em semanticCommunitySearch: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro ao realizar a busca na comunidade.")
    
@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 
)
def submitReplyOrComment(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    current_user_id = req.auth.uid
    post_id = req.data.get("postId")
    content = req.data.get("content")
    
    # Parâmetros opcionais para comentários aninhados (Nível 2)
    parent_reply_id = req.data.get("parentReplyId") 
    replying_to_user_id = req.data.get("replyingToUserId")
    replying_to_user_name = req.data.get("replyingToUserName")

    if not post_id or not content:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="postId e content são obrigatórios.")

    try:
        post_ref = db.collection('posts').document(post_id)
        
        @transactional
        def _add_reply_or_comment_transaction(transaction):
            post_docs = list(transaction.get(post_ref))
            post_doc = post_docs[0] if post_docs else None
            
            if not post_doc or not post_doc.exists:
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="A pergunta original não foi encontrada.")
            
            post_data = post_doc.to_dict()
            original_author_id = post_data.get("authorId")
            is_post_anonymous = post_data.get("isAnonymous", False)

            user_ref = db.collection('users').document(current_user_id)
            user_docs = list(transaction.get(user_ref))
            user_doc = user_docs[0] if user_docs else None
            user_data = user_doc.to_dict() if user_doc and user_doc.exists else {}

            # Monta os dados base do autor
            author_data = {
                'authorId': current_user_id,
                'content': content,
                'timestamp': firestore.SERVER_TIMESTAMP,
            }
            
            # A LÓGICA CENTRAL DO ANONIMATO
            if is_post_anonymous and current_user_id == original_author_id:
                author_data['authorName'] = "Autor Anônimo"
                author_data['authorPhotoUrl'] = ""
            else:
                author_data['authorName'] = user_data.get('nome', 'Anônimo')
                author_data['authorPhotoUrl'] = user_data.get('photoURL', '')
            
            # DECIDE ONDE SALVAR (RESPOSTA NÍVEL 1 ou COMENTÁRIO NÍVEL 2)
            if parent_reply_id:
                # É um comentário aninhado (Nível 2)
                comment_data = {**author_data} # Copia os dados do autor
                comment_data.update({
                    'replyingToUserId': replying_to_user_id,
                    'replyingToUserName': replying_to_user_name,
                })
                
                reply_ref = post_ref.collection('replies').document(parent_reply_id)
                new_comment_ref = reply_ref.collection('comments').document()
                
                transaction.set(new_comment_ref, comment_data)
                transaction.update(reply_ref, {'commentCount': firestore.firestore.Increment(1)})
                
            else:
                # É uma resposta principal (Nível 1)
                reply_data = {**author_data}
                reply_data.update({
                    'upvoteCount': 0,
                    'upvotedBy': [],
                    'commentCount': 0,
                })
                
                new_reply_ref = post_ref.collection('replies').document()
                transaction.set(new_reply_ref, reply_data)
                transaction.update(post_ref, {'answerCount': firestore.firestore.Increment(1)})

        _add_reply_or_comment_transaction(db.transaction())
        return {"status": "success", "message": "Enviado com sucesso!"}

    except Exception as e:
        print(f"ERRO em submitReplyOrComment: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Ocorreu um erro ao enviar: {e}")

@https_fn.on_call(
    secrets=["openai-api-key"], # Garante que a chave da API OpenAI está disponível
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256 # Memória suficiente para esta tarefa
)
def generateCommentarySummary(req: https_fn.CallableRequest) -> dict:
    """
    Recebe o texto de um comentário e gera um resumo estruturado usando a IA.
    """
    # 1. Validação de Autenticação e Parâmetros
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para gerar resumos.'
        )

    context_text = req.data.get("context_text")
    if not context_text or not isinstance(context_text, str) or len(context_text.strip()) < 50:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'context_text' deve ser um texto com pelo menos 50 caracteres."
        )

    print(f"Gerando resumo para o usuário {req.auth.uid}...")

    # 2. Montagem do Prompt (exatamente como você pediu)
    # Colocamos o mapa de abreviações dentro da função para ser auto-contido
    REFERENCE_ABBREVIATIONS_MAP_STRING = """
    Genesis: gn, Exodus: ex, Leviticus: lv, Numbers: nm, Deuteronomy: dt,
    Joshua: js, Judges: jz, Ruth: rt, 1 Samuel: 1sm, 2 Samuel: 2sm,
    1 Kings: 1rs, 2 Kings: 2rs, 1 Chronicles: 1cr, 2 Chronicles: 2cr,
    Ezra: ed, Nehemiah: ne, Esther: et, Job: jó, Psalms: sl, Psalm: sl,
    Proverbs: pv, Ecclesiastes: ec, Song of Solomon: ct, Isaiah: is,
    Jeremiah: jr, Lamentations: lm, Ezekiel: ez, Daniel: dn, Hosea: os,
    Joel: jl, Amos: am, Obadiah: ob, Jonah: jn, Micah: mq, Nahum: na,
    Habakkuk: hc, Zephaniah: sf, Haggai: ag, Zechariah: zc, Malachi: ml,
    Matthew: mt, Mark: mc, Luke: lc, John: jo, Acts: at, Romans: rm,
    1 Corinthians: 1co, 2 Corinthians: 2co, Galatians: gl, Ephesians: ef,
    Philippians: fp, Colossians: cl, 1 Thessalonians: 1ts, 2 Thessalonians: 2ts,
    1 Timothy: 1tm, 2 Timothy: 2tm, Titus: tt, Philemon: fm, Hebrews: hb,
    James: tg, 1 Peter: 1pe, 2 Peter: 2pe, 1 John: 1jo, 2 John: 2jo,
    3 John: 3jo, Jude: jd, Revelation: ap
    """
    
    system_prompt = f"""
Você é um assistente teológico especialista em sintetizar informações. Sua tarefa é resumir o texto fornecido em tópicos e subtópicos, em português, usando o formato Markdown.

# Instruções de Formato
- Use títulos de Nível 3 (###) para os tópicos principais.
- Use negrito (**Texto**) para subtítulos ou conceitos chave.
- Use itálico (_Referência_) para o rótulo da referência bíblica.
- Use abreviações para as referências bíblicas conforme o mapa abaixo. NÃO invente abreviações.

# Mapa de Abreviações de Referência
{REFERENCE_ABBREVIATIONS_MAP_STRING}

# Exemplo de Saída Esperada
### 1. Desejos desordenados por objetos carnais
- **Precaução contra desejos indevidos**
    - _Referência_: 1co 10:6
- **Exemplo do povo de Israel**
    - _Referência_: nm 11:4; sl 106:14
    - Deus lhes deu sustento, porém desejaram carne com indulgência.
- **Advertência**
    - Desejos carnais, quando satisfeitos, originam muitos pecados.

Agora, resuma o seguinte texto:
"""

    # 3. Chamada à API da OpenAI
    try:
        # Reutiliza o cliente inicializado em outro serviço se possível, ou inicializa um novo
        # (A melhor prática é ter um módulo 'ai_services.py' que gerencia o cliente)
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key: raise ValueError("Secret 'openai-api-key' não encontrado.")
        client = OpenAI(api_key=openai_api_key)

        chat_completion = client.chat.completions.create(
            model="gpt-4.1-nano",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": context_text}
            ],
            temperature=0.3, # Baixa temperatura para manter o resumo factual
            max_tokens=1024,
        )

        summary = chat_completion.choices[0].message.content.strip()
        print("Resumo gerado com sucesso.")
        
        return {"status": "success", "summary": summary}

    except Exception as e:
        print(f"ERRO CRÍTICO em generateCommentarySummary: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao gerar o resumo: {e}"
        )
    
@https_fn.on_call(
    secrets=["openai-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def generateSermonSummary(req: https_fn.CallableRequest) -> dict:
    """
    Recebe o texto de um sermão e gera um resumo estruturado usando a IA.
    """
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para gerar resumos.'
        )

    sermon_text = req.data.get("sermon_text")
    if not sermon_text or not isinstance(sermon_text, str) or len(sermon_text.strip()) < 100:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'sermon_text' deve ser um texto com pelo menos 100 caracteres."
        )

    print(f"Gerando resumo de sermão para o usuário {req.auth.uid}...")

    # O prompt é idêntico ao anterior, apenas ajustamos a frase final para ser mais genérica.
    REFERENCE_ABBREVIATIONS_MAP_STRING = """
    Genesis: gn, Exodus: ex, Leviticus: lv, Numbers: nm, Deuteronomy: dt,
    Joshua: js, Judges: jz, Ruth: rt, 1 Samuel: 1sm, 2 Samuel: 2sm,
    1 Kings: 1rs, 2 Kings: 2rs, 1 Chronicles: 1cr, 2 Chronicles: 2cr,
    Ezra: ed, Nehemiah: ne, Esther: et, Job: jó, Psalms: sl, Psalm: sl,
    Proverbs: pv, Ecclesiastes: ec, Song of Solomon: ct, Isaiah: is,
    Jeremiah: jr, Lamentations: lm, Ezekiel: ez, Daniel: dn, Hosea: os,
    Joel: jl, Amos: am, Obadiah: ob, Jonah: jn, Micah: mq, Nahum: na,
    Habakkuk: hc, Zephaniah: sf, Haggai: ag, Zechariah: zc, Malachi: ml,
    Matthew: mt, Mark: mc, Luke: lc, John: jo, Acts: at, Romans: rm,
    1 Corinthians: 1co, 2 Corinthians: 2co, Galatians: gl, Ephesians: ef,
    Philippians: fp, Colossians: cl, 1 Thessalonians: 1ts, 2 Thessalonians: 2ts,
    1 Timothy: 1tm, 2 Timothy: 2tm, Titus: tt, Philemon: fm, Hebrews: hb,
    James: tg, 1 Peter: 1pe, 2 Peter: 2pe, 1 John: 1jo, 2 John: 2jo,
    3 John: 3jo, Jude: jd, Revelation: ap
    """
    
    system_prompt = f"""
Você é um assistente teológico especialista em sintetizar informações. Sua tarefa é resumir o texto fornecido em tópicos e subtópicos, em português, usando o formato Markdown.

# Instruções de Formato
- Use títulos de Nível 3 (###) para os tópicos principais.
- Use negrito (**Texto**) para subtítulos ou conceitos chave.
- Use itálico (_Referência_) para o rótulo da referência bíblica.
- Use abreviações para as referências bíblicas conforme o mapa abaixo. NÃO invente abreviações.

# Mapa de Abreviações de Referência
{REFERENCE_ABBREVIATIONS_MAP_STRING}

# Exemplo de Saída Esperada
### 1. Desejos desordenados por objetos carnais
- **Precaução contra desejos indevidos**
    - _Referência_: 1co 10:6
- **Exemplo do povo de Israel**
    - _Referência_: nm 11:4; sl 106:14
    - Deus lhes deu sustento, porém desejaram carne com indulgência.
- **Advertência**
    - Desejos carnais, quando satisfeitos, originam muitos pecados.

Agora, resuma o seguinte sermão:
"""
    
    try:
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key: raise ValueError("Secret 'openai-api-key' não encontrado.")
        client = OpenAI(api_key=openai_api_key)

        chat_completion = client.chat.completions.create(
            model="gpt-4.1-nano",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": sermon_text}
            ],
            temperature=0.3,
            max_tokens=1024,
        )

        summary = chat_completion.choices[0].message.content.strip()
        print("Resumo de sermão gerado com sucesso.")
        
        return {"status": "success", "summary": summary}

    except Exception as e:
        print(f"ERRO CRÍTICO em generateSermonSummary: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao gerar o resumo do sermão: {e}"
        )

@https_fn.on_call(
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_256
)
def processReferralById(req: https_fn.CallableRequest) -> dict:
    """
    Processa um pedido de indicação baseado no Septima ID (username#discriminator).
    Recompensa ambos os usuários com pontos de ranking (rawReadingTime).
    """
    db = get_db()

    # 1. Validações Iniciais (sem alterações)
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para usar um código de indicação.'
        )
    # ... (o resto das suas validações de input permanecem as mesmas)
    new_user_id = req.auth.uid
    septima_id_input = req.data.get("septimaId")
    if not septima_id_input or "#" not in septima_id_input:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O ID Septima fornecido é inválido.")
    
    try:
        username, discriminator = septima_id_input.strip().split('#', 1)
    except ValueError:
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O formato do ID Septima é inválido.")

    # 2. Busca o usuário "indicante" (sem alterações)
    referrer_query = db.collection('users').where('username', '==', username.lower()).where('discriminator', '==', discriminator).limit(1)
    referrer_docs = list(referrer_query.stream())
    if not referrer_docs:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Não encontramos um usuário com este ID Septima.")
    
    referrer_doc = referrer_docs[0]
    referrer_id = referrer_doc.id
    if referrer_id == new_user_id:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Você não pode indicar a si mesmo.")

    # 3. Transação Atômica (LÓGICA PRINCIPAL ALTERADA)
    try:
        @firestore.transactional
        def _referral_transaction(transaction):
            new_user_ref = db.collection('users').document(new_user_id)
            new_user_snapshot = new_user_ref.get(transaction=transaction)
            if not new_user_snapshot.exists:
                raise Exception("Ocorreu um erro, seu perfil não foi encontrado.")
            if new_user_snapshot.to_dict().get("hasBeenReferred"):
                raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.ALREADY_EXISTS, message="Você já utilizou um código de indicação.")

            # <<< MUDANÇA AQUI: Definição dos pontos de ranking >>>
            reward_points = 1000

            # --- Atualiza o novo usuário ---
            transaction.update(new_user_ref, {
                "referredBy": referrer_id,
                "hasBeenReferred": True,
            })
            
            # <<< MUDANÇA AQUI: Alvo agora é a coleção 'userBibleProgress' >>>
            new_user_progress_ref = db.collection('userBibleProgress').document(new_user_id)
            transaction.set(new_user_progress_ref, {
                "rawReadingTime": firestore.Increment(reward_points)
            }, merge=True) # Usa 'set' com 'merge=True' para criar o doc se não existir

            # --- Atualiza o usuário que indicou ---
            referrer_progress_ref = db.collection('userBibleProgress').document(referrer_id)
            transaction.set(referrer_progress_ref, {
                "rawReadingTime": firestore.Increment(reward_points)
            }, merge=True)

            return {
                "referrer_name": referrer_doc.to_dict().get("nome", "Um amigo"),
                "new_user_name": new_user_snapshot.to_dict().get("nome", "Um novo usuário")
            }

        user_names = _referral_transaction(db.transaction())
        referrer_name = user_names["referrer_name"]
        new_user_name = user_names["new_user_name"]
        reward_points = 1000

        # 4. Enviar Notificações (MENSAGEM ALTERADA)
        
        # A. Notificação para quem INDICOU
        referrer_notifications_ref = db.collection('users').document(referrer_id).collection('notifications')
        referrer_notifications_ref.add({
            "type": "referral_success_referrer",
            "title": "Você ganhou pontos no ranking!", # <<< MUDANÇA
            "body": f"{new_user_name} usou seu código! Ambos ganharam {reward_points} pontos para o ranking semanal.", # <<< MUDANÇA
            "timestamp": firestore.SERVER_TIMESTAMP,
            "isRead": False
        })
        
        # B. Notificação para quem FOI INDICADO
        new_user_notifications_ref = db.collection('users').document(new_user_id).collection('notifications')
        new_user_notifications_ref.add({
            "type": "referral_success_new_user",
            "title": "Bônus de Ranking Recebido!", # <<< MUDANÇA
            "body": f"Seu código de {referrer_name} foi validado! Você ganhou {reward_points} pontos de bônus.", # <<< MUDANÇA
            "timestamp": firestore.SERVER_TIMESTAMP,
            "isRead": False
        })
        
        # 5. Retorno Final (MENSAGEM ALTERADA)
        return {"status": "success", "message": f"Código validado! Você e {referrer_name} ganharam {reward_points} pontos no ranking!"}

    except https_fn.HttpsError as e:
        raise e
    except Exception as e:
        print(f"ERRO CRÍTICO em processReferralById: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro inesperado ao processar a indicação: {e}"
        )

################## Stripe ####################

@https_fn.on_call(
    secrets=["STRIPE_SECRET_KEY"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512 
)
def createStripeCheckoutSession(req: https_fn.CallableRequest) -> dict:
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    db = get_db()

    user_id = req.auth.uid
    price_id = req.data.get("priceId") # Continuamos recebendo o priceId

    if not price_id:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="O 'priceId' do plano é obrigatório.")

    try:
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        user_data = user_doc.to_dict() or {}
        
        customer_id = user_data.get("stripeCustomerId")

        if not customer_id:
            customer = stripe.Customer.create(
                email=user_data.get("email"),
                name=user_data.get("nome"),
                metadata={'firebaseUID': user_id}
            )
            customer_id = customer.id
            user_ref.set({'stripeCustomerId': customer_id}, merge=True)
            print(f"Novo cliente Stripe criado para o usuário {user_id}: {customer_id}")

        # <<< INÍCIO DA MUDANÇA PRINCIPAL >>>

        # Em vez de criar uma Checkout Session, criamos uma Assinatura diretamente.
        # Isso nos dará um SetupIntent ou PaymentIntent com um client_secret garantido.
        subscription = stripe.Subscription.create(
            customer=customer_id,
            items=[{'price': price_id}],
            payment_behavior='default_incomplete', # Permite pagamentos que precisam de ação do usuário
            payment_settings={'save_default_payment_method': 'on_subscription'},
            expand=['latest_invoice.payment_intent', 'pending_setup_intent'], # Pede para a Stripe incluir os objetos que precisamos
        )

        print(f"Assinatura em estado 'incomplete' criada para {user_id}. ID: {subscription.id}")

        client_secret = None
        
        # A Stripe pode retornar um 'pending_setup_intent' (para configurar o método de pagamento)
        # ou um 'payment_intent' (se o primeiro pagamento precisar ser feito imediatamente).
        if subscription.pending_setup_intent:
            client_secret = subscription.pending_setup_intent.client_secret
            print(f"Encontrado client_secret no 'pending_setup_intent'.")
        elif subscription.latest_invoice and subscription.latest_invoice.payment_intent:
            client_secret = subscription.latest_invoice.payment_intent.client_secret
            print(f"Encontrado client_secret no 'payment_intent' da primeira fatura.")
            
        if not client_secret:
            raise Exception("Não foi possível obter o client_secret da assinatura criada.")

        # <<< FIM DA MUDANÇA PRINCIPAL >>>

        return {
            "clientSecret": client_secret,
            "customerId": customer_id
        }

    except Exception as e:
        print(f"ERRO CRÍTICO em createStripeCheckoutSession: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro ao criar sessão de pagamento: {e}")

# ==============================================================================
# 2. FUNÇÃO WEBHOOK (CHAMADA PELA STRIPE)
# ==============================================================================
# Crie um novo secret para o webhook
# No terminal: firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Cole o "Segredo do endpoint" que a Stripe te dará no painel de webhooks.

@https_fn.on_request(
    secrets=["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512
)
def stripeWebhook(req: https_fn.Request) -> https_fn.Response:
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    endpoint_secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
    payload = req.data
    sig_header = req.headers.get('stripe-signature')

    try:
        event = stripe.Webhook.construct_event(
            payload=payload, sig_header=sig_header, secret=endpoint_secret
        )
    except Exception as e:
        print(f"Webhook error: {e}")
        return https_fn.Response(status=400)

    event_type = event['type']
    data_object = event['data']['object']
    db = get_db()

    print(f"Webhook recebido: {event_type}")

    # --- LÓGICA PRINCIPAL CORRIGIDA AQUI ---

    # <<< MUDANÇA AQUI: Agora escuta 'invoice.payment_succeeded' OU 'invoice.paid' >>>
    if event_type == 'invoice.payment_succeeded' or event_type == 'invoice.paid':
        
        print(f"Processando evento '{event_type}' para ativação/renovação...")
        
        customer_id = data_object.get('customer')
        subscription_id = data_object.get('subscription')

        if not customer_id or not subscription_id:
            print(f"Webhook '{event_type}' sem customer_id ou subscription_id. Ignorando.")
            return https_fn.Response(status=200)

        try:
            subscription = stripe.Subscription.retrieve(subscription_id)
            end_date = datetime.fromtimestamp(subscription.current_period_end, tz=timezone.utc)
            
            users_query = db.collection('users').where('stripeCustomerId', '==', customer_id).limit(1)
            user_docs = list(users_query.stream())

            if user_docs:
                user_id = user_docs[0].id
                
                update_data = {
                    'stripeSubscriptionId': subscription_id,
                    'subscriptionStatus': 'active',
                    'activePriceId': subscription.plan.id,
                    'subscriptionEndDate': end_date,
                    'lastPurchaseToken': None
                }
                
                db.collection('users').document(user_id).set(update_data, merge=True)
                print(f"Assinatura ATIVADA/RENOVADA para o usuário {user_id}. Válida até {end_date}.")
            else:
                print(f"AVISO: '{event_type}' recebido para o cliente Stripe {customer_id}, mas nenhum usuário correspondente foi encontrado.")

        except Exception as e:
            print(f"ERRO ao processar '{event_type}': {e}")
            return https_fn.Response(status=500)

    elif event_type == 'customer.subscription.deleted':
        # Esta parte para o cancelamento já está correta
        customer_id = data_object.get('customer')
        if customer_id:
            users_query = db.collection('users').where('stripeCustomerId', '==', customer_id).limit(1)
            user_docs = list(users_query.stream())
            if user_docs:
                user_id = user_docs[0].id
                db.collection('users').document(user_id).update({
                    'subscriptionStatus': 'inactive',
                    'stripeSubscriptionId': None,
                    'activePriceId': None,
                    'subscriptionEndDate': None
                })
                print(f"Assinatura DESATIVADA para o usuário {user_id}.")

    return https_fn.Response(status=200)

@https_fn.on_call(
    secrets=["STRIPE_SECRET_KEY"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1
)
def createStripePortalSession(req: https_fn.CallableRequest) -> dict:
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    db = get_db()
    user_id = req.auth.uid

    try:
        user_doc = db.collection('users').document(user_id).get()
        customer_id = user_doc.to_dict().get("stripeCustomerId")

        if not customer_id:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Nenhum cliente de pagamento encontrado para este usuário.")

        # URL de retorno para onde o usuário voltará após gerenciar a assinatura
        return_url = 'https://septimahome.com/perfil' # ou a URL do seu app

        portal_session = stripe.billing_portal.Session.create(
            customer=customer_id,
            return_url=return_url,
        )
        
        print(f"Sessão do Portal do Cliente criada para {user_id}.")
        return {"url": portal_session.url}

    except Exception as e:
        print(f"ERRO CRÍTICO em createStripePortalSession: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f"Erro ao criar sessão do portal: {e}")
    
    # ==============================================================================
# 1. FUNÇÃO PARA CRIAR O PAGAMENTO PIX
# ==============================================================================
@https_fn.on_call(
    secrets=["MERCADO_PAGO_ACCESS_TOKEN"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1
)
def createMercadoPagoPix(req: https_fn.CallableRequest) -> dict:
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    user_id = req.auth.uid
    db = get_db()
    
    device_id = req.data.get("deviceId")
    print(f"Device ID recebido do cliente: {device_id}")

    amount = 19.90
    item_id = "premium_monthly_pix_01"
    item_title = "Septima Premium - 1 Mês"
    item_description = "Acesso completo por 31 dias ao Septima Bíblia Premium"
    access_duration_days = 31

    try:
        sdk = mercadopago.SDK(os.environ.get("MERCADO_PAGO_ACCESS_TOKEN"))
        
        user_doc = db.collection('users').document(user_id).get()
        if not user_doc.exists:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Usuário não encontrado.")
        
        user_data = user_doc.to_dict()
        user_email = user_data.get("email")
        full_name = user_data.get("nome", "Usuário Septima")
        
        name_parts = full_name.split(" ", 1)
        first_name = name_parts[0]
        last_name = name_parts[1] if len(name_parts) > 1 else " "

        if not user_email:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message="O usuário não possui um e-mail verificado.")

        webhook_url = "https://southamerica-east1-resumo-livros.cloudfunctions.net/mercadoPagoWebhook"

        payment_data = {
            "transaction_amount": amount,
            "description": item_description,
            "payment_method_id": "pix",
            "external_reference": user_id,
            "notification_url": webhook_url,
            "statement_descriptor": "SEPTIMA BIBLIA",
            "metadata": { "firebaseUID": user_id, "access_duration_days": access_duration_days },
            "payer": {
                "email": user_email,
                "first_name": first_name,
                "last_name": last_name,
                "entity_type": "individual"
            },
            "additional_info": {
                "items": [
                    {
                        "id": item_id,
                        "title": item_title,
                        "description": item_description,
                        "category_id": "services",
                        "quantity": 1,
                        "unit_price": amount
                    }
                ]
            }
        }
        
        # --- INÍCIO DA CORREÇÃO FINAL ---
        
        request_options = None
        if device_id:
            # 2. Cria uma instância da classe RequestOptions
            request_options = RequestOptions()
            # 3. Adiciona os headers customizados a ela
            request_options.custom_headers = {
                'X-meli-session-id': device_id
            }
            print(f"Opções de requisição customizadas criadas com header 'X-meli-session-id'.")

        # --- FIM DA CORREÇÃO FINAL ---
        
        # 4. Passa o objeto RequestOptions para a chamada de criação
        payment_response = sdk.payment().create(payment_data, request_options)
        
        if payment_response["status"] == 201:
            payment = payment_response["response"]
            qr_code_base64 = payment['point_of_interaction']['transaction_data']['qr_code_base64']
            qr_code_copia_e_cola = payment['point_of_interaction']['transaction_data']['qr_code']
            
            print(f"Pagamento PIX de 1 mês criado para usuário {user_id}.")

            return {
                "qr_code_base64": qr_code_base64,
                "qr_code_copia_e_cola": qr_code_copia_e_cola
            }
        else:
            print(f"ERRO da API do Mercado Pago (Payment). Status: {payment_response['status']}. Resposta: {payment_response['response']}")
            error_desc = payment_response['response'].get('cause', [{}])[0].get('description', 'Erro desconhecido')
            raise Exception(f"Não foi possível gerar o código PIX: {error_desc}")

    except Exception as e:
        print(f"ERRO CRÍTICO em createMercadoPagoPix: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=str(e))


# ==============================================================================
# 2. FUNÇÃO WEBHOOK (COM DURAÇÃO CORRIGIDA)
# ==============================================================================
@https_fn.on_request(
    secrets=["MERCADO_PAGO_ACCESS_TOKEN", "STRIPE_SECRET_KEY"], # Adicionei stripe p/ n dar erro
    region=options.SupportedRegion.SOUTHAMERICA_EAST1
)
def mercadoPagoWebhook(req: https_fn.Request) -> https_fn.Response:
    db = get_db()
    sdk = mercadopago.SDK(os.environ.get("MERCADO_PAGO_ACCESS_TOKEN"))

    # <<< INÍCIO DA CORREÇÃO >>>
    
    payment_id = None
    topic = None

    # O Mercado Pago pode enviar dados como query params (GET) ou no corpo (POST)
    if req.method == 'POST':
        # Para POST, os dados estão no corpo. O curl envia como 'form'.
        # O webhook real do MP envia como JSON, então verificamos ambos.
        if req.form:
            payment_id = req.form.get("id")
            topic = req.form.get("topic")
        elif req.json:
            data = req.json.get("data", {})
            payment_id = data.get("id")
            topic = req.json.get("type") # O webhook real usa 'type' para o evento
            if topic == 'payment': # Ajuste para o webhook real
                topic = 'payment'
    elif req.method == 'GET':
        payment_id = req.args.get("id")
        topic = req.args.get("topic")
        
    print(f"Webhook recebido. Método: {req.method}, Topic: {topic}, ID: {payment_id}")

    # Verifica se o evento é o que nos interessa ('payment')
    if topic == "payment" and payment_id:
    # <<< FIM DA CORREÇÃO >>>

        print(f"Processando notificação para o pagamento: {payment_id}")

        try:
            payment_info = sdk.payment().get(payment_id)
            if payment_info["status"] == 200:
                payment = payment_info["response"]
                
                if payment['status'] == 'approved':
                    user_id = payment.get("external_reference")
                    metadata = payment.get("metadata", {})
                    access_duration_days = metadata.get("access_duration_days", 31)

                    if user_id:
                        end_date = datetime.now(timezone.utc) + timedelta(days=access_duration_days)
                        
                        db.collection('users').document(user_id).set({
                            'subscriptionStatus': 'active',
                            'subscriptionEndDate': end_date,
                            'activePriceId': 'pix_1_month',
                            'lastPurchaseMethod': 'mercadopago_pix'
                        }, merge=True)
                        print(f"Acesso Premium (PIX 1 Mês) ATIVADO para o usuário {user_id}. Válido até {end_date}.")
        
        except Exception as e:
            print(f"Erro ao processar webhook do Mercado Pago: {e}")
            return https_fn.Response(status=500)

    # Se o tópico não for 'payment' ou se faltar o ID, apenas confirme o recebimento.
    return https_fn.Response(status=200)
