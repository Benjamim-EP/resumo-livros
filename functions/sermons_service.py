# functions/sermons_service.py
import os
import traceback
from openai import OpenAI
import httpx
import asyncio
from collections import defaultdict

# Reutilizar a configuração de clientes e as funções de embedding/query do Pinecone
# Idealmente, você poderia mover _initialize_clients, generate_embedding_async,
# e query_pinecone_async para um módulo compartilhado (ex: common_services.py)
# Mas por enquanto, vamos duplicá-las/adaptá-las aqui para manter o exemplo focado.

# --- Configuração (Copiar e adaptar de bible_search_service.py) ---
PINECONE_ENDPOINT_SPURGEON = "https://spurgeonsermoes-hqija7a.svc.aped-4627-b74a.pinecone.io" # SEU ENDPOINT DO PINECONE PARA SERMÕES
EMBEDDING_MODEL = "text-embedding-3-small" # Ou o modelo que você usou para indexar os sermões

_openai_client_sermons = None
_httpx_client_sermons = None
_pinecone_api_key_sermons_loaded = None



def _initialize_sermon_clients():
    global _openai_client_sermons, _httpx_client_sermons, _pinecone_api_key_sermons_loaded
    if _openai_client_sermons and _httpx_client_sermons and _pinecone_api_key_sermons_loaded:
        return # Já inicializado

    openai_api_key = os.environ.get("openai-api-key")
    if not openai_api_key:
        raise ValueError("Configuração da API OpenAI ausente (secret 'openai-api-key').")
    try:
        _openai_client_sermons = OpenAI(api_key=openai_api_key)
        print("Cliente OpenAI inicializado para SermonsService.")
    except Exception as e_openai_init:
        print(f"ERRO (SermonsService): Falha ao inicializar cliente OpenAI: {e_openai_init}")
        _openai_client_sermons = None
        raise

    if _httpx_client_sermons is None:
        try:
            _httpx_client_sermons = httpx.AsyncClient(timeout=30.0)
            print("Cliente HTTPX inicializado para SermonsService.")
        except Exception as e_httpx_init:
            print(f"ERRO (SermonsService): Falha ao inicializar cliente HTTPX: {e_httpx_init}")
            _httpx_client_sermons = None
            raise
    
    if _pinecone_api_key_sermons_loaded is None:
        _pinecone_api_key_sermons_loaded = os.environ.get("pinecone-api-key")
        if not _pinecone_api_key_sermons_loaded:
            raise ValueError("Configuração da API Pinecone ausente (secret 'pinecone-api-key').")
        print("Chave API do Pinecone carregada para SermonsService.")

async def _generate_sermon_embedding_async(text_to_embed: str) -> list[float]:
    _initialize_sermon_clients()
    if not _openai_client_sermons:
        raise ConnectionError("Falha na inicialização do cliente OpenAI para Sermons.")
    if not text_to_embed or not isinstance(text_to_embed, str):
        raise ValueError("Texto para embedding (sermão) inválido ou vazio.")
    try:
        response = await asyncio.to_thread(
            _openai_client_sermons.embeddings.create,
            model=EMBEDDING_MODEL,
            input=text_to_embed
        )
        if response.data and len(response.data) > 0 and hasattr(response.data[0], 'embedding') and response.data[0].embedding:
            return response.data[0].embedding
        else:
            raise ValueError("Resposta da API de embedding OpenAI (sermão) não contém dados válidos.")
    except Exception as e:
        print(f"Erro durante a geração de embedding (sermão): {e}")
        traceback.print_exc()
        raise

async def _query_pinecone_sermons_async(vector: list[float], top_k: int, filters: dict | None = None) -> list[dict]:
    _initialize_sermon_clients()
    
    # --- INÍCIO DA CORREÇÃO ---
    pinecone_api_key = _pinecone_api_key_sermons_loaded

    if not pinecone_api_key:
        raise ConnectionError("Falha ao carregar configuração da API Pinecone para Sermons.")

    request_url = f"{PINECONE_ENDPOINT_SPURGEON}/query"
    headers = {
        "Api-Key": pinecone_api_key,
        "Content-Type": "application/json", "Accept": "application/json"
    }
    payload: dict[str, any] = {
        "vector": vector, "topK": top_k,
        "includeMetadata": True, "includeValues": False
    }
    if filters: payload["filter"] = filters
    
    print(f"Consultando Pinecone (Sermões) em {request_url}...")

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(request_url, headers=headers, json=payload)
            response.raise_for_status()
            result_data = response.json()
            matches = result_data.get("matches", [])
            if not isinstance(matches, list): return []
            print(f"Consulta ao Pinecone (Sermões) bem-sucedida. {len(matches)} parágrafos encontrados.")
            return matches
        except httpx.HTTPStatusError as e_http:
            error_body_text = e_http.response.text
            print(f"Erro HTTP ao consultar Pinecone (Sermões): Status {e_http.response.status_code}, Corpo: {error_body_text}")
            raise ConnectionError(f"Falha na comunicação com Pinecone (Sermões).")
        except Exception as e_generic:
            print(f"Erro inesperado durante a consulta ao Pinecone (Sermões): {e_generic}")
            raise

