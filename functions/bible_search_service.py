# functions/bible_search_service.py
import os
import traceback
from openai import OpenAI # Garanta que 'openai>=1.0.0' está no seu requirements.txt
import httpx # Usar httpx>=0.25.0 para requisições async mais robustas
import asyncio # Para asyncio.to_thread

# Configuração - Chaves serão lidas de os.environ
# PINECONE_ENDPOINT é o HOST mostrado na sua imagem do console Pinecone
PINECONE_ENDPOINT = "https://biblia-hqija7a.svc.aped-4627-b74a.pinecone.io" # CONFIRME SE É ESTE
EMBEDDING_MODEL = "text-embedding-3-small" # Ou text-embedding-3-large se usou para indexar

# Variáveis globais para clientes (serão inicializadas uma vez por instância de função "quente")
_openai_client = None
_httpx_client = None
_pinecone_api_key_loaded = None # Para armazenar a chave do Pinecone após carregá-la

def _initialize_clients():
    """
    Inicializa os clientes OpenAI e HTTPX se ainda não foram, e carrega a chave do Pinecone.
    Esta função é chamada no início de cada função pública do serviço para garantir
    que os clientes estejam prontos, mas a inicialização real só ocorre uma vez.
    Levanta ValueError se as chaves API não estiverem configuradas/acessíveis como variáveis de ambiente
    (espera-se que sejam injetadas pelo Firebase Functions via parâmetro 'secrets' do decorator).
    """
    global _openai_client, _httpx_client, _pinecone_api_key_loaded

    # Inicializa cliente OpenAI
    if _openai_client is None:
        # O nome da variável de ambiente será o mesmo que você listou em 'secrets'
        # no decorator da função chamadora em main.py (ex: "openai-api-key")
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key:
            print("ERRO CRÍTICO (BibleSearchService): Variável de ambiente/secret 'openai-api-key' não configurada ou não acessível.")
            raise ValueError("Configuração da API OpenAI ausente (secret 'openai-api-key').")
        try:
            _openai_client = OpenAI(api_key=openai_api_key)
            print("Cliente OpenAI inicializado com sucesso para BibleSearchService.")
        except Exception as e_openai_init:
            print(f"ERRO CRÍTICO (BibleSearchService): Falha ao inicializar cliente OpenAI: {e_openai_init}")
            _openai_client = None # Garante que não será usado se a inicialização falhar
            raise # Relança a exceção para indicar falha na configuração

    # Inicializa cliente HTTPX
    if _httpx_client is None:
        try:
            _httpx_client = httpx.AsyncClient(timeout=30.0) # Timeout de 30s para requisições
            print("Cliente HTTPX inicializado com sucesso para BibleSearchService.")
        except Exception as e_httpx_init:
            print(f"ERRO CRÍTICO (BibleSearchService): Falha ao inicializar cliente HTTPX: {e_httpx_init}")
            _httpx_client = None
            raise

    # Carrega chave API do Pinecone
    if _pinecone_api_key_loaded is None:
        # O nome da variável de ambiente será o mesmo que você listou em 'secrets'
        _pinecone_api_key_loaded = os.environ.get("pinecone-api-key")
        if not _pinecone_api_key_loaded:
            print("ERRO CRÍTICO (BibleSearchService): Variável de ambiente/secret 'pinecone-api-key' não configurada ou não acessível.")
            raise ValueError("Configuração da API Pinecone ausente (secret 'pinecone-api-key').")
        print("Chave API do Pinecone carregada com sucesso para BibleSearchService via Secret Manager.")


async def generate_embedding_async(text_to_embed: str) -> list[float]:
    """Gera embedding para o texto usando OpenAI de forma assíncrona."""
    _initialize_clients() # Garante que os clientes estão inicializados antes de usar

    if not _openai_client:
        print("ERRO FATAL (generate_embedding_async): Cliente OpenAI não pôde ser inicializado.")
        raise ConnectionError("Falha na inicialização do cliente OpenAI.")

    if not text_to_embed or not isinstance(text_to_embed, str):
        print(f"ERRO (generate_embedding_async): Texto para embedding inválido ou vazio. Tipo: {type(text_to_embed)}")
        raise ValueError("Texto para embedding inválido ou vazio.")

    print(f"Gerando embedding para texto (primeiros 50 chars): '{text_to_embed[:50]}...'")
    try:
        # Executa a chamada síncrona da biblioteca OpenAI em um thread separado
        response = await asyncio.to_thread(
            _openai_client.embeddings.create, # Função a ser chamada
            model=EMBEDDING_MODEL,            # Argumentos nomeados para a função
            input=text_to_embed
        )
        if response.data and len(response.data) > 0 and hasattr(response.data[0], 'embedding') and response.data[0].embedding:
            embedding_vector = response.data[0].embedding
            print(f"Embedding gerado com sucesso (dimensões: {len(embedding_vector)}, primeiros 3 valores: {embedding_vector[:3]})")
            return embedding_vector
        else:
            # Este log pode ser extenso, considere truncar 'response' se necessário
            print(f"Resposta inesperada ou sem embedding da API OpenAI: {str(response)[:500]}")
            raise ValueError("Resposta da API de embedding OpenAI não contém dados de embedding válidos.")
    except Exception as e:
        print(f"Erro durante a geração de embedding com OpenAI: {e}")
        traceback.print_exc()
        # Considere levantar um tipo de erro mais específico se a biblioteca openai o fizer
        raise # Relança a exceção para ser tratada pela função chamadora

