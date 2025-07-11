# functions/bible_chat_service.py
import os
import traceback
import asyncio
import json
from openai import OpenAI
from firebase_admin import firestore

# --- Configurações ---
CHAT_MODEL = "gpt-4.1-nano"

_openai_client = None

def _initialize_clients():
    """Inicializa o cliente OpenAI de forma preguiçosa (lazy)."""
    global _openai_client
    if _openai_client is None:
        openai_api_key = os.environ.get("openai-api-key")
        if not openai_api_key:
            raise ValueError("Secret 'openai-api-key' não encontrado.")
        _openai_client = OpenAI(api_key=openai_api_key)
        print("BibleChatService: Cliente OpenAI inicializado.")

# --- Funções de Coleta de Contexto ---

async def _get_bible_verses_text(db, book_abbrev, chapter_number, verses_range_str):
    """Busca o texto dos versículos da NVI a partir do Firestore."""
    # Esta função é um placeholder. O ideal é que o texto seja enviado do cliente
    # para evitar uma leitura extra no DB. Mas se for necessário, a lógica seria:
    # 1. Montar o caminho para a coleção/documento dos versículos.
    # 2. Ler os versículos.
    # Por simplicidade, vamos assumir que o texto virá no payload da função no futuro.
    # Por enquanto, retornamos uma string indicando o que foi solicitado.
    print(f"Buscando texto para {book_abbrev} {chapter_number}:{verses_range_str}...")
    # Lógica de busca real no Firestore iria aqui.
    return f"Texto dos versículos de {book_abbrev} {chapter_number}:{verses_range_str}."


async def _get_matthew_henry_commentary(db, book_abbrev, chapter_number, verses_range_str):
    """Busca o comentário de Matthew Henry para a seção no Firestore."""
    # A ID do documento de comentário é construída da mesma forma que no app Flutter.
    safe_abbrev = 'jó' if book_abbrev.lower() == 'job' else book_abbrev
    commentary_doc_id = f"{safe_abbrev}_c{chapter_number}_v{verses_range_str}"
    print(f"Buscando comentário com ID: {commentary_doc_id}")
    try:
        doc_ref = db.collection('commentary_sections').document(commentary_doc_id)
        doc = await asyncio.to_thread(doc_ref.get)
        if doc.exists:
            data = doc.to_dict()
            commentary_list = data.get('commentary', [])
            # Concatena todos os parágrafos do comentário em um único texto.
            return "\n\n".join([item.get('traducao', item.get('original', '')) for item in commentary_list]).strip()
        return "Nenhum comentário de Matthew Henry encontrado para esta seção."
    except Exception as e:
        print(f"Erro ao buscar comentário de Matthew Henry: {e}")
        return "Erro ao carregar o comentário."


async def _get_strongs_knowledge(db, book_abbrev, chapter_number, verses_range_str):
    """
    Busca os dados do interlinear e do léxico para a seção.
    Esta é a parte mais complexa.
    """
    # Placeholder para a lógica complexa
    # 1. Determinar se é AT (Hebraico) ou NT (Grego)
    # 2. Construir o caminho para o arquivo JSON do interlinear do capítulo.
    # 3. Ler o arquivo (precisaria estar acessível para a Cloud Function, ex: no GCS).
    # 4. Filtrar os versículos relevantes da seção.
    # 5. Para cada palavra, pegar o número de Strong.
    # 6. Buscar a definição de cada número de Strong no Firestore (coleção do léxico).
    # 7. Formatar tudo em uma string legível.
    print("Buscando conhecimento de Strong (simulação)...")
    await asyncio.sleep(0.5) # Simula latência
    return "Análise do Léxico de Strong:\n- logos (G3056): Palavra, Verbo, algo dito.\n- agape (G26): Amor incondicional, benevolência."

