import os

# Caminhos base
lib_path = "./lib"
test_path = "./test"
functions_path = "./functions"
output_file = "codigo_concatenado.txt"

# Função para ler e formatar arquivos recursivamente
def ler_arquivos_recursivamente(base_path, extensao):
    blocos = []
    for root, dirs, files in os.walk(base_path):
        for file in files:
            if file.endswith(extensao):
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, start=".")
                with open(file_path, "r", encoding="utf-8") as f:
                    conteudo = f.read()
                bloco = (
                    "#----------------------------------------#\n\n"
                    f"#{relative_path.replace(os.sep, '/')}\n\n"
                    f"{conteudo}\n"
                )
                blocos.append(bloco)
    return blocos

# Função para ler apenas arquivos da raiz da pasta (sem subpastas)
def ler_arquivos_somente_da_raiz(raiz, extensao):
    blocos = []
    for file in os.listdir(raiz):
        caminho_completo = os.path.join(raiz, file)
        if os.path.isfile(caminho_completo) and file.endswith(extensao):
            relative_path = os.path.relpath(caminho_completo, start=".")
            with open(caminho_completo, "r", encoding="utf-8") as f:
                conteudo = f.read()
            bloco = (
                "#----------------------------------------#\n\n"
                f"#{relative_path.replace(os.sep, '/')}\n\n"
                f"{conteudo}\n"
            )
            blocos.append(bloco)
    return blocos

# 1. Código Dart da pasta lib/
blocos_de_codigo = ler_arquivos_recursivamente(lib_path, ".dart")

# 2. Código Dart da pasta test/
testes = ler_arquivos_recursivamente(test_path, ".dart")
if testes:
    blocos_de_codigo.append("\n\n------ Testes ------\n\n")
    blocos_de_codigo.extend(testes)

# 3. Functions .py apenas da raiz de /functions/
if os.path.isdir(functions_path):
    functions = ler_arquivos_somente_da_raiz(functions_path, ".py")
    if functions:
        blocos_de_codigo.append("\n\n------ Functions ------\n\n")
        blocos_de_codigo.extend(functions)

# Escrever no arquivo
with open(output_file, "w", encoding="utf-8") as f_out:
    f_out.writelines(blocos_de_codigo)

print(f"Todos os arquivos foram concatenados em '{output_file}'.")