def _extract_sermon_base_id(pinecone_id: str) -> str:
    """Extrai o ID base do sermão do ID do Pinecone (ex: sermon_1000_p25 -> sermon_1000)"""
    parts = pinecone_id.split('_p')
    return parts[0]

async def perform_sermon_semantic_search(user_query: str, top_k_paragraphs: int = 20, top_k_sermons: int = 5) -> list[dict]:
    """
    Realiza a busca semântica por sermões.
    Retorna uma lista de sermões agrupados, com os parágrafos relevantes e metadados.
    """
    if not user_query:
        raise ValueError("A query do usuário não pode ser vazia.")

    print(f"Iniciando busca semântica de sermões para query: '{user_query[:100]}...'")
    try:
        query_vector = await _generate_sermon_embedding_async(user_query)
        # Buscamos mais parágrafos inicialmente para ter uma boa chance de agrupar
        # sermões completos. top_k_paragraphs pode ser ajustado.
        paragraph_results = await _query_pinecone_sermons_async(query_vector, top_k_paragraphs)

        if not paragraph_results:
            print("Nenhum parágrafo encontrado no Pinecone para a query.")
            return []

        # Agrupar parágrafos por sermon_id_base
        sermons_map = defaultdict(lambda: {"sermon_id_base": "", "paragraphs": [], "total_score": 0.0, "max_score": 0.0, "metadata_sermon_level": {}})
        
        for para_match in paragraph_results:
            pinecone_id = para_match.get("id")
            score = para_match.get("score", 0.0)
            metadata = para_match.get("metadata", {})

            if not pinecone_id:
                print(f"AVISO: Parágrafo sem ID encontrado: {para_match}")
                continue

            sermon_id_base = metadata.get("sermon_id_base") # Deve ser igual a _extract_sermon_base_id(pinecone_id)
            if not sermon_id_base:
                 sermon_id_base = _extract_sermon_base_id(pinecone_id) # Fallback
                 print(f"AVISO: sermon_id_base não encontrado nos metadados para {pinecone_id}, derivado para {sermon_id_base}")


            sermon_entry = sermons_map[sermon_id_base]
            sermon_entry["sermon_id_base"] = sermon_id_base
            sermon_entry["paragraphs"].append({
                "pinecone_id": pinecone_id,
                "text_preview": metadata.get("text_preview", ""), # Ou o campo de conteúdo do parágrafo
                "score": score,
                "paragraph_order_in_sermon": metadata.get("paragraph_order_in_sermon")
            })
            sermon_entry["total_score"] += score
            if score > sermon_entry["max_score"]:
                sermon_entry["max_score"] = score
            
            # Pegar metadados do nível do sermão (deveriam ser os mesmos para todos os parágrafos do mesmo sermão)
            if not sermon_entry["metadata_sermon_level"]: # Pega apenas uma vez
                sermon_entry["metadata_sermon_level"] = {
                    "title_translated": metadata.get("sermon_title_translated", "Título não disponível"),
                    "title_original": metadata.get("sermon_title_original", ""),
                    "main_scripture_abbreviated": metadata.get("main_scripture_passage_abbreviated", ""),
                    "preacher": metadata.get("preacher", "C. H. Spurgeon")
                }
        
        # Ordenar os sermões pela pontuação máxima de um de seus parágrafos (ou pontuação total)
        # Usar max_score para priorizar sermões com pelo menos um parágrafo muito relevante.
        sorted_sermons = sorted(sermons_map.values(), key=lambda s: s["max_score"], reverse=True)

        # Limitar ao top_k_sermons
        final_sermons_list = []
        for sermon_data in sorted_sermons[:top_k_sermons]:
            # Ordenar os parágrafos dentro de cada sermão pela ordem original, se disponível
            if sermon_data["paragraphs"] and sermon_data["paragraphs"][0].get("paragraph_order_in_sermon") is not None:
                sermon_data["paragraphs"].sort(key=lambda p: p["paragraph_order_in_sermon"])
            
            final_sermons_list.append({
                "sermon_id_base": sermon_data["sermon_id_base"],
                "title_translated": sermon_data["metadata_sermon_level"]["title_translated"],
                "title_original": sermon_data["metadata_sermon_level"]["title_original"],
                "main_scripture_abbreviated": sermon_data["metadata_sermon_level"]["main_scripture_abbreviated"],
                "preacher": sermon_data["metadata_sermon_level"]["preacher"],
                "relevant_paragraphs": sermon_data["paragraphs"][:3], # Mostrar prévia dos 3 parágrafos mais relevantes ou os primeiros
                "relevance_score": sermon_data["max_score"] # Ou total_score / len(sermon_data["paragraphs"]) para uma média
            })

        print(f"Busca semântica de sermões retornando {len(final_sermons_list)} sermões agrupados.")
        return final_sermons_list

    except ValueError as ve:
        print(f"Erro de valor (ValueError) durante a busca de sermões: {ve}")
        raise
    except ConnectionError as ce:
        print(f"Erro de conexão (ConnectionError) durante a busca de sermões: {ce}")
        raise
    except Exception as e:
        print(f"Falha geral inesperada na busca de sermões: {e}")
        traceback.print_exc()
        raise Exception(f"Erro interno no serviço de busca de sermões: {str(e)}")