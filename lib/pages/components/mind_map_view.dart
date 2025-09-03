// lib/pages/components/mind_map_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class MindMapView extends StatefulWidget {
  final Map<String, dynamic> mapData;
  const MindMapView({super.key, required this.mapData});

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  final Graph graph = Graph();
  late final SugiyamaAlgorithm _algorithm;
  final TransformationController _transformationController =
      TransformationController();
  Node? _focusedNode;

  @override
  void initState() {
    super.initState();
    _buildGraph();
    _setupAlgorithm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (graph.nodes.isNotEmpty) {
        _focusNode(graph.nodes.first);
      }
    });
  }

  void _buildGraph() {
    final List<dynamic> nodesJson = widget.mapData['nodes'] ?? [];
    final List<dynamic> edgesJson = widget.mapData['edges'] ?? [];
    for (var nodeJson in nodesJson) {
      graph.addNode(Node.Id(nodeJson['id']));
    }
    for (var edgeJson in edgesJson) {
      graph.addEdge(
        Node.Id(edgeJson['sourceId']),
        Node.Id(edgeJson['targetId']),
        paint: (edgeJson['style'] == 'dashed')
            ? (Paint()
              ..color = Colors.grey.shade600
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke)
            : null,
      );
    }
  }

  void _setupAlgorithm() {
    final config = SugiyamaConfiguration()
      ..nodeSeparation = 50
      ..levelSeparation = 75
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;

    _algorithm = SugiyamaAlgorithm(config);
  }

  void _centerOnNode(Node node) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = 400.0;
    final x = -node.x + (screenWidth / 2) - 50;
    final y = -node.y + (screenHeight / 2) - 25;
    final newMatrix = Matrix4.identity()
      ..translate(x, y)
      ..scale(1.0);
    _transformationController.value = newMatrix;
  }

  void _focusNode(Node node) {
    setState(() => _focusedNode = node);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _centerOnNode(node);
    });
  }

  void _navigateUp() {
    if (_focusedNode == null) return;
    final parentEdges = graph.getInEdges(_focusedNode!);
    if (parentEdges.isNotEmpty) {
      _focusNode(parentEdges.first.source);
    }
  }

  void _navigateDown() {
    if (_focusedNode == null) return;
    final children = graph.successorsOf(_focusedNode!);
    if (children.isNotEmpty) {
      _focusNode(children.first);
    }
  }

  void _navigateSibling({required bool next}) {
    if (_focusedNode == null) return;
    final parentEdges = graph.getInEdges(_focusedNode!);
    if (parentEdges.isEmpty) return;
    final parentNode = parentEdges.first.source;
    final siblings = graph.successorsOf(parentNode).toList();
    if (siblings.length <= 1) return;
    final currentIndex = siblings.indexOf(_focusedNode!);
    int newIndex = next
        ? (currentIndex + 1) % siblings.length
        : (currentIndex - 1 + siblings.length) % siblings.length;
    _focusNode(siblings[newIndex]);
  }

  Widget _buildNodeWidget(Node node) {
    // ... (esta função permanece a mesma)
    final nodesJson = widget.mapData['nodes'] ?? [];
    var nodeId = node.key!.value;
    var nodeJson =
        nodesJson.firstWhere((n) => n['id'] == nodeId, orElse: () => {});
    final bool isFocused = _focusedNode == node;
    final String label = nodeJson['label'] ?? '';
    final String type = nodeJson['type'] ?? 'detail_point';
    Color color;
    switch (type) {
      case 'main_topic':
        color = Colors.deepPurple.shade300;
        break;
      case 'category':
        color = Colors.grey.shade700;
        break;
      case 'sub_topic':
        color = Colors.blueGrey.shade600;
        break;
      default:
        color = Colors.teal.shade800;
        break;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.7),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // O InteractiveViewer já permite o zoom por gestos (pinch-to-zoom)
        InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 4.0,
          child: GraphView(
            graph: graph,
            algorithm: _algorithm,
            paint: Paint()
              ..color = Colors.grey
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke,
            builder: (Node node) {
              return _buildNodeWidget(node);
            },
          ),
        ),
        // ✅ BOTÕES DE ZOOM E CENTRALIZAR REMOVIDOS

        // Botões de Navegação (esquerda)
        Positioned(
          bottom: 10,
          left: 10,
          child: Row(
            children: [
              FloatingActionButton.small(
                  onPressed: () => _navigateSibling(next: false),
                  tooltip: 'Irmão Anterior',
                  child: const Icon(Icons.arrow_back)),
              const SizedBox(width: 8),
              Column(
                children: [
                  FloatingActionButton.small(
                      onPressed: _navigateUp,
                      tooltip: 'Ir para o Pai',
                      child: const Icon(Icons.arrow_upward)),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                      onPressed: _navigateDown,
                      tooltip: 'Ir para Filho',
                      child: const Icon(Icons.arrow_downward)),
                ],
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                  onPressed: () => _navigateSibling(next: true),
                  tooltip: 'Próximo Irmão',
                  child: const Icon(Icons.arrow_forward)),
            ],
          ),
        ),
      ],
    );
  }
}
