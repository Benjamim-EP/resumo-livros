# functions/chat_service.py
import os
import traceback
import asyncio
from openai import OpenAI
import httpx # Garanta que httpx>=0.25.0 está nos seus requirements.txt

# Importa as funções de serviço do módulo de sermões
from sermons_service import (
    _initialize_sermon_clients,
    _generate_sermon_embedding_async,
    _query_pinecone_sermons_async,
)

# --- Configurações ---
# Usamos gpt-4.1-nano por ser rápido e barato, ideal para tarefas de roteamento e chat
CHAT_MODEL = "gpt-4.1-nano"
ROUTING_MODEL = "gpt-4.1-nano" 

# O número de parágrafos para buscar no Pinecone quando uma nova busca é necessária
MAX_CONTEXT_PARAGRAPHS = 30 


async def _route_user_query(user_query: str, chat_history: list[dict]) -> str:
    """
    Decide qual ferramenta usar com base na nova pergunta e no histórico da conversa.
    Retorna 'search_new_sermons' ou 'answer_from_history'.
    """
    
    # ✅ LÓGICA REFINADA: Verifica se há alguma mensagem do usuário no histórico.
    has_user_message_in_history = any(msg.get('role') == 'user' for msg in chat_history)

    if not has_user_message_in_history:
        # Se não há histórico ou se o histórico só tem mensagens do bot (como a de boas-vindas),
        # a única opção é buscar novos sermões.
        print("Agente de Roteamento: Sem interação prévia do usuário. Rota: search_new_sermons")
        return "search_new_sermons"

    # ... O resto da função permanece exatamente o mesmo ...
    # Formata o histórico para o prompt
    history_str = "\n".join([
        f"{'User' if msg['role'] == 'user' else 'AI'}: {msg.get('content', '...')}"
        for msg in chat_history[-4:] 
    ])

    system_prompt = f"""
Você é um agente roteador inteligente. Sua tarefa é analisar a última pergunta do usuário e o histórico da conversa para decidir qual ferramenta usar.

As ferramentas disponíveis são:
1. `search_new_sermons`: Use esta ferramenta se a pergunta do usuário introduz um novo tópico, um conceito teológico diferente, ou pede informações que provavelmente não estão no contexto da conversa atual. Exemplos: "E sobre a vida de oração?", "Qual a visão dele sobre escatologia?", "Fale sobre a santificação".
2. `answer_from_history`: Use esta ferramenta se a pergunta do usuário é uma continuação direta do último tópico discutido. Exemplos: "Como aplico isso na minha vida?", "Pode me dar um exemplo prático?", "Explique melhor esse ponto.", "Por quê?".

Histórico da Conversa Recente:
{history_str}

Última Pergunta do Usuário: "{user_query}"

Com base na última pergunta, qual ferramenta você deve usar? Responda APENAS com o nome da ferramenta (`search_new_sermons` ou `answer_from_history`).
"""
    
    print("Agente de Roteamento: Decidindo a rota para a query...")
    try:
        from sermons_service import _openai_client_sermons as openai_client
        
        response = await asyncio.to_thread(
            openai_client.chat.completions.create,
            model=ROUTING_MODEL,
            messages=[{"role": "user", "content": system_prompt}],
            temperature=0,
            max_tokens=10,
        )
        
        decision = response.choices[0].message.content.strip()
        print(f"Agente de Roteamento: Decisão -> {decision}")
        
        if decision in ["search_new_sermons", "answer_from_history"]:
            return decision
        else:
            print(f"Agente de Roteamento: Decisão inválida ('{decision}'). Usando 'search_new_sermons' como fallback.")
            return "search_new_sermons"

    except Exception as e:
        print(f"ERRO no Agente de Roteamento: {e}. Usando 'search_new_sermons' como fallback.")
        return "search_new_sermons"


async def _transform_query_with_history(user_query: str, chat_history: list[dict]) -> str:
    """
    Usa o LLM para reescrever a pergunta do usuário, incorporando o contexto do histórico,
    para que a busca semântica seja mais precisa.
    """
    if not chat_history:
        return user_query

    history_str = "\n".join([f"{'User' if msg['role'] == 'user' else 'AI'}: {msg['content']}" for msg in chat_history])
    prompt = f"""Given the following conversation history and a follow up question, rephrase the follow up question to be a standalone question that can be understood without the chat history, making it ideal for a semantic search.

Chat History:
{history_str}

Follow Up Input: {user_query}

Standalone question:"""
    
    print("Gerando query autônoma com base no histórico...")
    try:
        from sermons_service import _openai_client_sermons as openai_client
        response = await asyncio.to_thread(
            openai_client.chat.completions.create,
            model=ROUTING_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0,
            max_tokens=150,
        )
        standalone_query = response.choices[0].message.content.strip()
        print(f"Query original: '{user_query}' -> Query transformada: '{standalone_query}'")
        return standalone_query
    except Exception as e:
        print(f"ERRO ao transformar a query: {e}. Usando a query original.")
        return user_query


