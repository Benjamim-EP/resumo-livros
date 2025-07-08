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
    
    # 1. Constrói a string de contexto com os parágrafos recuperados
    context_str = "\n\n---\n\n".join([
        f"Parágrafo do sermão '{p.get('metadata', {}).get('sermon_title_translated', 'desconhecido')}':\n{p.get('metadata', {}).get('text_preview', '')}"
        for p in retrieved_paragraphs
    ])
    
    # 2. Constrói o histórico da conversa formatado
    history_str = ""
    if chat_history:
        for message in chat_history:
            role = "Usuário" if message.get('role') == 'user' else "Assistente"
            history_str += f"{role}: {message.get('content')}\n"

    # 3. Mensagem do Sistema (System Message): Define o comportamento do AI
    system_message = {
        "role": "system",
        "content": f"""
Você é 'Spurgeon AI', um assistente teológico especialista nos sermões de Charles H. Spurgeon.
Sua personalidade é sábia, pastoral e fiel aos ensinamentos de Spurgeon.
Responda à pergunta do usuário estritamente com base no CONTEXTO fornecido abaixo.
O contexto é uma coleção de parágrafos dos sermões de Spurgeon.
Se a resposta não estiver clara no contexto, diga educadamente: "Com base nos sermões que analisei, não encontrei uma resposta direta para sua pergunta."
Não invente informações. Se possível, mencione o sermão de onde tirou a informação.

--- CONTEXTO ---
{context_str}
--- FIM DO CONTEXTO ---
"""
    }

    # 4. Monta o prompt final
    prompt_messages = [system_message]
    
    # Adiciona o histórico da conversa se existir
    if history_str:
        prompt_messages.append({
            "role": "user",
            "content": f"Aqui está o histórico da nossa conversa anterior para referência:\n\n{history_str}\n\nAgora, por favor, responda à minha nova pergunta."
        })

    # Adiciona a pergunta atual do usuário
    prompt_messages.append({
        "role": "user",
        "content": user_query
    })
    
    return prompt_messages


async def get_rag_chat_response(user_query: str, chat_history: list[dict] | None = None) -> dict:
    """
    Orquestra o fluxo RAG completo.
    1. Gera embedding da query.
    2. Busca parágrafos relevantes no Pinecone.
    3. Constrói o prompt.
    4. Chama o modelo de chat da OpenAI.
    5. Retorna a resposta e as fontes.
    """
    print(f"Chat RAG iniciado para a query: '{user_query[:100]}...'")
    
    try:
        # Inicializa clientes (OpenAI, Pinecone) - função reutilizada de sermons_service
        _initialize_sermon_clients()
        
        # Etapa 1: Recuperação (Retrieval)
        print("Gerando embedding para a query do usuário...")
        query_vector = await _generate_sermon_embedding_async(user_query)
        
        print(f"Buscando {MAX_CONTEXT_PARAGRAPHS} parágrafos relevantes no Pinecone...")
        retrieved_paragraphs = await _query_pinecone_sermons_async(query_vector, MAX_CONTEXT_PARAGRAPHS)
        
        if not retrieved_paragraphs:
            return {
                "response": "Peço desculpas, mas não consegui encontrar sermões relevantes para responder à sua pergunta. Tente reformulá-la.",
                "sources": []
            }
            
        # Etapa 2: Geração Aumentada (Augmented Generation)
        print("Construindo o prompt para o modelo de chat...")
        prompt_messages = _build_rag_prompt(user_query, retrieved_paragraphs, chat_history)
        
        print(f"Enviando prompt para o modelo '{CHAT_MODEL}'...")
        # Acesso direto ao cliente OpenAI inicializado em sermons_service
        from sermons_service import _openai_client_sermons as openai_client
        
        chat_completion = await asyncio.to_thread(
            openai_client.chat.completions.create,
            model=CHAT_MODEL,
            messages=prompt_messages,
            temperature=0.3, # Um valor mais baixo para respostas mais factuais
        )
        
        ai_response = chat_completion.choices[0].message.content
        print("Resposta recebida da OpenAI.")

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