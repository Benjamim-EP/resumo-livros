# functions/bible_search_service.py
import os
import traceback
from openai import OpenAI # Garanta que 'openai' está no seu requirements.txt
import httpx # Usar httpx para requisições async mais robustas

# Configuração - Chaves serão lidas de os.environ
# PINECONE_ENDPOINT é o HOST mostrado na sua imagem do console Pinecone
PINECONE_ENDPOINT = "https://biblia-hqija7a.svc.aped-4627-b74a.pinecone.io" # CONFIRME SE É ESTE
EMBEDDING_MODEL = "text-embedding-3-small" # Ou text-embedding-3-large se usou para indexar

# Variáveis globais para clientes (serão inicializadas uma vez)
_openai_client = None
_httpx_client = None
_pinecone_api_key_loaded = None # Para armazenar a chave do Pinecone após carregá-la

def _initialize_clients():
    """Inicializa os clientes OpenAI e HTTPX se ainda não foram, e carrega a chave do Pinecone."""
    global _openai_client, _httpx_client, _pinecone_api_key_loaded

    if _openai_client is None:
        # Usa OPENAI_KEY conforme a configuração do Firebase `openai.key`
        openai_api_key = os.environ.get("OPENAI_KEY")
        if not openai_api_key:
            print("ERRO CRÍTICO (BibleSearch): Variável de ambiente OPENAI_KEY não configurada.")
            # Em um ambiente de produção, você pode querer levantar uma exceção aqui
            # ou ter um mecanismo de fallback/notificação.
            raise ValueError("OPENAI_KEY não configurada.")
        try:
            _openai_client = OpenAI(api_key=openai_api_key)
            print("Cliente OpenAI inicializado com sucesso para BibleSearchService.")
        except Exception as e_openai_init:
            print(f"ERRO CRÍTICO (BibleSearch): Falha ao inicializar cliente OpenAI: {e_openai_init}")
            _openai_client = None # Garante que não será usado se a inicialização falhar
            raise

    if _httpx_client is None:
        try:
            _httpx_client = httpx.AsyncClient(timeout=30.0) # Timeout de 30s para requisições
            print("Cliente HTTPX inicializado com sucesso para BibleSearchService.")
        except Exception as e_httpx_init:
            print(f"ERRO CRÍTICO (BibleSearch): Falha ao inicializar cliente HTTPX: {e_httpx_init}")
            _httpx_client = None
            raise

    if _pinecone_api_key_loaded is None:
        # Usa PINECONE_KEY conforme a configuração do Firebase `pinecone.key`
        _pinecone_api_key_loaded = os.environ.get("PINECONE_KEY")
        if not _pinecone_api_key_loaded:
            print("ERRO CRÍTICO (BibleSearch): Variável de ambiente PINECONE_KEY não configurada.")
            raise ValueError("PINECONE_KEY não configurada.")
        print("Chave API do Pinecone carregada com sucesso para BibleSearchService.")


async def generate_embedding_async(text_to_embed: str) -> list[float]:
    """Gera embedding para o texto usando OpenAI de forma assíncrona."""
    _initialize_clients() # Garante que o cliente está inicializado
    if not _openai_client:
        print("ERRO (generate_embedding_async): Cliente OpenAI não está inicializado.")
        raise ConnectionError("Cliente OpenAI não inicializado em generate_embedding_async.")

    if not text_to_embed or not isinstance(text_to_embed, str):
        print("ERRO (generate_embedding_async): Texto para embedding inválido ou vazio.")
        raise ValueError("Texto para embedding inválido ou vazio.")

    print(f"Gerando embedding para texto: '{text_to_embed[:50]}...'")
    try:
        response = await _openai_client.embeddings.create(
            model=EMBEDDING_MODEL,
            input=text_to_embed
        )
        if response.data and len(response.data) > 0 and response.data[0].embedding:
            print(f"Embedding gerado com sucesso (primeiros 5 valores): {response.data[0].embedding[:5]}")
            return response.data[0].embedding
        else:
            print(f"Resposta inesperada da API de embedding OpenAI: {response}")
            raise ValueError("Resposta da API de embedding OpenAI não contém dados de embedding válidos.")
    except Exception as e:
        print(f"Erro ao gerar embedding com OpenAI: {e}")
        traceback.print_exc() # Loga o traceback completo para depuração
        # Você pode querer levantar uma exceção mais específica ou tratar o erro de forma diferente
        raise # Relança a exceção para ser tratada pela função chamadora

