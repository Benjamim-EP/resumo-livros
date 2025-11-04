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
#from google.cloud.firestore import Timestamp
#from google.cloud import firestore_v1
from google.protobuf.timestamp_pb2 import Timestamp
from google.cloud.firestore_v1.field_path import FieldPath


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


cors_options = options.CorsOptions(
    cors_origins=["*"],  # <<< MUDE PARA APENAS ESTA LINHA
    cors_methods=["get", "post"])

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

ABBREV_TO_FULL_NAME_MAP = {
    "gn": "Gênesis", "ex": "Êxodo", "lv": "Levítico", "nm": "Números", "dt": "Deuteronômio",
    "js": "Josué", "jz": "Juízes", "rt": "Rute", "1sm": "1 Samuel", "2sm": "2 Samuel",
    "1rs": "1 Reis", "2rs": "2 Reis", "1cr": "1 Crônicas", "2cr": "2 Crônicas",
    "ed": "Esdras", "ne": "Neemias", "et": "Ester", "job": "Jó", "sl": "Salmos",
    "pv": "Provérbios", "ec": "Eclesiastes", "ct": "Cantares de Salomão", "is": "Isaías",
    "jr": "Jeremias", "lm": "Lamentações", "ez": "Ezequiel", "dn": "Daniel",
    "os": "Oseias", "jl": "Joel", "am": "Amós", "ob": "Obadias", "jn": "Jonas",
    "mq": "Miqueias", "na": "Naum", "hc": "Habacuque", "sf": "Sofonias",
    "ag": "Ageu", "zc": "Zacarias", "ml": "Malaquias", "mt": "Mateus", "mc": "Marcos",
    "lc": "Lucas", "jo": "João", "at": "Atos", "rm": "Romanos", "1co": "1 Coríntios",
    "2co": "2 Coríntios", "gl": "Gálatas", "ef": "Efésios", "fp": "Filipenses",
    "cl": "Colossenses", "1ts": "1 Tessalonicenses", "2ts": "2 Tessalonicenses",
    "1tm": "1 Timóteo", "2tm": "2 Timóteo", "tt": "Tito", "fm": "Filemom",
    "hb": "Hebreus", "tg": "Tiago", "1pe": "1 Pedro", "2pe": "2 Pedro",
    "1jo": "1 João", "2jo": "2 João", "3jo": "3 João", "jd": "Judas", "ap": "Apocalipse"
}


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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    timeout_sec=60,
    cors=cors_options
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
    timeout_sec=60,
    cors=cors_options
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
    timeout_sec=300,
    cors=cors_options
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
    timeout_sec=120,
    cors=cors_options
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
                elif isinstance(subscription_end_date, firestore_v1.types.Timestamp):
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
                elif isinstance(reward_expiration_raw, firestore_v1.types.Timestamp):
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
    timeout_sec=120,
    cors=cors_options
)
def chatWithBibleSection(request: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    # 1. Validação
    if not request.auth or not request.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Você precisa estar logado para usar o chat.')
    
    user_id = request.auth.uid
    data = request.data
    user_query = data.get("query")
    chat_history = data.get("history")
    book_abbrev = data.get("bookAbbrev")
    chapter_number_raw = data.get("chapterNumber")
    verses_range_str = data.get("versesRangeStr")
    use_strongs = data.get("useStrongsKnowledge", False)

    # Conversão de capítulo
    chapter_number = 0
    if isinstance(chapter_number_raw, dict) and 'value' in chapter_number_raw:
        try:
            chapter_number = int(chapter_number_raw['value'])
        except (ValueError, TypeError):
             raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Valor de 'chapterNumber' inválido.")
    elif isinstance(chapter_number_raw, int):
        chapter_number = chapter_number_raw

    if not all([user_query, book_abbrev, chapter_number > 0, verses_range_str]):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Parâmetros essenciais da seção bíblica estão faltando ou são inválidos.")

    print(f"Handler chatWithBibleSection chamado por User ID: {user_id} para {book_abbrev} {chapter_number}:{verses_range_str}")
    
    try:
        # 2. Lógica de custo
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Dados do usuário não encontrados.")
        
        user_data = user_doc.to_dict()
        subscription_status = user_data.get('subscriptionStatus', 'inactive')
        
        is_premium = False
        if subscription_status == 'active':
            subscription_end_date = user_data.get('subscriptionEndDate')
            if subscription_end_date and isinstance(subscription_end_date, Timestamp):  # ✅ Corrigido
                end_date_aware = subscription_end_date.to_datetime().replace(tzinfo=timezone.utc)
                if end_date_aware > datetime.now(timezone.utc):
                    is_premium = True

        if use_strongs and not is_premium:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="A análise etimológica é um recurso Premium."
            )
        
        if not is_premium:
            print(f"Usuário {user_id} não é Premium. Verificando moedas.")
            
            reward_coins = user_data.get('weeklyRewardCoins', 0)
            reward_expiration = user_data.get('rewardExpiration')
            
            has_valid_reward = False
            if reward_expiration and isinstance(reward_expiration, Timestamp):  # ✅ Corrigido
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
        else:
            print(f"Usuário {user_id} é Premium. Chat da Bíblia gratuito.")
        
        # 3. Execução da lógica principal
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
    memory=options.MemoryOption.MB_512,
    cors=cors_options
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
            'lifetimeReadingTime': firestore.Increment(seconds_to_add),
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
        
        user_ids_in_ranking = [doc.id for doc in weekly_ranking_docs]
        users_ref = db.collection('users')
        
        # =================================================================
        # <<< INÍCIO DA CORREÇÃO: Lógica de Chunking >>>
        # =================================================================
        
        # Dicionário para armazenar os documentos de usuário encontrados
        user_docs_map = {}
        chunk_size = 30 # O limite do Firestore
        
        print(f"Buscando detalhes de {len(user_ids_in_ranking)} usuários em lotes de {chunk_size}...")
        
        # Itera sobre a lista de IDs em pedaços de 30
        for i in range(0, len(user_ids_in_ranking), chunk_size):
            chunk_of_ids = user_ids_in_ranking[i:i + chunk_size]
            
            # Executa a consulta 'whereIn' apenas para o pedaço atual
            chunk_query = users_ref.where(FieldPath.document_id(), 'in', chunk_of_ids).stream()
            
            # Adiciona os documentos encontrados ao nosso mapa
            for user_doc in chunk_query:
                user_docs_map[user_doc.id] = user_doc
        
        print(f"Verificação de existência concluída. {len(user_docs_map)} usuários válidos encontrados na coleção 'users'.")
        
        # =================================================================
        # <<< FIM DA CORREÇÃO >>>
        # =================================================================

        batch = db.batch()
        now = datetime.now(timezone.utc)
        expiration_date = now + timedelta(days=7)

        for i, progress_doc in enumerate(weekly_ranking_docs):
            rank = i + 1
            user_id = progress_doc.id

            # Agora, em vez de verificar um set, verificamos se o ID está no nosso mapa
            if user_id in user_docs_map:
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
                print(f"AVISO: O usuário {user_id} (Rank {rank}) existe em 'userBibleProgress', mas não na coleção 'users'. A atualização foi pulada.")
        
        batch.commit()
        print("Recompensas e posições anteriores ('previousRank') salvas com sucesso para usuários válidos.")

        # --- ETAPA 2: Resetar o tempo de leitura (sem alterações) ---
        
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
    timeout_sec=90,
    cors=cors_options
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
    secrets=["play-store-service-account-key"],
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options

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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    # --- INÍCIO DA CORREÇÃO ---
    
    # Inicializa apenas para garantir que as chaves de API sejam carregadas.
    # Não usaremos mais o cliente httpx global daqui.
    sermons_service._initialize_sermon_clients()
    pinecone_api_key = sermons_service._pinecone_api_key_sermons_loaded

    if not pinecone_api_key:
        raise ConnectionError("Falha ao carregar configuração da API Pinecone.")

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
    
    # Cria o cliente HTTPX localmente dentro do escopo da função async
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(request_url, headers=headers, json=payload)
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
    timeout_sec=60,
    cors=cors_options
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
    (Lógica Assíncrona Real - VERSÃO ATUALIZADA)
    Gera um feed de frases (BibTok) para um usuário, retornando listas separadas
    para personalizadas e aleatórias.
    """
    db = get_db()
    
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')

    user_id = req.auth.uid
    
    # O frontend agora sempre pedirá ambos, então removemos o 'type'.
    # O 'count' agora é o número de cada tipo que queremos.
    try:
        count = int(req.data.get("count", 10))
    except (ValueError, TypeError):
        count = 10
        
    fetch_count = count * 4 # Busca 4x mais para ter margem de filtragem no cliente

    print(f"BibTok Feed (async) chamada para User: {user_id}, Contagem por tipo: {count}")

    try:
        # --- BUSCA PERSONALIZADA ---
        personalized_quotes = []
        user_doc = await asyncio.to_thread(db.collection('users').document(user_id).get)
        if user_doc.exists:
            user_data = user_doc.to_dict()
            recent_interactions = user_data.get("recentInteractions", [])
            if recent_interactions:
                profile_text = " ".join([item.get("text", "") for item in recent_interactions])
                if profile_text.strip():
                    query_vector_personalized = await sermons_service._generate_sermon_embedding_async(profile_text)
                    print("Vetor de perfil gerado com sucesso.")
                    
                    personalized_results = await _query_pinecone_quotes_async(vector=query_vector_personalized, top_k=fetch_count)
                    
                    for match in personalized_results:
                        metadata = match.get("metadata", {})
                        if "text" in metadata:
                            personalized_quotes.append({
                                "id": match.get("id"),
                                "text": metadata.get("text"),
                                "author": metadata.get("author"),
                                "book": metadata.get("book"),
                                "score": match.get("score", 0.0),
                            })

        # --- BUSCA ALEATÓRIA ---
        random_quotes = []
        query_vector_random = [random.uniform(-1, 1) for _ in range(1536)]
        print("Gerando vetor aleatório para a busca de frases.")
        
        random_results = await _query_pinecone_quotes_async(vector=query_vector_random, top_k=fetch_count)

        for match in random_results:
            metadata = match.get("metadata", {})
            if "text" in metadata:
                random_quotes.append({
                    "id": match.get("id"),
                    "text": metadata.get("text"),
                    "author": metadata.get("author"),
                    "book": metadata.get("book"),
                    "score": match.get("score", 0.0),
                })
        
        print(f"Retornando {len(personalized_quotes)} frases personalizadas e {len(random_quotes)} frases aleatórias.")
        
        # <<< A MUDANÇA PRINCIPAL ESTÁ AQUI >>>
        # Retorna um objeto com duas chaves, em vez de uma única lista.
        return {
            "personalized_quotes": personalized_quotes,
            "random_quotes": random_quotes
        }

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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    timeout_sec=60,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    memory=options.MemoryOption.MB_512,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    memory=options.MemoryOption.MB_256,
    cors=cors_options
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
    memory=options.MemoryOption.MB_512 ,
    cors=cors_options
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
    memory=options.MemoryOption.MB_512,
    cors=cors_options
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
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    cors=cors_options
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
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    cors=cors_options
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
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    cors=cors_options
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


@https_fn.on_call(
    secrets=["openai-api-key"], # Garante que a chave da API OpenAI está disponível
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    cors=cors_options
)
def recommendLibraryBooks(req: https_fn.CallableRequest) -> dict:
    """
    Recomenda livros da biblioteca. Funciona em dois modos:
    1. MODO BUSCA (Explícito): Se 'user_query' for fornecido no request,
       a IA busca livros que correspondam àquela necessidade específica.
    2. MODO RECOMENDAÇÃO (Implícito): Se 'user_query' for omitido,
       a IA usa as interações recentes do usuário ('recentInteractions' no Firestore)
       para gerar recomendações proativas e personalizadas.
    """
    db = get_db()
    
    # 1. Validação de Autenticação
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para usar este recurso.'
        )

    user_id = req.auth.uid
    user_query = req.data.get("user_query")

    # 2. Determinação do Texto Base para Recomendação
    recommendation_base_text = ""
    
    if user_query and isinstance(user_query, str) and user_query.strip():
        # --- MODO BUSCA ---
        print(f"Executando recommendLibraryBooks em modo de BUSCA para a query: '{user_query}'")
        recommendation_base_text = user_query.strip()
    else:
        # --- MODO RECOMENDAÇÃO AUTOMÁTICA ---
        print(f"Executando recommendLibraryBooks em modo de RECOMENDAÇÃO para o usuário {user_id}")
        try:
            user_doc = db.collection('users').document(user_id).get()
            if user_doc.exists:
                user_data = user_doc.to_dict()
                recent_interactions = user_data.get("recentInteractions", [])
                
                if recent_interactions:
                    # Concatena o texto das 7 interações mais recentes
                    interaction_texts = [item.get("text", "") for item in recent_interactions]
                    recommendation_base_text = ". ".join(filter(None, interaction_texts))
                    print(f"Texto base (interações): '{recommendation_base_text[:150]}...'")
                else:
                    print(f"Usuário {user_id} não possui interações recentes. Nenhuma recomendação será gerada.")
                    return {"status": "success", "recommendations": []}
            else:
                 raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Usuário não encontrado.")
        except Exception as e:
            print(f"Erro ao buscar interações do usuário {user_id}: {e}")
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro ao buscar seu histórico.")

    # Se, após toda a lógica, não houver texto base, retorna uma lista vazia.
    if not recommendation_base_text:
        return {"status": "success", "recommendations": []}

    # 3. Lista da Biblioteca (Fonte de Dados para a IA)
    library_items_json = """
    [
        {"bookId": "o-peregrino-oxford-world-s-classics", "title": "O Peregrino", "author": "John Bunyan", "description": "A jornada alegórica de Cristão da Cidade da Destruição à Cidade Celestial."},
        {"bookId": "a-divina-comedia", "title": "A Divina Comédia", "author": "Dante Alighieri", "description": "Uma jornada épica através do Inferno, Purgatório e Paraíso, explorando a teologia e a moralidade medieval."},
        {"bookId": "ben-hur", "title": "Ben-Hur: Uma História de Cristo", "author": "Lew Wallace", "description": "A épica história de um nobre judeu que, após ser traído, encontra redenção e fé durante a época de Jesus Cristo."},
        {"bookId": "elogio-da-loucura", "title": "Elogio da Loucura", "author": "Desiderius Erasmus", "description": "Uma sátira espirituosa da sociedade, costumes e religião do século XVI, narrada pela própria Loucura."},
        {"bookId": "anna-karenina", "title": "Anna Karenina", "author": "Leo Tolstoy", "description": "Um retrato complexo da sociedade russa e das paixões humanas através da história de uma mulher que desafia as convenções."},
        {"bookId": "lilith", "title": "Lilith", "author": "George MacDonald", "description": "Uma fantasia sombria e alegórica sobre a vida, a morte e a redenção, explorando temas de egoísmo e sacrifício."},
        {"bookId": "donal-grantchapters", "title": "Donal Grant", "author": "George MacDonald", "description": "A história de um jovem poeta e tutor que navega pelos desafios do amor, fé e mistério em um castelo escocês."},
        {"bookId": "david-elginbrod", "title": "David Elginbrod", "author": "George MacDonald", "description": "Um romance que explora a fé, o espiritismo e a natureza do bem e do mal através de seus personagens memoráveis."},
        {"bookId": "gravidade-e-graca", "title": "Gravidade e Graça", "author": "Simone Weil", "description": "Reflexões filosóficas sobre a condição humana, o sofrimento, e a busca pela graça divina em meio à 'gravidade' do mundo."},
        {"bookId": "o-enraizamento", "title": "O Enraizamento", "author": "Simone Weil", "description": "Um ensaio sobre as necessidades da alma humana e a importância de ter raízes espirituais, culturais e sociais."},
        {"bookId": "ortodoxia", "title": "Ortodoxia", "author": "G.K. Chesterton", "description": "A jornada intelectual do autor, defendendo a lógica e a alegria da fé cristã tradicional como uma aventura emocionante."},
        {"bookId": "hereges", "title": "Hereges", "author": "G.K. Chesterton", "description": "Uma coleção de ensaios que critica as filosofias modernas da época, argumentando que a verdadeira liberdade vem da aceitação de uma verdade objetiva."},
        {"bookId": "carta-a-um-religioso", "title": "Carta a um Religioso", "author": "Simone Weil", "description": "Uma carta profunda e pessoal que explora as dúvidas e as certezas da autora em relação à fé e à Igreja Católica."},
        {"bookId": "mapas-tematicos", "title": "Mapas Temáticos", "author": "Septima", "description": "Explore as jornadas dos apóstolos e outros eventos bíblicos em mapas interativos."},
        {"bookId": "spurgeon-sermoes", "title": "Sermões de Spurgeon", "author": "C.H. Spurgeon", "description": "Uma vasta coleção dos sermões do 'Príncipe dos Pregadores', abordando praticamente todos os temas da vida cristã."},
        {"bookId": "a-palavra-as-mulheres", "title": "A Palavra às Mulheres", "author": "K. C. Bushnell", "description": "Uma análise profunda das escrituras sobre o papel e a interpretação de passagens relacionadas às mulheres."},
        {"bookId": "promessas-da-biblia", "title": "Promessas da Bíblia", "author": "Samuel Clarke", "description": "Um compêndio de promessas divinas organizadas por tema para encorajamento e oração."},
        {"bookId": "historia-da-igreja", "title": "História da Igreja", "author": "Philip Schaff", "description": "A jornada completa da igreja cristã desde os apóstolos até a era moderna, cobrindo doutrinas, concílios e eventos."},
        {"bookId": "teologia-apologetica", "title": "Teologia Apologética", "author": "Francis Turretin", "description": "Uma obra monumental da teologia sistemática reformada, defendendo a fé cristã com rigor lógico."},
        {"bookId": "estudos-rapidos", "title": "Estudos Rápidos", "author": "Séptima", "description": "Guias e rotas de estudo temáticos para aprofundar seu conhecimento bíblico de forma rápida e focada."},
        {"bookId": "linha-do-tempo", "title": "Linha do Tempo", "author": "Septima", "description": "Contextualize os eventos bíblicos com a história mundial através de uma linha do tempo interativa."},
        {"bookId": "c-s-lewis-o-peso-da-gloria", "title": "O Peso da Glória", "author": "C. S. Lewis", "description": "Um guia de estudo sobre os sermões e ensaios de Lewis que exploram o anseio humano pelo céu e a natureza da glória divina."},
        {"bookId": "c-s-lewis-o-dom-da-amizade", "title": "O Dom da Amizade", "author": "C. S. Lewis", "description": "Um guia de estudo sobre a exploração profunda da natureza e do valor da amizade, um dos 'quatro amores' de Lewis."},
        {"bookId": "c-s-lewis-a-abolicao-do-homem", "title": "A Abolição do Homem", "author": "C. S. Lewis", "description": "Um guia de estudo sobre a defesa filosófica da existência de valores objetivos e da lei natural contra o relativismo."},
        {"bookId": "c-s-lewis-a-anatomia-de-uma-dor", "title": "A Anatomia de Uma Dor", "author": "C. S. Lewis", "description": "Um guia de estudo sobre o diário íntimo e cru de Lewis com a fé e o sofrimento após a morte de sua esposa."},
        {"bookId": "c-s-lewis-como-ser-cristao", "title": "Como Ser Cristão", "author": "C. S. Lewis", "description": "Um guia de estudo que une obras como 'Cristianismo Puro e Simples', 'Cartas de um Diabo a seu Aprendiz', 'O Grande Divórcio' e 'O Problema da Dor'."},
        {"bookId": "c-s-lewis-a-ultima-noite-do-mundo", "title": "A Última Noite do Mundo", "author": "C. S. Lewis", "description": "Um guia de estudo sobre ensaios que exploram a segunda vinda de Cristo, oração e o significado da existência."},
        {"bookId": "c-s-lewis-cartas-a-malcolm", "title": "Cartas a Malcolm", "author": "C. S. Lewis", "description": "Um guia de estudo sobre uma troca de cartas fictícia que explora a natureza da oração de forma íntima e prática."},
        {"bookId": "c-s-lewis-cartas-de-um-diabo-a-seu-aprendiz", "title": "Cartas de um Diabo a seu Aprendiz", "author": "C. S. Lewis", "description": "Um guia de estudo sobre a sátira genial onde um demônio veterano ensina seu sobrinho a como corromper um ser humano."},
        {"bookId": "c-s-lewis-cristianismo-puro-e-simples", "title": "Cristianismo Puro e Simples", "author": "C. S. Lewis", "description": "Um guia de estudo de uma das mais famosas defesas da fé cristã, argumentando de forma lógica e acessível os pilares do cristianismo."},
        {"bookId": "c-s-lewis-deus-no-banco-dos-reus", "title": "Deus no Banco dos Réus", "author": "C. S. Lewis", "description": "Um guia de estudo sobre ensaios que abordam objeções comuns ao cristianismo, colocando Deus 'no banco dos réus' para responder a críticas."},
        {"bookId": "c-s-lewis-milagres", "title": "Milagres", "author": "C. S. Lewis", "description": "Um guia de estudo sobre a análise filosófica da possibilidade e natureza dos milagres em um mundo governado por leis naturais."},
        {"bookId": "c-s-lewis-o-grande-divorcio", "title": "O Grande Divórcio", "author": "C. S. Lewis", "description": "Um guia de estudo da alegoria sobre uma viagem do inferno ao céu, explorando as escolhas que nos prendem ao pecado."},
        {"bookId": "c-s-lewis-o-problema-da-dor", "title": "O Problema da Dor", "author": "C. S. Lewis", "description": "Um guia de estudo da tentativa intelectual de reconciliar um Deus bom com a realidade do sofrimento."},
        {"bookId": "c-s-lewis-os-quatro-amores", "title": "Os Quatro Amores", "author": "C. S. Lewis", "description": "Um guia de estudo sobre a exploração das quatro formas de amor: Afeição, Amizade, Eros e Caridade (Ágape)."},
        {"bookId": "c-s-lewis-reflexoes", "title": "Reflexões sobre os Salmos", "author": "C. S. Lewis", "description": "Um guia de estudo da meditação pessoal e acadêmica sobre o livro de Salmos, abordando suas dificuldades e belezas."},
        {"bookId": "billy-graham-a-jornada", "title": "A Jornada", "author": "Billy Graham", "description": "Uma exploração sobre o propósito de Deus para a vida e como lidar com as decepções e desafios ao longo do caminho."},
        {"bookId": "billy-graham-anjos", "title": "Anjos", "author": "Billy Graham", "description": "Uma investigação sobre o papel dos anjos como agentes secretos de Deus, sua influência na história bíblica e sua atuação na proteção da humanidade."},
        {"bookId": "billy-graham-aproximando-se-de-casa-vida-fe-e-terminar-bem", "title": "Aproximando-se de Casa", "author": "Billy Graham", "description": "Reflexões sobre envelhecer com graça, fé e propósito, oferecendo sabedoria para terminar bem a jornada da vida."},
        {"bookId": "billy-graham-como-nascer-de-novo", "title": "Como Nascer de Novo", "author": "Billy Graham", "description": "Um guia que explica a experiência do novo nascimento espiritual, ajudando a descobrir valores esquecidos e a tomar uma decisão que pode revolucionar a vida."},
        {"bookId": "billy-graham-em-paz-com-deus", "title": "Em Paz com Deus", "author": "Billy Graham", "description": "Apresenta o caminho para a autêntica paz pessoal em um mundo em crise, mostrando como encontrar calma espiritual em meio ao estresse e desânimo."},
        {"bookId": "billy-graham-esperanca-para-o-coracao-perturbado", "title": "Esperança para o Coração Perturbado", "author": "Billy Graham", "description": "Oferece conforto e encorajamento bíblico para aqueles que enfrentam dor, perda e incerteza, lembrando do amor inabalável de Deus."},
        {"bookId": "billy-graham-o-espirito-santo", "title": "O Espírito Santo", "author": "Billy Graham", "description": "Responde a perguntas fundamentais sobre a terceira pessoa da Trindade, explicando quem Ele é, o que Ele faz e como experimentar Seu poder na vida diária."},
        {"bookId": "billy-graham-respostas-para-os-problemas-da-vida", "title": "Respostas para os Problemas da Vida", "author": "Billy Graham", "description": "Um guia com respostas bíblicas para as preocupações e dúvidas mais comuns da atualidade, abordando mais de 80 tópicos para fortalecer a fé."},
        {"bookId": "billy-graham-tempestade-a-vista", "title": "Tempestade à Vista", "author": "Billy Graham", "description": "Analisa os sinais dos tempos e os problemas urgentes que o mundo enfrenta, explicando como Deus está traçando seu plano final em meio às crises."},
        {"bookId": "billy-graham-vida-e-pos-morte", "title": "Vida e Pós-morte", "author": "Billy Graham", "description": "Aborda uma das maiores questões da humanidade, a morte, explicando-a como parte do plano de Deus e ajudando a superar o medo do que vem a seguir."},
        {"bookId": "-os-guinness-o-chamado", "title": "O Chamado", "author": "Os Guinness", "description": "Um livro escrito para aqueles que possuem um profundo desejo de compreender o propósito de sua existência - o 'porquê' último de sua vida. Os Guinness avalia como essa busca é empreendida por adolescentes, universitários, jovens profissionais, pessoas na meia-idade, pais com o 'ninho vazio', homens e mulheres dos cinquenta para cima. Para conhecer o sentido da sua vida deverão descobrir o propósito para o qual foram criados e para o qual foram chamados."},
        {"bookId": "christine-caine-inesperado-deixe-o-medo-para-tras-e-avance-em-fe", "title": "Inesperado: Deixe o Medo para Trás e Avance em Fé", "author": "Christine Caine", "description": "Neste livro, Christine Caine convida o leitor a deixar para trás o medo do desconhecido e a avançar com fé, mesmo quando a vida toma rumos inesperados. A autora compartilha experiências pessoais e ensinamentos bíblicos para encorajar e equipar o leitor a confiar em Deus em meio às incertezas."},
        {"bookId": "corrie-ten-boom-o-refugio-secreto", "title": "O Refúgio Secreto", "author": "Corrie ten Boom", "description": "A história verídica de como uma família holandesa arrisca sua vida para esconder judeus durante a Segunda Guerra Mundial é vividamente registrada neste livro. Como membros do movimento de Resistência, Corrie ten Boom, seu pai e sua irmã foram enviados aos campos de concentração nazistas onde seu aprendizado sobre a graça divina foi o sustentáculo durante os anos de provação."},
        {"bookId": "elisabeth-elliot-paixao-e-pureza", "title": "Paixão e Pureza", "author": "Elisabeth Elliot", "description": "Por meio de cartas trocadas com Jim e escritos em seu diário, a autora compartilha memórias de sua perseverança sobre as tentações, os sacrifícios enfrentados e as vitórias sobre o fogo da paixão em sua história de namoro com Jim. Neste clássico, Elisabeth oferece ricos ensinamentos bíblicos que auxiliam os solteiros a priorizarem o compromisso com Cristo acima do amor entre um homem e uma mulher."},
        {"bookId": "ellen-santilli-tornando-se-elisabeth-elliot", "title": "Tornando-se Elisabeth Elliot", "author": "Ellen Santilli Vaughn", "description": "Uma biografia que narra a vida de Elisabeth Elliot, desde sua infância e juventude até seus anos como missionária, escritora e palestrante. O livro explora as experiências que moldaram sua fé e ministério, incluindo a perda de seu primeiro marido, Jim Elliot. A obra oferece um olhar íntimo sobre a jornada de uma das mulheres mais influentes do cristianismo do século XX."},
        {"bookId": "ellisabeth-ellioth-deixe-me-ser-mulher", "title": "Deixe-me Ser Mulher", "author": "Elisabeth Elliot", "description": "Escrito de mãe para filha no auge do movimento feminista em 1976, este livro reúne ensinamentos preciosos para os dias de hoje sobre o que é ser uma mulher cristã. Com o objetivo de responder à pergunta “O que significa ser mulher”, Elisabeth Elliot aborda vários assuntos relevantes como: submissão, orgulho, liberdade, vocação."},
        {"bookId": "ellisabeth-ellioth-esperanca-na-solidao-encontrando-deus-no-deserto", "title": "Esperança na Solidão: Encontrando Deus na Escuridão", "author": "Elisabeth Elliot", "description": "Neste livro, Elisabeth Elliot explora o tema da solidão e como encontrar esperança e a presença de Deus em meio a ela. A autora compartilha reflexões e experiências pessoais para encorajar aqueles que se sentem sozinhos, mostrando que a solidão pode ser um caminho para um relacionamento mais profundo com Deus."},
        {"bookId": "ellisabeth-ellioth-o-sofrimento-nunca-e-em-vao", "title": "O Sofrimento Nunca é em Vão", "author": "Elisabeth Elliot", "description": "A partir de seu testemunho de vida e todas as provações que ela passou, somos desafiados, encorajados e inspirados a continuar confiando em Deus mesmo nos momentos mais difíceis e angustiantes de nossas vidas."},
        {"bookId": "ellisabeth-ellioth-uma-vida-de-obediencia-7-disciplinas-para-a-vida-do-cristao", "title": "Uma Vida de Obediência: 7 Disciplinas para uma Vida mais Forte", "author": "Elisabeth Elliot", "description": "Elisabeth Elliot apresenta sete disciplinas espirituais para fortalecer a vida cristã. Com base em sua própria jornada de fé, a autora explora a importância da obediência a Deus em áreas como a vontade, o corpo, a mente, as posses, o tempo, o trabalho e os sentimentos. O livro oferece um guia prático para uma vida de maior disciplina e dedicação a Deus."},
        {"bookId": "emerson-eggerichs-amor-e-respeito-na-familia-o-que-os-pais-mais-desejam-do-que-os-filhos-mais-precisam", "title": "Amor e Respeito na Família", "author": "Emerson Eggerichs", "description": "Psicólogos afirmam hoje o que a sabedoria bíblica já havia estabelecido há milênios: as crianças precisam do amor que Deus nos ordenou dar a elas (Tito 2.4), e os pais precisam receber delas o respeito que as Escrituras apontam ser o dever dos filhos (Êxodo 20.12). Amor e respeito na família oferece orientações práticas para romper o que os autores denominam o ciclo insano que realimenta a discórdia, afasta pais e filhos e torna o lar um ambiente tóxico."},
        {"bookId": "jen-wilkin-mulheres-da-palavra-como-estudar-a-biblia-com-nossa-mente-e-coracao", "title": "Mulheres da Palavra", "author": "Jen Wilkin", "description": "Oferecendo um plano claro e conciso de aprofundamento no estudo das Sagradas Escrituras, este livro irá ajudar as mulheres a perseverarem na leitura da Palavra de Deus, de forma a treinar suas mentes e transformar seus corações."},
        {"bookId": "jen-wilkin-ninguem-como-ele", "title": "Ninguém como Ele", "author": "Jen Wilkin", "description": "Jen Wilkin explora dez atributos de Deus que destacam Sua singularidade e majestade. O livro convida o leitor a um estudo profundo sobre quem Deus é, mostrando como a compreensão de Seus atributos pode transformar a adoração, o relacionamento e a vida diária do crente."},
        {"bookId": "joyce-meyer-campo-de-batalha-da-mente-vencendo-a-batalha-na-sua-mente", "title": "Campo de Batalha da Mente", "author": "Joyce Meyer", "description": "Se você é um dos milhões que sofrem com preocupação, dúvida, depressão, raiva ou culpa, você está experimentando um ataque à sua mente. Superar pensamentos negativos que vêm contra sua mente traz liberdade e paz."},
        {"bookId": "martyn-lloyd-jones-depressao-espiritual", "title": "Depressão Espiritual", "author": "Martyn Lloyd-Jones", "description": "Neste livro, o Dr. Lloyd-Jones discute as causas da depressão espiritual e a forma como deve ser tratada e superada. A Bíblia aborda este tema com muita frequência, e como parece ser um problema que afetou muitos do povo de Deus, e ainda afeta os cristãos de hoje, este livro certamente será de grande ajuda para esclarecer o que a Bíblia ensina sobre este assunto."},
        {"bookId": "nancy-demoss-adornada-vivendo-a-beleza-do-evangelho-em-comunhao", "title": "Adornada: Vivendo a Beleza do Evangelho em Meio às Mulheres", "author": "Nancy DeMoss Wolgemuth", "description": "Nancy DeMoss Wolgemuth explora a passagem de Tito 2 e o chamado para que as mulheres mais velhas ensinem as mais novas. O livro oferece uma visão prática de como viver o evangelho de forma bela e intencional, construindo relacionamentos de mentoria que edificam a igreja e glorificam a Deus."},
        {"bookId": "nancy-leigh-demoss-mentiras-em-que-as-garotas-acreditam-e-a-verdade-que-as-liberta", "title": "Mentiras em que as Garotas Acreditam e a Verdade que as Liberta", "author": "Nancy DeMoss Wolgemuth", "description": "Nancy DeMoss Wolgemuth e Dannah Gresh abordam as mentiras comuns que as jovens acreditam sobre Deus, si mesmas, rapazes, amizades e o futuro. O livro oferece a verdade da Palavra de Deus para combater essas mentiras, ajudando as jovens a viverem na liberdade e na verdade de Cristo."},
        {"bookId": "nancy-r--pearcey-verdade-total-libertando-o-cristianismo-de-seu-cativeiro-cultural", "title": "Verdade Total: Libertando o Cristianismo de seu Cativeiro Cultural", "author": "Nancy R. Pearcey", "description": "Nancy Pearcey argumenta que o cristianismo não é apenas uma fé privada, mas uma verdade total que se aplica a todas as áreas da vida. O livro desafia os cristãos a desenvolverem uma cosmovisão bíblica consistente, capaz de engajar e transformar a cultura, libertando o cristianismo da dicotomia entre o sagrado e o secular."},
        {"bookId": "richard-j--foster-celebracao-da-disciplina", "title": "Celebração da Disciplina", "author": "Richard J. Foster", "description": "Richard Foster escreveu este livro para ajudar os cristãos a redescobrir os 'hábitos sagrados' que foram negligenciados ou mal compreendidos no cristianismo moderno. Ele divide essas práticas em três categorias: disciplinas internas, disciplinas externas e disciplinas corporativas."},
        {"bookId": "rosaria-butterfield-o-evangelho-vem-com-uma-chave-de-casa", "title": "O Evangelho Vem com uma Chave de Casa", "author": "Rosaria Butterfield", "description": "Rosaria Butterfield descreve a prática da hospitalidade radicalmente comum como um meio de viver o evangelho no dia a dia. A autora compartilha histórias de como abrir sua casa para estranhos e vizinhos se tornou uma poderosa ferramenta de evangelismo e discipulado, mostrando que o evangelho é compartilhado tanto na mesa de jantar quanto no púlpito."},
        {"bookId": "rosaria-champagne-butterfield-pensamentos-secretos-de-uma-convertida-improvavel", "title": "Pensamentos Secretos de uma Convertida Improvável", "author": "Rosaria Butterfield", "description": "A jornada de uma professora de língua inglesa rumo à fé cristã. Rosaria Champagne Butterfield conta a história de sua conversão, e é surpreendente. O amor de Deus não tem limites, ninguém é um caso perdido, Jesus veio para TODOS. Essa leitura despertou em mim um olhar diferente para as pessoas."},
        {"bookId": "sally-clarkson-o-lar-que-da-vida-criando-um-lugar-de-pertencimento-e-beleza", "title": "O Lar que Dá Vida: Criando um Lugar de Pertença e Propósito", "author": "Sally Clarkson", "description": "Sally Clarkson inspira as mães a criarem um lar que seja um refúgio de amor, vida e aprendizado para seus filhos. O livro oferece conselhos práticos e encorajamento para cultivar uma atmosfera familiar que nutra a alma e o coração, transformando a casa em um lugar onde a fé e o caráter são forjados."},
        {"bookId": "tedd-tripp-pastoreando-o-coracao-da-crianca", "title": "Pastoreando o Coração da Criança", "author": "Tedd Tripp", "description": "Pastoreando o Coração da Criança é uma obra sobre como falar ao coração de nossos filhos. As coisas que seu filho diz e faz brotam do coração. Lucas 6.45 afirma isso com as seguintes palavras: 'A boca fala do que está cheio o coração'. Escrito para pais que têm filhos de qualquer idade, este livro esclarecedor fornece perspectivas e procedimentos para o pastoreio do coração da criança nos caminhos da vida."},
        {"bookId": "timothy-keller-o-significado-do-casamento", "title": "O Significado do Casamento", "author": "Timothy Keller", "description": "Este livro se baseia na muito aplaudida série de sermões pregados por Timothy Keller, autor best-seller do New York Times. O autor mostra a todos — cristãos, céticos, solteiros, casais casados há muito tempo e aos que estão prestes a noivar — a visão do que o casamento deve ser segundo a Bíblia."},
        {"bookId": "sheldon-vanauken-uma-misericordia-severa","title": "Uma Misericórdia Severa","author": "Sheldon Vanauken","description": "Vencedor do National Book Award, 'Uma Misericórdia Severa' é o relato comovente da história de amor de Sheldon Vanauken e sua esposa, Jean, a descoberta da fé em meio à dor e a amizade com C. S. Lewis. A obra inclui dezoito cartas de C. S. Lewis que abordam questões universais sobre fé, a existência de Deus e as razões por trás do sofrimento. É uma narrativa autobiográfica sobre a busca espiritual do autor e o impacto transformador que a amizade com Lewis teve em sua vida."}
    ]
    """

    # 4. Montagem do Prompt para a OpenAI
    system_prompt = f"""