def _build_bible_chat_prompt(
    user_query: str,
    bible_text_context: str,
    commentary_context: str,
    strongs_context: str | None,
    chat_history: list[dict] | None,
    use_strongs: bool
) -> list[dict]:
    """Constrói o prompt completo e contextualizado para o chat da Bíblia."""

    history_str = "\n".join([f"{'User' if msg['role'] == 'user' else 'AI'}: {msg['content']}" for msg in (chat_history or [])])

    # ✅ INSTRUÇÃO PRINCIPAL REFINADA
    system_instruction = f"""
Você é 'Septima AI', um assistente de exegese bíblica e estudo teológico. Sua personalidade é acadêmica, precisa e pastoral. Responda à pergunta do usuário utilizando as seguintes fontes de informação como base para sua análise.

--- CONTEXTO 1: TEXTO BÍBLICO (NVI) ---
{bible_text_context}

--- CONTEXTO 2: COMENTÁRIO DE MATTHEW HENRY ---
{commentary_context}
"""

    if strongs_context:
        system_instruction += f"""
--- CONTEXTO 3: ANÁLISE DO LÉXICO DE STRONG ---
{strongs_context}
"""

    system_instruction += """
--- FIM DO CONTEXTO ---

Instruções para a resposta:
1. Responda de forma detalhada, citando o texto bíblico, o comentário de Matthew Henry e a análise de Strong (se fornecida e relevante) para construir sua resposta.
2. Se o usuário fizer uma pergunta geral sobre o trecho (ex: "me explique esse trecho", "qual o significado etimológico?", "faça uma análise"), não peça para ele especificar uma palavra. Em vez disso, identifique proativamente as 2 ou 3 palavras ou conceitos teológicos mais importantes no CONTEXTO BÍBLICO e no CONTEXTO DE STRONG e forneça uma análise sobre eles.
3. Se a pergunta for muito vaga e não puder ser respondida com o contexto, peça educadamente por mais detalhes.
4. Seja sempre claro e didático.
"""
    
    # Monta a lista de mensagens final
    messages = [
        {"role": "system", "content": system_instruction}
    ]
    if history_str:
        messages.append({"role": "user", "content": f"Contexto da conversa anterior:\n{history_str}"})
    
    messages.append({"role": "user", "content": user_query})
    
    return messages

# --- Função Principal do Serviço ---
async def get_bible_chat_response(
    db, 
    user_query: str, 
    chat_history: list[dict] | None, 
    book_abbrev: str, 
    chapter_number: int, 
    verses_range_str: str, 
    use_strongs: bool
) -> str:
    _initialize_clients()
    
    # 1. Coleta de Contexto em Paralelo (sem alterações)
    print("Iniciando coleta de contexto...")
    context_tasks = [
        _get_bible_verses_text(db, book_abbrev, chapter_number, verses_range_str),
        _get_matthew_henry_commentary(db, book_abbrev, chapter_number, verses_range_str),
    ]
    if use_strongs:
        context_tasks.append(_get_strongs_knowledge(db, book_abbrev, chapter_number, verses_range_str))
        
    contexts = await asyncio.gather(*context_tasks)
    
    bible_text_context = contexts[0]
    commentary_context = contexts[1]
    strongs_context = contexts[2] if use_strongs else None

    # 2. Construção do Prompt usando a nova função
    prompt_messages = _build_bible_chat_prompt(
        user_query=user_query,
        bible_text_context=bible_text_context,
        commentary_context=commentary_context,
        strongs_context=strongs_context,
        chat_history=chat_history,
        use_strongs=use_strongs
    )

    # 3. Chamada à API da OpenAI (sem alterações)
    print("Enviando prompt completo para a OpenAI...")
    try:
        chat_completion = await asyncio.to_thread(
            _openai_client.chat.completions.create,
            model=CHAT_MODEL,
            messages=prompt_messages,
            temperature=0.5,
            max_tokens=1500,
        )
        ai_response = chat_completion.choices[0].message.content
        return ai_response.strip()

    except Exception as e:
        print(f"ERRO ao chamar a API da OpenAI: {e}")
        traceback.print_exc()
        raise Exception("Falha ao se comunicar com o assistente de IA.")