import os

# Caminho da pasta atual (lib/)
lib_path = "."
# Nome do arquivo de saída
output_file = "codigo_concatenado.txt"

# Lista para armazenar os blocos de código
blocos_de_codigo = []

# Percorrer recursivamente a pasta lib/
for root, dirs, files in os.walk(lib_path):
    for file in files:
        if file.endswith(".dart"):
            # Caminho completo do arquivo
            file_path = os.path.join(root, file)
            # Caminho relativo ao diretório lib/
            relative_path = os.path.relpath(file_path, start=lib_path)
            # Leitura do conteúdo
            with open(file_path, "r", encoding="utf-8") as f:
                conteudo = f.read()
            # Formatar bloco
            bloco = (
                "#----------------------------------------#\n\n"
                f"#lib/{relative_path.replace(os.sep, '/')}\n\n"
                f"{conteudo}\n"
            )
            blocos_de_codigo.append(bloco)

# Escrever todos os blocos em um único arquivo
with open(output_file, "w", encoding="utf-8") as f_out:
    f_out.writelines(blocos_de_codigo)

print(f"Todos os arquivos foram concatenados em '{output_file}'.")