Você é um bibliotecário e conselheiro teológico especialista. Sua tarefa é analisar a necessidade do usuário e recomendar até 4 livros da lista fornecida.

# INSTRUÇÕES:
1.  Analise a "NECESSIDADE DO USUÁRIO". Este texto pode ser uma pergunta direta ou um compilado de interações recentes que refletem os interesses do usuário.
2.  Compare essa necessidade com o título, autor e descrição de cada livro na "LISTA DE LIVROS".
3.  Selecione de 3 a 7 livros que melhor respondem à necessidade ou interesse do usuário.
4.  Para CADA livro selecionado, escreva uma "justificativa" curta e pessoal (1-2 frases) explicando por que aquele livro é uma boa recomendação.
5.  Retorne sua resposta ESTRITAMENTE no formato JSON, como uma lista de objetos, usando a chave "recommendations". Cada objeto deve conter 'bookId', 'title', 'author', 'coverImagePath', e 'justificativa'.

# LISTA DE LIVROS DISPONÍVEIS:
{library_items_json}

# EXEMPLO DE SAÍDA JSON ESPERADA:
{{
  "recommendations": [
    {{
      "bookId": "c-s-lewis-a-ultima-noite-do-mundo", 
      "title": "A Última Noite do Mundo",
      "author": "C. S. Lewis",
      "coverImagePath": "caminho/para/capa.webp",
      "justificativa": "Sua justificativa para este livro aqui."
    }}
  ]
}}

