import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecipeCameraImportPage extends StatefulWidget {
  const RecipeCameraImportPage({super.key, this.maxImages = 5});

  final int maxImages;

  @override
  State<RecipeCameraImportPage> createState() => _RecipeCameraImportPageState();
}

class _RecipeCameraImportPageState extends State<RecipeCameraImportPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeCamera;
  final List<String> _imagePaths = [];
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera = _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera = _startCamera();
      setState(() {});
    }
  }

  Future<void> _startCamera() async {
    setState(() => _error = null);
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller?.dispose();
      _controller = controller;
      await controller.initialize();
    } catch (_) {
      _error = 'Kamera konnte nicht geöffnet werden.';
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _imagePaths.length >= widget.maxImages) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      setState(() => _imagePaths.add(image.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto konnte nicht gespeichert werden.')),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _removeImage(int index) {
    setState(() => _imagePaths.removeAt(index));
  }

  void _finish() {
    context.pop<List<String>>(_imagePaths);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canCapture = _imagePaths.length < widget.maxImages && !_isCapturing;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${_imagePaths.length}/${widget.maxImages} Seiten'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _imagePaths.isEmpty ? null : _finish,
            child: const Text('Verarbeiten'),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeCamera,
        builder: (context, snapshot) {
          final controller = _controller;
          if (_error != null) {
            return _CameraError(message: _error!, onRetry: _retry);
          }
          if (snapshot.connectionState != ConnectionState.done ||
              controller == null ||
              !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
              Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 72,
                      child: _imagePaths.isEmpty
                          ? Center(
                              child: Text(
                                'Fotografiere eine oder mehrere Rezeptseiten.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imagePaths.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => _Thumb(
                                path: _imagePaths[index],
                                index: index,
                                onRemove: () => _removeImage(index),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => context.pop<List<String>>(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Abbrechen',
                        ),
                        const Spacer(),
                        SizedBox.square(
                          dimension: 72,
                          child: IconButton.filled(
                            onPressed: canCapture ? _capture : null,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white24,
                              foregroundColor: Colors.black,
                            ),
                            icon: _isCapturing
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded),
                            tooltip: 'Foto aufnehmen',
                          ),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: _imagePaths.isEmpty ? null : _finish,
                          icon: const Icon(Icons.check_rounded),
                          tooltip: 'Verarbeiten',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _retry() {
    _initializeCamera = _startCamera();
    setState(() {});
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.path,
    required this.index,
    required this.onRemove,
  });

  final String path;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(path),
            width: 56,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          left: 4,
          top: 4,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: Colors.black54,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.cancel_rounded),
            color: Colors.white,
            tooltip: 'Foto entfernen',
          ),
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nochmal versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
