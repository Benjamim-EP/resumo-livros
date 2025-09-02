// lib/pages/components/mind_map_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

// 1. Converter para StatefulWidget
class MindMapView extends StatefulWidget {
  final Map<String, dynamic> mapData;

  const MindMapView({super.key, required this.mapData});

  @override
  State<MindMapView> createState() => _MindMapViewWidgetState();
}

class _MindMapViewWidgetState extends State<MindMapView> {
  // 2. Criar o TransformationController
  final TransformationController _transformationController =
      TransformationController();

  // Função para dar zoom in
  void _zoomIn() {
    // Pega a matriz de transformação atual
    final currentMatrix = _transformationController.value;
    // Cria uma nova matriz que aplica uma escala de 1.2x
    final newMatrix = currentMatrix.clone()..scale(1.2);
    // Aplica a nova matriz
    _transformationController.value = newMatrix;
  }

  // Função para dar zoom out
  void _zoomOut() {
    final currentMatrix = _transformationController.value;
    final newMatrix = currentMatrix.clone()..scale(0.8);
    _transformationController.value = newMatrix;
  }

  // A função para construir os nós permanece a mesma
  Widget _buildNodeWidget(Map<String, dynamic> nodeJson) {
    final String label = nodeJson['label'] ?? '';
    final String type = nodeJson['type'] ?? 'detail_point';

    BoxDecoration decoration;
    TextStyle textStyle;

    switch (type) {
      case 'main_topic':
        decoration = BoxDecoration(
            color: Colors.deepPurple.shade300,
            borderRadius: BorderRadius.circular(20));
        textStyle =
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
        break;
      case 'category':
        decoration = BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(8));
        textStyle = const TextStyle(color: Colors.white);
        break;
      case 'sub_topic':
        decoration = BoxDecoration(
            color: Colors.blueGrey.shade600,
            borderRadius: BorderRadius.circular(12));
        textStyle = const TextStyle(color: Colors.white);
        break;
      default:
        decoration = BoxDecoration(
            color: Colors.teal.shade800,
            borderRadius: BorderRadius.circular(10));
        textStyle = const TextStyle(color: Colors.white, fontSize: 12);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: decoration,
      child: Text(label, style: textStyle, textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Graph graph = Graph();
    final List<dynamic> nodes = widget.mapData['nodes'] ?? [];
    final List<dynamic> edges = widget.mapData['edges'] ?? [];

    for (var nodeJson in nodes) {
      graph.addNode(Node.Id(nodeJson['id']));
    }

    for (var edgeJson in edges) {
      graph.addEdge(
        Node.Id(edgeJson['sourceId']),
        Node.Id(edgeJson['targetId']),
        paint: (edgeJson['style'] == 'dashed')
            ? (Paint()
              ..color = Colors.grey
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round)
            : null,
      );
    }

    // 3. Envolver tudo em um Stack para sobrepor os botões
    return Stack(
      children: [
        InteractiveViewer(
          // 4. Conectar o controlador
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 4.0,
          child: GraphView(
            graph: graph,
            algorithm: FruchtermanReingoldAlgorithm(iterations: 100),
            paint: Paint()
              ..color = Colors.grey
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke,
            builder: (Node node) {
              var nodeId = node.key!.value;
              var nodeJson =
                  nodes.firstWhere((n) => n['id'] == nodeId, orElse: () => {});
              return _buildNodeWidget(nodeJson);
            },
          ),
        ),
        // 5. Adicionar os botões de controle de zoom
        Positioned(
          bottom: 10,
          right: 10,
          child: Column(
            children: [
              FloatingActionButton.small(
                onPressed: _zoomIn,
                tooltip: 'Aproximar',
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                onPressed: _zoomOut,
                tooltip: 'Afastar',
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        )
      ],
    );
  }
}