# EXEMPLO DE SAÍDA INCORRETA (NÃO retire partes do id), exemplo do id "c-s-lewis-a-ultima-noite-do-mundo":
# {{ "bookId": "a-ultima-noite-do-mundo" }}
"""
    
    user_prompt = f"NECESSIDADE DO USUÁRIO: \"{recommendation_base_text}\""

    # 5. Chamada à API da OpenAI e Retorno
    try:
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key: raise ValueError("Secret 'openai-api-key' não encontrado.")
        client = OpenAI(api_key=openai_api_key)

        print(f"Enviando prompt para a OpenAI...")
        
        chat_completion = client.chat.completions.create(
            model="gpt-5-nano",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            response_format={"type": "json_object"}
        )

        response_content = chat_completion.choices[0].message.content
        print(f"Resposta bruta da OpenAI: {response_content}")

        recommendations = []
        if response_content:
            try:
                response_data = json.loads(response_content)
                
                # Procura pela chave "recommendations" ou "books"
                if isinstance(response_data, dict) and "recommendations" in response_data and isinstance(response_data["recommendations"], list):
                    recommendations = response_data["recommendations"]
                elif isinstance(response_data, dict) and "books" in response_data and isinstance(response_data["books"], list):
                    recommendations = response_data["books"]
                elif isinstance(response_data, list):
                    recommendations = response_data
                else:
                    raise TypeError("Formato de resposta da IA não contém uma lista de recomendações válida.")

            except (json.JSONDecodeError, TypeError) as e:
                print(f"Erro ao processar o JSON da OpenAI: {e}")
                raise TypeError("A resposta da IA não estava no formato JSON esperado.")
        
        print(f"Recomendações extraídas com sucesso: {len(recommendations)} livros.")
        return {"status": "success", "recommendations": recommendations}

    except Exception as e:
        print(f"ERRO CRÍTICO em recommendLibraryBooks: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Ocorreu um erro ao gerar as recomendações: {e}"
        )


@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    cors=cors_options
)
def getVerseRecommendationsForChapter(req: https_fn.CallableRequest) -> dict:
    db = get_db()
    
    # 1. Autenticação e Validação
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para receber recomendações.'
        )
    
    user_id = req.auth.uid
    book_abbrev = req.data.get("bookAbbrev")
    chapter_raw = req.data.get("chapter")

    # ==========================================================
    # <<< CORREÇÃO FINAL E DEFINITIVA AQUI >>>
    # ==========================================================
    # Esta lógica agora lida com o formato de objeto que o Flutter envia para números.
    chapter_to_parse = None
    if isinstance(chapter_raw, dict) and 'value' in chapter_raw:
        # Se 'chapter_raw' for um dicionário com a chave 'value', pegamos o valor de dentro.
        chapter_to_parse = chapter_raw['value']
        print(f"Parâmetro 'chapter' recebido como objeto, extraindo valor: {chapter_to_parse}")
    else:
        # Se for qualquer outra coisa (int, string, etc.), usamos o valor bruto.
        chapter_to_parse = chapter_raw

    try:
        chapter = int(chapter_to_parse)
    except (ValueError, TypeError):
        print(f"ERRO: Não foi possível converter 'chapter_to_parse' para inteiro. Valor: {chapter_to_parse}, Tipo: {type(chapter_to_parse)}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="O parâmetro 'chapter' deve ser um número inteiro."
        )
    # ==========================================================
    # <<< FIM DA CORREÇÃO >>>
    # ==========================================================
    
    # 2. Lógica de Cache (sem alterações)
    chapter_id_cache = f"{book_abbrev}_{chapter}"
    user_doc_ref = db.collection('users').document(user_id)
    cache_ref = user_doc_ref.collection('recommendedVerses').document(chapter_id_cache)
    
    try:
        cached_doc = cache_ref.get()
        if cached_doc.exists:
            cached_data = cached_doc.to_dict()
            if 'verses' in cached_data:
                print(f"Cache HIT para '{chapter_id_cache}'.")
                return {"verses": cached_data['verses']}
    except Exception as e:
        print(f"AVISO: Erro ao ler cache: {e}.")

    print(f"Cache MISS para '{chapter_id_cache}'. Buscando na IA.")

    # O resto da sua função continua exatamente o mesmo...
    try:
        user_doc_snapshot = user_doc_ref.get()
        if not user_doc_snapshot.exists:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Usuário não encontrado.")
        
        # ... (lógica para learning_goal, texto da bíblia, chamada à OpenAI, etc.) ...
        user_data = user_doc_snapshot.to_dict()
        learning_goal = user_data.get("learningGoal")
        
        if not learning_goal or not learning_goal.strip():
            print(f"Usuário {user_id} não possui um 'learningGoal' definido. Retornando lista vazia.")
            cache_ref.set({"verses": [], "createdAt": firestore.SERVER_TIMESTAMP})
            return {"verses": []}

        bible_doc_id = f"ARA_{book_abbrev}"
        bible_doc = db.collection('Bible').document(bible_doc_id).get()
        if not bible_doc.exists:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message=f"Texto bíblico não encontrado para '{bible_doc_id}'.")
            
        bible_data = bible_doc.to_dict()
        chapter_verses = bible_data.get("chapters", {}).get(str(chapter))
        
        if not chapter_verses or not isinstance(chapter_verses, list):
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message=f"Capítulo {chapter} não encontrado para o livro '{bible_doc_id}'.")

        chapter_text_formatted = "\n".join([f"Versículo {i+1}: {verse}" for i, verse in enumerate(chapter_verses)])

        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Chave da API OpenAI não configurada.")
        
        client = OpenAI(api_key=openai_api_key)
        book_full_name = ABBREV_TO_FULL_NAME_MAP.get(book_abbrev, book_abbrev.upper())
        
        system_prompt = "Você é um assistente teológico especialista em análise semântica da Bíblia."
        user_prompt = f"""
