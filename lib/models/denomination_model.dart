// lib/models/denomination_model.dart

class Denomination {
  final int id;
  final String name;
  final String mainBranch; // ramo_principal
  final String path; // caminho
  final String memberCount; // numero_adeptos

  Denomination({
    required this.id,
    required this.name,
    required this.mainBranch,
    required this.path,
    required this.memberCount,
  });

  factory Denomination.fromJson(Map<String, dynamic> json) {
    return Denomination(
      id: json['id'] ?? 0,
      name: json['nome'] ?? 'Desconhecida',
      mainBranch: json['ramo_principal'] ?? 'N/A',
      path: json['caminho'] ?? 'N/A',
      memberCount: json['numero_adeptos'] ?? '0',
    );
  }
}
