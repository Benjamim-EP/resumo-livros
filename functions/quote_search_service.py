# functions/quote_search_service.py

import os
import traceback
from openai import OpenAI
import httpx
import asyncio

# --- Configurações ---
# !!! ATENÇÃO: Verifique se este é o endpoint correto do seu índice de FRASES !!!
PINECONE_ENDPOINT_QUOTES = "https://septima-quotes-hqija7a.svc.aped-4627-b74a.pinecone.io" 
EMBEDDING_MODEL = "text-embedding-3-small"

# Clientes globais
_openai_client_quotes = None
_pinecone_api_key_quotes_loaded = None

def _initialize_quote_clients():
    """Inicializa clientes de forma preguiçosa para a busca de frases."""
    global _openai_client_quotes, _pinecone_api_key_quotes_loaded

    if _openai_client_quotes and _pinecone_api_key_quotes_loaded:
        return

    if _openai_client_quotes is None:
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key:
            raise ValueError("Secret 'openai-api-key' não configurado.")
        _openai_client_quotes = OpenAI(api_key=openai_api_key)
        print("QuoteSearchService: Cliente OpenAI inicializado.")
    
    if _pinecone_api_key_quotes_loaded is None:
        _pinecone_api_key_quotes_loaded = os.environ.get("pinecone-api-key")
        if not _pinecone_api_key_quotes_loaded:
            raise ValueError("Secret 'pinecone-api-key' não configurado.")
        print("QuoteSearchService: Chave API do Pinecone carregada.")

async def _generate_embedding_async(text_to_embed: str) -> list[float]:
    _initialize_quote_clients()
    try:
        response = await asyncio.to_thread(
            _openai_client_quotes.embeddings.create,
            model=EMBEDDING_MODEL,
            input=text_to_embed
        )
        return response.data[0].embedding
    except Exception as e:
        print(f"QuoteSearchService: Erro na geração de embedding: {e}")
        raise

async def _query_pinecone_quotes_async(vector: list[float], top_k: int) -> list[dict]:
    _initialize_quote_clients()
    pinecone_api_key = _pinecone_api_key_quotes_loaded

    request_url = f"{PINECONE_ENDPOINT_QUOTES}/query"
    headers = { "Api-Key": pinecone_api_key, "Content-Type": "application/json" }
    payload = {
        "vector": vector, "topK": top_k,
        "includeMetadata": True, "includeValues": False
    }
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(request_url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json().get("matches", [])
        except Exception as e:
            print(f"QuoteSearchService: Erro na consulta ao Pinecone: {e}")
            raise

async def perform_quote_search_async(user_query: str, top_k: int = 30) -> list[dict]:
    """Orquestra a busca: gera embedding e consulta o Pinecone."""
    if not user_query:
        raise ValueError("A query do usuário não pode ser vazia.")
    
    try:
        print(f"QuoteSearchService: Buscando frases para a query: '{user_query}'")
        query_vector = await _generate_embedding_async(user_query)
        search_results = await _query_pinecone_quotes_async(query_vector, top_k)
        
        # Formata os resultados para enviar de volta ao cliente
        formatted_results = []
        for match in search_results:
            metadata = match.get('metadata', {})
            # Adiciona os campos que o QuoteCardWidget espera
            formatted_results.append({
                "id": match.get('id'),
                "text": metadata.get("text"),
                "author": metadata.get("author"),
                "book": metadata.get("book"),
                "likeCount": 0, # Valores padrão, já que não temos essa info no Pinecone
                "commentCount": 0,
                "likedBy": [],
            })
        
        return formatted_results
    except Exception as e:
        print(f"ERRO CRÍTICO em perform_quote_search_async: {e}")
        traceback.print_exc()
        raise