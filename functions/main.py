# functions/main.py
import os
import sys
import firebase_admin
import google.auth
from firebase_admin import initialize_app, firestore, credentials
from firebase_functions import https_fn, options
from datetime import datetime, timezone
import asyncio
import traceback

# >>> INÍCIO DOS NOVOS IMPORTS PARA GOOGLE PLAY <<<
from google.oauth2 import service_account
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
# >>> FIM DOS NOVOS IMPORTS <<<

print(">>>> main.py (VERSÃO GOOGLE PLAY BILLING) <<<<")

# --- Importação dos seus módulos de serviço ---
try:
    import bible_search_service
    print("Módulo 'bible_search_service' importado com sucesso.")
except ImportError as e_import:
    print(f"ERRO CRÍTICO: Falha ao importar 'bible_search_service': {e_import}")
    bible_search_service = None

try:
    import sermons_service
    print("Módulo 'sermons_service' importado com sucesso.")
except ImportError as e_import_sermon:
    print(f"ERRO CRÍTICO: Falha ao importar 'sermons_service': {e_import_sermon}")
    sermons_service = None

# --- Inicialização do Firebase Admin ---
if not firebase_admin._apps:
    try:
        initialize_app()
        print("Firebase Admin SDK inicializado com credenciais de ambiente padrão.")
    except Exception as e_init:
        print(f"ERRO CRÍTICO: Não foi possível inicializar o Firebase Admin SDK: {e_init}")
        raise

# Obtém o cliente Firestore
db = firestore.client()
print("Cliente Firestore obtido com sucesso.")

# Define a região global para as Cloud Functions
options.set_global_options(region=options.SupportedRegion.SOUTHAMERICA_EAST1)

# --- Constantes do Google Play ---
# O nome do seu pacote, conforme definido no seu app/build.gradle
PACKAGE_NAME = "com.septima.septimabiblia" 

# --- Funções Auxiliares (Async) ---
def _run_async_handler_wrapper(async_func):
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop.run_until_complete(async_func)

# --- NOVA CLOUD FUNCTION PARA VALIDAR COMPRAS DO GOOGLE PLAY ---
@https_fn.on_call(
    secrets=["play-store-service-account-key"], # <<< NOME DA SUA SECRET COM O JSON DA CONTA DE SERVIÇO
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
    if not req.auth or not req.auth.uid:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message='Usuário não autenticado.')
    
    user_id = req.auth.uid
    product_id = req.data.get('productId')
    purchase_token = req.data.get('purchaseToken')
    
    if not all([product_id, purchase_token]):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message='productId e purchaseToken são obrigatórios.')

    print(f"Iniciando validação para User: {user_id}, Product: {product_id}, Token: {purchase_token[:10]}...")

    try:
        # Autentica com a API do Google Play Developer usando a chave da Secret
        service_account_info = os.environ.get("play-store-service-account-key")
        creds = service_account.Credentials.from_service_account_info(
            eval(service_account_info), # eval() para converter a string do JSON em dict
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        
        android_publisher = build('androidpublisher', 'v3', credentials=creds)

        # Chama a API para verificar a compra
        purchase = await asyncio.to_thread(
            lambda: android_publisher.purchases().subscriptions().get(
                packageName=PACKAGE_NAME,
                subscriptionId=product_id,
                token=purchase_token
            ).execute()
        )
        
        print(f"Resposta da API do Google Play: {purchase}")

        # Analisa a resposta
        # 0 = PENDENTE, 1 = ATIVA, 2 = EXPIRADA, 3 = CANCELADA, etc.
        payment_state = purchase.get('paymentState') 
        expiry_time_millis = int(purchase.get('expiryTimeMillis', 0))
        
        is_valid = payment_state == 1 # Apenas considera ATIVA como válida

        if is_valid:
            print(f"Compra VÁLIDA para {user_id}. Estado: {payment_state}")
            expiry_date = datetime.fromtimestamp(expiry_time_millis / 1000, tz=timezone.utc)
            
            # Atualiza o documento do usuário no Firestore
            user_ref = db.collection('users').document(user_id)
            await asyncio.to_thread(
                user_ref.set,
                {
                    'subscriptionStatus': 'active',
                    'subscriptionEndDate': expiry_date,
                    'activePriceId': product_id, # Usando o productId do Google Play
                    'lastPurchaseToken': purchase_token
                },
                merge=True
            )
            print(f"Firestore atualizado para {user_id}. Assinatura ativa até {expiry_date}.")
            return {'status': 'success', 'message': 'Assinatura validada e ativada.'}
        else:
            print(f"Compra INVÁLIDA para {user_id}. Estado: {payment_state}")
            # Se a compra não for ativa, atualizamos o status para inativo para garantir consistência
            user_ref = db.collection('users').document(user_id)
            await asyncio.to_thread(
                user_ref.set, {'subscriptionStatus': 'inactive'}, merge=True
            )
            raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message='A compra não está ativa.')

    except Exception as e:
        print(f"ERRO durante a validação da compra no Google Play: {e}")
        traceback.print_exc()
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message=f'Erro ao validar a assinatura: {e}')


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