def _build_rag_prompt(user_query: str, retrieved_paragraphs: list[dict]) -> list[dict]:
    """Constrói o prompt para a geração da resposta usando o contexto recuperado (RAG)."""
    
    context_str = "\n\n---\n\n".join([
        f"Trecho do sermão '{p.get('metadata', {}).get('sermon_title_translated', 'desconhecido')}':\n{p.get('metadata', {}).get('text_preview', '')}"
        for p in retrieved_paragraphs
    ])
    
    system_message = {
        "role": "system",
        "content": f"""
Você é 'Spurgeon AI', um assistente teológico especialista nos sermões de Charles H. Spurgeon.
Sua personalidade é sábia, pastoral, eloquente e fiel aos ensinamentos de Spurgeon.
Responda à pergunta do usuário de forma completa e detalhada, utilizando múltiplos parágrafos se necessário para explicar bem o conceito.
Sua resposta deve ser estritamente baseada no CONTEXTO fornecido abaixo, que é uma coleção de parágrafos dos sermões de Spurgeon.
Sintetize as informações de diferentes parágrafos do contexto para formar uma resposta coesa e bem estruturada.
Se a resposta não estiver clara no contexto, diga educadamente: "Com base nos sermões que analisei, não encontrei uma resposta direta para sua pergunta."
Não invente informações e não use conhecimento externo.

--- CONTEXTO DOS SERMÕES ---
{context_str}
--- FIM DO CONTEXTO ---
"""
    }
    
    prompt_messages = [
        system_message,
        {"role": "user", "content": user_query}
    ]
    return prompt_messages


def _build_history_prompt(user_query: str, chat_history: list[dict]) -> list[dict]:
    """Constrói o prompt para responder usando apenas o histórico da conversa como contexto."""
    
    context_str = "\n\n".join([
        f"{'Usuário' if msg['role'] == 'user' else 'Sua Resposta Anterior'}: {msg.get('content', '...')}"
        for msg in chat_history[-6:] # Limita o contexto para economizar tokens e manter o foco
    ])

    system_message = {
        "role": "system",
        "content": f"""
Você é 'Spurgeon AI', um assistente teológico.
Responda à nova pergunta do usuário baseando-se no contexto da nossa conversa anterior fornecido abaixo.
Seja claro, pastoral e direto, continuando o raciocínio da conversa.

--- CONTEXTO DA CONVERSA ANTERIOR ---
{context_str}
--- FIM DO CONTEXTO ---
"""
    }
    
    prompt_messages = [
        system_message,
        {"role": "user", "content": user_query}
    ]
    return prompt_messages


async def get_rag_chat_response(user_query: str, chat_history: list[dict] | None = None) -> dict:
    """
    Orquestra o fluxo de chat completo, usando um agente para rotear a query,
    buscando novos dados ou respondendo a partir do histórico conforme necessário.
    """
    print(f"Chat RAG iniciado para a query original: '{user_query[:100]}...'")
    _initialize_sermon_clients()
    chat_history = chat_history or []
    
    # 1. Agente decide a rota
    route = await _route_user_query(user_query, chat_history)

    final_sources = []
    
    if route == "search_new_sermons":
        print("Executando rota: BUSCAR NOVOS SERMÕES")
        standalone_query = await _transform_query_with_history(user_query, chat_history)
        query_vector = await _generate_sermon_embedding_async(standalone_query)
        retrieved_paragraphs = await _query_pinecone_sermons_async(query_vector, MAX_CONTEXT_PARAGRAPHS)
        
        if not retrieved_paragraphs:
            return {"response": "Peço desculpas, mas não consegui encontrar sermões relevantes para este novo tópico.", "sources": []}
            
        prompt_messages = _build_rag_prompt(user_query, retrieved_paragraphs)
        final_sources = retrieved_paragraphs
    
    else: # Rota "answer_from_history"
        print("Executando rota: RESPONDER A PARTIR DO HISTÓRICO")
        prompt_messages = _build_history_prompt(user_query, chat_history)
        
        # ✅ LÓGICA DE BUSCA DE FONTES CORRIGIDA
        # Procura para trás no histórico pela última mensagem do bot que tenha fontes.
        for message in reversed(chat_history):
            if message.get("role") == "assistant" and message.get("sources"):
                final_sources = message.get("sources", [])
                print(f"Fontes encontradas no histórico: {len(final_sources)} fontes.")
                break # Para assim que encontrar as fontes mais recentes
        
    # 3. Geração da Resposta Final
    print("Enviando prompt final para o modelo de chat...")
    try:
        from sermons_service import _openai_client_sermons as openai_client
        chat_completion = await asyncio.to_thread(
            openai_client.chat.completions.create,
            model=CHAT_MODEL,
            messages=prompt_messages,
            temperature=0.5,
            max_tokens=1024,
        )
        ai_response = chat_completion.choices[0].message.content.strip()
        print(f"Resposta recebida da OpenAI. Tokens usados: {chat_completion.usage}")

        # 4. Formatação das fontes para a UI (lógica permanece a mesma)
        formatted_sources = []
        used_sermon_ids = set()
        for source_item in final_sources:
            sermon_id = None
            title = None
            
            if 'metadata' in source_item:
                metadata = source_item.get("metadata", {})
                sermon_id = metadata.get("sermon_id_base")
                title = metadata.get("sermon_title_translated", "Sermão Desconhecido")
            else:
                sermon_id = source_item.get("sermon_id")
                title = source_item.get("title", "Sermão Desconhecido")

            if sermon_id and sermon_id not in used_sermon_ids:
                formatted_sources.append({"sermon_id": sermon_id, "title": title})
                used_sermon_ids.add(sermon_id)
        
        return {"response": ai_response, "sources": formatted_sources}

    except Exception as e:
        print(f"ERRO CRÍTICO no fluxo final do chat: {e}")
        traceback.print_exc()
        raise Exception(f"Erro interno ao gerar a resposta: {str(e)}")