async def query_pinecone_async(vector: list[float], top_k: int, filters: dict | None = None) -> list[dict]:
    """Consulta o Pinecone de forma assíncrona."""
    _initialize_clients()

    if not _httpx_client:
        print("ERRO FATAL (query_pinecone_async): Cliente HTTPX não pôde ser inicializado.")
        raise ConnectionError("Falha na inicialização do cliente HTTPX.")
    if not _pinecone_api_key_loaded:
        print("ERRO FATAL (query_pinecone_async): Chave API do Pinecone não pôde ser carregada.")
        raise ConnectionError("Falha ao carregar configuração da API Pinecone.")

    if not vector or not isinstance(vector, list) or not all(isinstance(n, (int, float)) for n in vector):
        print(f"ERRO (query_pinecone_async): Vetor de query inválido. Tipo: {type(vector)}")
        raise ValueError("Vetor de query inválido.")
    if not isinstance(top_k, int) or top_k <= 0:
        print(f"AVISO (query_pinecone_async): top_k inválido ({top_k}), usando padrão 1.")
        top_k = 1 # Um valor padrão seguro para evitar erros

    request_url = f"{PINECONE_ENDPOINT}/query"
    headers = {
        "Api-Key": _pinecone_api_key_loaded,
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    payload: dict[str, any] = {
        "vector": vector,
        "topK": top_k,
        "includeMetadata": True,
        "includeValues": False
    }
    if filters and isinstance(filters, dict) and filters:
        payload["filter"] = filters
        print(f"Consultando Pinecone em {request_url} com filtros: {filters}")
    else:
        print(f"Consultando Pinecone em {request_url} sem filtros.")

    try:
        response = await _httpx_client.post(request_url, headers=headers, json=payload)
        response.raise_for_status() # Lança exceção para erros HTTP (4xx ou 5xx)
        result_data = response.json()
        matches = result_data.get("matches", [])
        if not isinstance(matches, list):
            print(f"AVISO (query_pinecone_async): 'matches' não é uma lista na resposta do Pinecone. Recebido: {type(matches)}")
            return []
        print(f"Consulta ao Pinecone bem-sucedida. Recebidos {len(matches)} resultados.")
        return matches
    except httpx.HTTPStatusError as e_http:
        error_message = f"Falha na comunicação com Pinecone (HTTP {e_http.response.status_code})."
        print(f"Erro HTTP ao consultar Pinecone: Status {e_http.response.status_code}")
        try:
            error_body = e_http.response.json()
            print(f"Corpo do erro do Pinecone (JSON): {error_body}")
            # Tenta extrair uma mensagem mais específica do erro, se disponível
            if isinstance(error_body, dict) and "message" in error_body:
                error_message += f" Detalhe: {error_body['message']}"
        except Exception:
            print(f"Corpo do erro do Pinecone (Texto): {e_http.response.text}")
        traceback.print_exc()
        raise ConnectionError(error_message) from e_http
    except httpx.RequestError as e_req: # Erros de rede, DNS, timeout
        print(f"Erro de requisição ao consultar Pinecone: {e_req}")
        traceback.print_exc()
        raise ConnectionError(f"Erro de rede ao conectar com Pinecone: {e_req}")
    except Exception as e_generic: # Outros erros (ex: JSONDecodeError se a resposta não for JSON)
        print(f"Erro inesperado durante a consulta ao Pinecone: {e_generic}")
        traceback.print_exc()
        raise Exception(f"Erro desconhecido ao consultar Pinecone: {e_generic}")


async def perform_semantic_search(user_query: str, filters: dict | None, top_k: int = 10) -> list[dict]:
    """
    Realiza a busca semântica: gera embedding da query e consulta o Pinecone.
    Levanta ValueError para inputs inválidos, ConnectionError para problemas de rede/API,
    e Exception para outros erros internos.
    """
    # A inicialização dos clientes agora é chamada dentro de generate_embedding_async e query_pinecone_async.
    # Não é necessário chamar _initialize_clients() aqui diretamente, pois as funções que dependem
    # dos clientes farão isso.

    if not user_query or not isinstance(user_query, str):
        print("ERRO (perform_semantic_search): A query do usuário é inválida ou vazia.")
        raise ValueError("A query do usuário não pode ser vazia.")
    if filters is not None and not isinstance(filters, dict):
        # É melhor tratar filtros malformados como um erro de argumento inválido.
        print(f"ERRO (perform_semantic_search): Filtros fornecidos não são um dicionário ({type(filters)}).")
        raise ValueError("Formato de filtros inválido.")
    if not isinstance(top_k, int) or top_k <= 0:
        print(f"AVISO (perform_semantic_search): top_k inválido ({top_k}), usando padrão 10.")
        top_k = 10

    print(f"Iniciando busca semântica para query (primeiros 100 chars): '{user_query[:100]}...' com filtros: {filters} e top_k: {top_k}")

    try:
        # Passo 1: Gerar embedding para a query do usuário
        query_vector = await generate_embedding_async(user_query)
        # Passo 2: Consultar o Pinecone com o vetor e filtros
        search_results = await query_pinecone_async(query_vector, top_k, filters)
        print(f"Busca semântica concluída com sucesso. {len(search_results)} resultados retornados do Pinecone.")
        return search_results
    except ValueError as ve:
        print(f"Erro de valor (ValueError) durante a busca semântica: {ve}")
        traceback.print_exc()
        raise # Relança para ser capturado pela Cloud Function
    except ConnectionError as ce:
        print(f"Erro de conexão (ConnectionError) durante a busca semântica: {ce}")
        traceback.print_exc()
        raise # Relança para ser capturado pela Cloud Function
    except Exception as e: # Captura outros erros inesperados
        print(f"Falha geral inesperada na busca semântica: {e}")
        traceback.print_exc()
        raise Exception(f"Erro interno no serviço de busca: {str(e)}")