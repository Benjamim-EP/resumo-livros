# functions/chat_service.py
import os
import traceback
from openai import OpenAI
import httpx
import asyncio

# Reutilizando as funções de inicialização e embedding do sermons_service
# Em um projeto maior, isso seria movido para um common_services.py
from sermons_service import (
    _initialize_sermon_clients,
    _generate_sermon_embedding_async,
    _query_pinecone_sermons_async
)

# --- Configurações do Chat ---
CHAT_MODEL = "gpt-4.1-nano" # O modelo que você escolheu
MAX_CONTEXT_PARAGRAPHS = 30 # O número de parágrafos para recuperar do Pinecone

def _build_rag_prompt(user_query: str, retrieved_paragraphs: list[dict], chat_history: list[dict] | None = None) -> list[dict]:
    """
    Constrói a lista de mensagens (prompt) para a API de Chat da OpenAI.
    """
    
    context_str = "\n\n---\n\n".join([
        f"Parágrafo do sermão '{p.get('metadata', {}).get('sermon_title_translated', 'desconhecido')}':\n{p.get('metadata', {}).get('text_preview', '')}"
        for p in retrieved_paragraphs
    ])
    
    history_str = ""
    if chat_history:
        for message in chat_history:
            role = "Usuário" if message.get('role') == 'user' else "Assistente"
            history_str += f"{role}: {message.get('content')}\n"

    # <<< MUDANÇA PRINCIPAL AQUI: PROMPT MAIS DETALHADO >>>
    system_message = {
        "role": "system",
        "content": f"""
Você é 'Spurgeon AI', um assistente teológico especialista nos sermões de Charles H. Spurgeon.
Sua personalidade é sábia, pastoral, eloquente e fiel aos ensinamentos de Spurgeon.
Responda à pergunta do usuário de forma completa e detalhada, utilizando múltiplos parágrafos se necessário para explicar bem o conceito.
Sua resposta deve ser estritamente baseada no CONTEXTO fornecido abaixo, que é uma coleção de parágrafos dos sermões de Spurgeon.
Sintetize as informações de diferentes parágrafos do contexto para formar uma resposta coesa e bem estruturada.
Se a resposta não estiver clara no contexto, diga educadamente: "Com base nos sermões que analisei, não encontrei uma resposta direta para sua pergunta."
Não invente informações.

--- CONTEXTO ---
{context_str}
--- FIM DO CONTEXTO ---
"""
    }
    
    # ... (o resto da função continua igual) ...
    prompt_messages = [system_message]
    if history_str:
        prompt_messages.append({
            "role": "user",
            "content": f"Aqui está o histórico da nossa conversa anterior para referência:\n\n{history_str}\n\nAgora, por favor, responda à minha nova pergunta de forma completa e detalhada."
        })
    prompt_messages.append({
        "role": "user",
        "content": user_query
    })
    
    return prompt_messages

async def _transform_query_with_history(user_query: str, chat_history: list[dict]) -> str:
    """
    Usa o LLM para reescrever a pergunta do usuário, incorporando o contexto do histórico.
    """
    if not chat_history:
        return user_query # Se não há histórico, não há o que transformar

    # Formata o histórico para o prompt de transformação
    history_str = "\n".join([
        f"{'User' if msg['role'] == 'user' else 'AI'}: {msg['content']}"
        for msg in chat_history
    ])

    prompt = f"""Given the following conversation history and a follow up question, rephrase the follow up question to be a standalone question that can be understood without the chat history.
    
Chat History:
{history_str}

Follow Up Input: {user_query}

Standalone question:"""

    print("Gerando query autônoma com base no histórico...")
    try:
        from sermons_service import _openai_client_sermons as openai_client
        
        response = await asyncio.to_thread(
            openai_client.chat.completions.create,
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0, # Queremos uma reescrita direta, sem criatividade
            max_tokens=100, # A query reescrita não precisa ser longa
        )
        
        standalone_query = response.choices[0].message.content.strip()
        print(f"Query original: '{user_query}' -> Query transformada: '{standalone_query}'")
        return standalone_query
    except Exception as e:
        print(f"ERRO ao transformar a query: {e}. Usando a query original como fallback.")
        return user_query # Em caso de erro, usa a query original


async def get_rag_chat_response(user_query: str, chat_history: list[dict] | None = None) -> dict:
    """
    Orquestra o fluxo RAG completo, agora com Query Transformation.
    """
    print(f"Chat RAG iniciado para a query original: '{user_query[:100]}...'")
    
    try:
        _initialize_sermon_clients()
        
        # <<< PASSO EXTRA: TRANSFORMAR A QUERY >>>
        standalone_query = await _transform_query_with_history(user_query, chat_history or [])
        
        # Etapa 1: Recuperação (Retrieval) - Usa a query transformada
        print("Gerando embedding para a query transformada...")
        query_vector = await _generate_sermon_embedding_async(standalone_query)
        
        print(f"Buscando {MAX_CONTEXT_PARAGRAPHS} parágrafos relevantes no Pinecone...")
        retrieved_paragraphs = await _query_pinecone_sermons_async(query_vector, MAX_CONTEXT_PARAGRAPHS)
        
        if not retrieved_paragraphs:
            return {
                "response": "Peço desculpas, mas não consegui encontrar sermões relevantes para responder à sua pergunta. Tente reformulá-la.",
                "sources": []
            }
            
        # Etapa 2: Geração Aumentada (Augmented Generation)
        print("Construindo o prompt final para o modelo de chat...")
        # Importante: O prompt final ainda usa a query ORIGINAL do usuário e o histórico completo,
        # para que a resposta da IA seja natural e direta para o que o usuário perguntou.
        prompt_messages = _build_rag_prompt(user_query, retrieved_paragraphs, chat_history)
        
        print(f"Enviando prompt para o modelo '{CHAT_MODEL}'...")
        from sermons_service import _openai_client_sermons as openai_client
        
        chat_completion = await asyncio.to_thread(
            openai_client.chat.completions.create,
            model=CHAT_MODEL,
            messages=prompt_messages,
            temperature=0.4,
            max_tokens=1024,
        )
        
        ai_response = chat_completion.choices[0].message.content
        print(f"Resposta recebida da OpenAI. Tokens usados: {chat_completion.usage}")

        # Etapa 3: Preparar as fontes para retornar à UI
        sources = []
        used_sermon_ids = set() # Para evitar fontes duplicadas
        for p in retrieved_paragraphs:
            metadata = p.get("metadata", {})
            sermon_id = metadata.get("sermon_id_base")
            if sermon_id and sermon_id not in used_sermon_ids:
                sources.append({
                    "sermon_id": sermon_id,
                    "title": metadata.get("sermon_title_translated", "Sermão Desconhecido"),
                    "main_scripture": metadata.get("main_scripture_passage_abbreviated", ""),
                    "text_preview": metadata.get("text_preview", "...")
                })
                used_sermon_ids.add(sermon_id)
        
        return {
            "response": ai_response.strip(),
            "sources": sources
        }

    except Exception as e:
        print(f"ERRO CRÍTICO no fluxo RAG: {e}")
        traceback.print_exc()
        raise Exception(f"Erro interno ao processar sua pergunta: {str(e)}")