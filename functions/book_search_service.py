# functions/book_search_service.py
import os
import traceback
from openai import OpenAI
import httpx
import asyncio

# --- Configurações ---
# Use o mesmo endpoint do Pinecone que você usou para indexar os livros.
# Supondo que seja o mesmo do seu serviço de busca bíblica.
# Se for um índice diferente, atualize o endpoint.
PINECONE_ENDPOINT_LIVROS = "https://livros-hqija7a.svc.aped-4627-b74a.pinecone.io"
EMBEDDING_MODEL = "text-embedding-3-small"
# Usamos o modelo mais barato e rápido para a justificativa, pois é uma tarefa simples.
CHAT_MODEL = "gpt-4.1-nano"

# Clientes globais para reutilização em invocações "quentes"
_openai_client_books = None
_httpx_client_books = None
_pinecone_api_key_books_loaded = None


def _initialize_book_clients():
    """Inicializa os clientes de forma preguiçosa (lazy)."""
    global _openai_client_books, _httpx_client_books, _pinecone_api_key_books_loaded

    if _openai_client_books and _httpx_client_books and _pinecone_api_key_books_loaded:
        return  # Já inicializado

    # Carrega a chave da OpenAI a partir dos secrets
    if _openai_client_books is None:
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key:
            raise ValueError("Secret 'openai-api-key' não configurado.")
        _openai_client_books = OpenAI(api_key=openai_api_key)
        print("BookSearchService: Cliente OpenAI inicializado.")

    # Inicializa o cliente HTTP para chamadas ao Pinecone
    if _httpx_client_books is None:
        _httpx_client_books = httpx.AsyncClient(timeout=30.0)
        print("BookSearchService: Cliente HTTPX inicializado.")
    
    # Carrega a chave do Pinecone a partir dos secrets
    if _pinecone_api_key_books_loaded is None:
        _pinecone_api_key_books_loaded = os.environ.get("pinecone-api-key")
        if not _pinecone_api_key_books_loaded:
            raise ValueError("Secret 'pinecone-api-key' não configurado.")
        print("BookSearchService: Chave API do Pinecone carregada.")


# Esta função pode ser importada de um módulo comum no futuro para evitar repetição
async def _generate_embedding_async(text_to_embed: str) -> list[float]:
    _initialize_book_clients()
    try:
        response = await asyncio.to_thread(
            _openai_client_books.embeddings.create,
            model=EMBEDDING_MODEL,
            input=text_to_embed
        )
        return response.data[0].embedding
    except Exception as e:
        print(f"BookSearchService: Erro na geração de embedding: {e}")
        raise


# Esta função também poderia ser compartilhada
async def _query_pinecone_async(vector: list[float], top_k: int) -> list[dict]:
    _initialize_book_clients()
    headers = { "Api-Key": _pinecone_api_key_books_loaded, "Content-Type": "application/json" }
    payload = { "vector": vector, "topK": top_k, "includeMetadata": True }
    
    try:
        response = await _httpx_client_books.post(f"{PINECONE_ENDPOINT_LIVROS}/query", headers=headers, json=payload)
        response.raise_for_status()
        return response.json().get("matches", [])
    except httpx.HTTPStatusError as e_http:
        print(f"BookSearchService: Erro HTTP no Pinecone: {e_http.response.text}")
        raise
    except Exception as e:
        print(f"BookSearchService: Erro na consulta ao Pinecone: {e}")
        raise


async def _generate_recommendation_reason(user_query: str, book_metadata: dict) -> str:
    print("Metadados do Livro para Justificativa:")
    print(book_metadata)
    
    """
    Usa a IA para criar uma justificativa do porquê o livro é recomendado.
    """
    _initialize_book_clients()
    
    # Monta o contexto com os dados do livro recuperados do Pinecone
    context = f"""
    Título do Livro: {book_metadata.get('titulo', 'N/A')}
    Autor: {book_metadata.get('autor', 'N/A')}
    Resumo: {book_metadata.get('resumo', 'N/A')}
    Aplicações Práticas: {book_metadata.get('aplicacoes', 'N/A')}
    Perfil do Leitor Ideal: {book_metadata.get('perfil_leitor', 'N/A')}
    """

    prompt = f"""
Você é um bibliotecário e conselheiro teológico experiente. Um usuário descreveu a seguinte situação ou necessidade: "{user_query}"

Com base no CONTEXTO do livro fornecido abaixo, escreva uma justificativa curta, pessoal e convincente (1-2 frases) explicando por que este livro específico é uma excelente recomendação para a situação do usuário. Comece a resposta diretamente, por exemplo: "Este livro é ideal para você porque..." ou "Para o momento que você está vivendo, esta obra oferece...". Evite frases genéricas.

--- CONTEXTO DO LIVRO ---
{context}
--- FIM DO CONTEXTO ---

Justificativa da Recomendação:
"""
    try:
        response = await asyncio.to_thread(
            _openai_client_books.chat.completions.create,
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7, # Um pouco de criatividade para uma resposta mais natural
            max_tokens=150,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"BookSearchService: Erro ao gerar justificativa para {book_metadata.get('titulo')}: {e}")
        # Retorna uma justificativa padrão em caso de erro na API do chat
        return "Este livro é altamente recomendado por tratar de temas profundos e relevantes relacionados à sua busca."


async def get_book_recommendations(user_query: str, top_k: int = 5) -> list[dict]:
    """
    Orquestra o processo completo: embedding, busca no Pinecone e geração de justificativas.
    """
    if not user_query:
        raise ValueError("A query do usuário não pode ser vazia.")

    print(f"BookSearchService: Iniciando busca de livros para a query: '{user_query}'")
    
    try:
        # 1. Gerar embedding para a query do usuário
        query_vector = await _generate_embedding_async(user_query)

        # 2. Buscar no Pinecone pelos livros mais similares
        search_results = await _query_pinecone_async(query_vector, top_k)
        print(f"BookSearchService: {len(search_results)} livros encontrados no Pinecone.")

        # 3. Preparar tarefas para gerar as justificativas em paralelo
        justification_tasks = []
        for match in search_results:
            metadata = match.get('metadata', {})
            # Adiciona a tarefa de geração à lista
            justification_tasks.append(_generate_recommendation_reason(user_query, metadata))

        # Executa todas as chamadas à API de chat para as justificativas concorrentemente
        justifications = await asyncio.gather(*justification_tasks)

        # 4. Montar a resposta final combinando os resultados da busca com as justificativas
        recommendations = []
        for i, match in enumerate(search_results):
            metadata = match.get('metadata', {})
            pinecone_id = match.get('id')
            recommendations.append({
                "book_id": pinecone_id,
                "titulo": metadata.get("titulo"),
                "autor": metadata.get("autor"),
                "cover": metadata.get("cover_principal"),
                "resumo": metadata.get("resumo"),
                "recommendation_reason": justifications[i], # A justificativa gerada pela IA
                "score": match.get("score")
            })

        print(f"BookSearchService: Recomendações finalizadas e prontas para retornar.", recommendations[0])
        return recommendations
        
    except Exception as e:
        print(f"ERRO CRÍTICO em get_book_recommendations: {e}")
        traceback.print_exc()
        # Relança a exceção para ser capturada pela Cloud Function em main.py
        raise