O objetivo de estudo do usuário é: "{learning_goal}"

Abaixo está o texto completo do capítulo {book_full_name} {chapter}.
Analise cada versículo e identifique quais se relacionam DIRETAMENTE com o objetivo do usuário.

Retorne APENAS um objeto JSON com uma única chave "verses" contendo um array com os NÚMEROS dos versículos relevantes. Não inclua nenhuma outra palavra, explicação ou formatação.
Se nenhum versículo for relevante, retorne um array vazio [].

Exemplo de saída: {{"verses": [3, 5, 12, 26]}}

Texto do Capítulo:
---
{chapter_text_formatted}
---
"""
        print(f"Enviando prompt para a OpenAI para o usuário {user_id}...")
        
        chat_completion = client.chat.completions.create(
            model="gpt-5-nano",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            response_format={"type": "json_object"}
        )
        
        response_content = chat_completion.choices[0].message.content
        print(f"Resposta da OpenAI recebida: {response_content}")
        
        try:
            parsed_json = json.loads(response_content)
            recommended_verses = parsed_json.get("verses", []) 
            if not isinstance(recommended_verses, list):
                recommended_verses = []

        except (json.JSONDecodeError, TypeError, AttributeError) as e:
            print(f"ERRO: A resposta da OpenAI não é um JSON válido ou está em formato inesperado: {e}")
            recommended_verses = []

        cache_ref.set({"verses": recommended_verses, "createdAt": firestore.SERVER_TIMESTAMP})
        print(f"Resultado salvo no cache para '{chapter_id_cache}'. Versículos: {recommended_verses}")
        
        return {"verses": recommended_verses}

    except Exception as e:
        print(f"ERRO CRÍTICO em getVerseRecommendationsForChapter: {e}")
        traceback.print_exc()
        return {"verses": []}



# ==============================================================================
# <<< NOVA CLOUD FUNCTION: GET SERMON RECOMMENDATIONS FOR USER >>>
# ==============================================================================
async def getSermonRecommendationsForUser_async(req: https_fn.CallableRequest) -> dict:
    """
    (Lógica Assíncrona Interna)
    Busca o 'learningGoal' de um usuário, usa-o para encontrar sermões
    semanticamente relevantes e armazena o resultado em cache no Firestore.
    """
    db = get_db()
    
    # 1. Autenticação e Validação
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message='Você precisa estar logado para receber recomendações.'
        )
    
    user_id = req.auth.uid
    
    if sermons_service is None:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Erro interno: serviço de sermões não está disponível.")

    # 2. Lógica de Cache (Leitura)
    cache_ref = db.collection('users').document(user_id).collection('personalizedContent').document('sermonRecommendations')
    
    try:
        cached_doc = await asyncio.to_thread(cache_ref.get)
        if cached_doc.exists:
            cached_data = cached_doc.to_dict()
            if 'recommendations' in cached_data:
                print(f"Cache HIT para recomendações de sermões do usuário {user_id}.")
                return {"recommendations": cached_data.get('recommendations', [])}
    except Exception as e:
        print(f"AVISO: Erro ao ler o cache de sermões para {user_id}: {e}. Prosseguindo...")

    print(f"Cache MISS para recomendações de sermões do usuário {user_id}. Gerando novas recomendações.")

    try:
        # 3. Buscar Contexto (learningGoal do usuário)
        user_ref = db.collection('users').document(user_id)
        user_doc = await asyncio.to_thread(user_ref.get)
        if not user_doc.exists:
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.NOT_FOUND, message="Usuário não encontrado.")
        
        user_data = user_doc.to_dict()
        learning_goal = user_data.get("learningGoal")
        
        if not learning_goal or not learning_goal.strip():
            print(f"Usuário {user_id} não possui 'learningGoal'. Cacheando resultado vazio.")
            await asyncio.to_thread(cache_ref.set, {'recommendations': [], 'createdAt': firestore.SERVER_TIMESTAMP})
            return {"recommendations": []}

        # 4. Chamar o Serviço de Busca Semântica
        print(f"Chamando sermons_service com a query: '{learning_goal[:50]}...'")
        recommended_sermons = await sermons_service.perform_sermon_semantic_search(
            user_query=learning_goal,
            top_k_sermons=5
        )
        
        # 5. Salvar no Cache
        print(f"Salvando {len(recommended_sermons)} recomendações de sermões no cache para {user_id}.")
        await asyncio.to_thread(cache_ref.set, {
            'recommendations': recommended_sermons,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # 6. Retornar o resultado
        return {"recommendations": recommended_sermons}

    except Exception as e:
        print(f"ERRO CRÍTICO em getSermonRecommendationsForUser_async para {user_id}: {e}")
        traceback.print_exc()
        return {"recommendations": []}

@https_fn.on_call(
    secrets=["openai-api-key", "pinecone-api-key"],
    region=options.SupportedRegion.SOUTHAMERICA_EAST1,
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    cors=cors_options
)
def getSermonRecommendationsForUser(req: https_fn.CallableRequest) -> dict:
    """
    (Wrapper Síncrono)
    Ponto de entrada para a chamada do cliente. Executa a lógica assíncrona.
    """
    return _run_async_handler_wrapper(
        getSermonRecommendationsForUser_async(req)
    )