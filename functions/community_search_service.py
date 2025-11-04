# functions/community_search_service.py

import os
import traceback
from openai import OpenAI
import httpx
import asyncio
from datetime import datetime, timezone

# --- Configurações ---
PINECONE_ENDPOINT_COMMUNITY = "https://community-rooms-hqija7a.svc.aped-4627-b74a.pinecone.io"
EMBEDDING_MODEL = "text-embedding-3-small"

# Clientes globais para reutilização
_openai_client_community = None
_httpx_client_community = None
_pinecone_api_key_community_loaded = None

def _initialize_community_clients():
    """Inicializa os clientes de forma preguiçosa (lazy)."""
    global _openai_client_community, _httpx_client_community, _pinecone_api_key_community_loaded

    if _openai_client_community and _httpx_client_community and _pinecone_api_key_community_loaded:
        return

    # OpenAI
    if _openai_client_community is None:
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key:
            raise ValueError("Secret 'openai-api-key' não configurado.")
        _openai_client_community = OpenAI(api_key=openai_api_key)
        print("CommunitySearchService: Cliente OpenAI inicializado.")

    # HTTPX
    if _httpx_client_community is None:
        _httpx_client_community = httpx.AsyncClient(timeout=30.0)
        print("CommunitySearchService: Cliente HTTPX inicializado.")
    
    # Pinecone
    if _pinecone_api_key_community_loaded is None:
        _pinecone_api_key_community_loaded = os.environ.get("pinecone-api-key")
        if not _pinecone_api_key_community_loaded:
            raise ValueError("Secret 'pinecone-api-key' não configurado.")
        print("CommunitySearchService: Chave API do Pinecone carregada.")

async def generate_embedding_for_post_async(text_to_embed: str) -> list[float]:
    """Gera o embedding para o conteúdo de um post."""
    _initialize_community_clients()
    try:
        response = await asyncio.to_thread(
            _openai_client_community.embeddings.create,
            model=EMBEDDING_MODEL,
            input=text_to_embed
        )
        return response.data[0].embedding
    except Exception as e:
        print(f"CommunitySearchService: Erro na geração de embedding: {e}")
        raise

async def upsert_post_to_pinecone_async(post_id: str, vector: list[float], metadata: dict) -> None:
    """
    Insere ou atualiza (upsert) um vetor de post no índice Pinecone da comunidade.
    """
    _initialize_community_clients()
    
    request_url = f"{PINECONE_ENDPOINT_COMMUNITY}/vectors/upsert"
    headers = {
        "Api-Key": _pinecone_api_key_community_loaded,
        "Content-Type": "application/json"
    }
    payload = {
        "vectors": [
            {
                "id": post_id,
                "values": vector,
                "metadata": metadata
            }
        ]
    }
    
    print(f"CommunitySearchService: Enviando upsert para Pinecone para o ID: {post_id}")
    try:
        response = await _httpx_client_community.post(request_url, headers=headers, json=payload)
        response.raise_for_status()
        print(f"CommunitySearchService: Upsert para o ID {post_id} bem-sucedido.")
    except httpx.HTTPStatusError as e_http:
        print(f"CommunitySearchService: Erro HTTP no Pinecone: {e_http.response.text}")
        raise
    except Exception as e:
        print(f"CommunitySearchService: Erro na consulta ao Pinecone: {e}")
        raise

async def query_pinecone_community_async(vector: list[float], top_k: int) -> list[dict]:
    """
    Consulta o índice 'community-rooms' do Pinecone de forma assíncrona.
    """
    _initialize_community_clients()
    
    # --- INÍCIO DA CORREÇÃO ---
    pinecone_api_key = _pinecone_api_key_community_loaded

    if not pinecone_api_key:
        raise ConnectionError("Falha na inicialização dos clientes para consulta ao Pinecone.")

    request_url = f"{PINECONE_ENDPOINT_COMMUNITY}/query"
    headers = { "Api-Key": pinecone_api_key, "Content-Type": "application/json" }
    payload = {
        "vector": vector,
        "topK": top_k,
        "includeMetadata": True,
        "includeValues": False
    }
    
    print(f"CommunitySearchService: Consultando Pinecone com top_k={top_k}")
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(request_url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json().get("matches", [])
        except Exception as e:
            print(f"CommunitySearchService: Erro na consulta ao Pinecone: {e}")
            raise

async def perform_community_search_async(user_query: str, top_k: int = 20) -> list[dict]:
    """
    Orquestra a busca: gera embedding e consulta o Pinecone.
    """
    if not user_query:
        raise ValueError("A query do usuário não pode ser vazia.")
    
    try:
        query_vector = await generate_embedding_for_post_async(user_query)
        search_results = await query_pinecone_community_async(query_vector, top_k)
        
        # Formata os resultados para enviar de volta ao cliente
        formatted_results = []
        for match in search_results:
            metadata = match.get('metadata', {})
            formatted_results.append({
                "id": match.get('id'),
                "score": match.get('score'),
                "title": metadata.get("title"),
                "category": metadata.get("category"),
                "authorName": metadata.get("authorName"),
                "content_preview": metadata.get("content_preview"),
            })
        print('resultados formatados: ',formatted_results)
        return formatted_results
    except Exception as e:
        print(f"ERRO CRÍTICO em perform_community_search_async: {e}")
        traceback.print_exc()
        raise


async def delete_post_from_pinecone_async(post_id: str) -> None:
    """
    Deleta um vetor do índice Pinecone da comunidade pelo seu ID.
    """
    _initialize_community_clients()
    
    # O endpoint para deletar é diferente do de upsert/query
    request_url = f"{PINECONE_ENDPOINT_COMMUNITY}/vectors/delete"
    headers = {
        "Api-Key": _pinecone_api_key_community_loaded,
        "Content-Type": "application/json"
    }
    # O payload para deleção requer uma lista de IDs
    payload = {
        "ids": [post_id]
    }
    
    print(f"CommunitySearchService: Enviando DELETE para Pinecone para o ID: {post_id}")
    try:
        # A API de delete do Pinecone usa o método POST com um corpo específico
        response = await _httpx_client_community.post(request_url, headers=headers, json=payload)
        response.raise_for_status()
        print(f"CommunitySearchService: Delete para o ID {post_id} bem-sucedido.")
    except httpx.HTTPStatusError as e_http:
        # Em caso de erro, apenas logamos. A falha em deletar do Pinecone
        # não deve impedir a exclusão do post no Firestore.
        print(f"CommunitySearchService: Erro HTTP no delete do Pinecone: {e_http.response.text}")
    except Exception as e:
        print(f"CommunitySearchService: Erro na chamada de delete ao Pinecone: {e}")
