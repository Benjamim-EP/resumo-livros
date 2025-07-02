# functions/main.py
import os
import sys
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, credentials, auth
from firebase_functions import https_fn, options
from datetime import datetime, timezone
import asyncio
import traceback

# >>> INÍCIO DOS NOVOS IMPORTS PARA GOOGLE PLAY <<<
from google.oauth2 import service_account
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
# >>> FIM DOS NOVOS IMPORTS <<<

print(">>>> main.py (VERSÃO LAZY INIT - CORRETA) <<<<")

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