async def query_pinecone_async(vector: list[float], top_k: int, filters: dict | None = None) -> list[dict]:
    """Consulta o Pinecone de forma assíncrona."""
    _initialize_clients() # Garante que os clientes e a chave do Pinecone estão inicializados
    if not _httpx_client:
        print("ERRO (query_pinecone_async): Cliente HTTPX não está inicializado.")
        raise ConnectionError("Cliente HTTPX não inicializado em query_pinecone_async.")
    if not _pinecone_api_key_loaded:
        print("ERRO (query_pinecone_async): Chave API do Pinecone não carregada.")
        raise ConnectionError("Chave API do Pinecone não carregada.")

    if not vector or not isinstance(vector, list):
        print("ERRO (query_pinecone_async): Vetor de query inválido.")
        raise ValueError("Vetor de query inválido.")
    if not isinstance(top_k, int) or top_k <= 0:
        print(f"AVISO (query_pinecone_async): top_k inválido ({top_k}), usando padrão 1.")
        top_k = 1 # Um valor padrão seguro

    request_url = f"{PINECONE_ENDPOINT}/query"
    headers = {
        "Api-Key": _pinecone_api_key_loaded, # Usa a chave carregada
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    payload: dict[str, any] = { # Define o tipo do payload
        "vector": vector,
        "topK": top_k,
        "includeMetadata": True,
        "includeValues": False
    }
    if filters and isinstance(filters, dict) and filters:
        payload["filter"] = filters
        print(f"Consultando Pinecone com filtros: {filters}")
    else:
        print("Consultando Pinecone sem filtros.")

    print(f"Enviando requisição para Pinecone URL: {request_url}")
    # print(f"Pinecone Query Payload (parcial): vector_len={len(payload['vector'])}, topK={payload['topK']}, filter={payload.get('filter')}")

    try:
        response = await _httpx_client.post(request_url, headers=headers, json=payload)
        response.raise_for_status() # Lança exceção para erros HTTP (4xx ou 5xx)
        result_data = response.json()
        matches = result_data.get("matches", [])
        print(f"Consulta ao Pinecone bem-sucedida. Recebidos {len(matches)} resultados.")
        # if matches:
        #     print(f"  Exemplo do primeiro resultado: ID={matches[0].get('id')}, Score={matches[0].get('score')}")
        return matches
    except httpx.HTTPStatusError as e:
        print(f"Erro HTTP ao consultar Pinecone: {e.response.status_code}")
        print(f"Corpo da resposta do erro do Pinecone: {e.response.text}")
        traceback.print_exc()
        raise # Relança a exceção para tratamento na Cloud Function
    except httpx.RequestError as e_req: # Captura erros de rede, timeouts, etc.
        print(f"Erro de requisição ao consultar Pinecone (ex: timeout, DNS): {e_req}")
        traceback.print_exc()
        raise ConnectionError(f"Erro de rede ao conectar com Pinecone: {e_req}")
    except Exception as e:
        print(f"Erro inesperado ao consultar Pinecone: {e}")
        traceback.print_exc()
        raise # Relança a exceção


async def perform_semantic_search(user_query: str, filters: dict | None, top_k: int = 10) -> list[dict]:
    """
    Realiza a busca semântica: gera embedding da query e consulta o Pinecone.
    """
    if not user_query or not isinstance(user_query, str):
        print("ERRO (perform_semantic_search): A query do usuário é inválida ou vazia.")
        raise ValueError("A query do usuário não pode ser vazia.")
    if filters is not None and not isinstance(filters, dict):
        print(f"AVISO (perform_semantic_search): Filtros fornecidos não são um dicionário ({type(filters)}). Serão ignorados.")
        filters = None # Ignora filtros malformados
    if not isinstance(top_k, int) or top_k <= 0:
        print(f"AVISO (perform_semantic_search): top_k inválido ({top_k}), usando padrão 10.")
        top_k = 10

    print(f"Iniciando busca semântica para query: '{user_query[:100]}...' com filtros: {filters} e top_k: {top_k}")

    try:
        # Passo 1: Gerar embedding para a query do usuário
        query_vector = await generate_embedding_async(user_query)
        # print(f"Embedding gerado para a query (dimensões: {len(query_vector)}).")

        # Passo 2: Consultar o Pinecone com o vetor e filtros
        search_results = await query_pinecone_async(query_vector, top_k, filters)
        print(f"Busca semântica concluída. {len(search_results)} resultados retornados do Pinecone.")
        return search_results
    except ValueError as ve: # Captura erros de validação de _initialize_clients ou generate_embedding_async
        print(f"Erro de valor durante a busca semântica: {ve}")
        traceback.print_exc()
        raise # Relança para a Cloud Function tratar como INVALID_ARGUMENT
    except ConnectionError as ce: # Captura erros de conexão
        print(f"Erro de conexão durante a busca semântica: {ce}")
        traceback.print_exc()
        raise # Relança para a Cloud Function tratar como UNAVAILABLE
    except Exception as e:
        print(f"Falha geral inesperada na busca semântica: {e}")
        traceback.print_exc()
        # Relança a exceção para ser tratada pela Cloud Function que chamou este serviço
        # Isso permitirá que a Cloud Function retorne um erro HttpsError.INTERNAL apropriado.
        raise Exception(f"Erro interno no serviço de busca: {str(e)}")

# Chamada para inicializar os clientes quando o módulo é carregado pela primeira vez.
# Isso pode ajudar com o "cold start" da Cloud Function, mas também pode ser feito
# de forma "lazy" dentro de cada função async se preferir.
# Para Cloud Functions, a inicialização no escopo global do módulo é comum.
try:
    _initialize_clients()
except ValueError as e_init_clients:
    # Loga o erro, mas não impede o carregamento do módulo.
    # As funções individuais que dependem dos clientes levantarão exceções se eles não estiverem prontos.
    print(f"AVISO: Falha na inicialização inicial de clientes em bible_search_service: {e_init_clients}")
    print("As funções tentarão inicializar os clientes quando chamadas.")