import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;

class DrcPreview extends StatefulWidget {
  static Set<String> imageFormats =
      Set.of(["webp", "bmp", "jpg", "png", "gif"]);
  static Set<String> videoFormats =
      debugDefaultTargetPlatformOverride == TargetPlatform.fuchsia
          ? Set.of([])
          : Set.of(["mp4", "3gp", "avi", "ogg", "mov"]);
  static Set<String> previewFormats = Set.from(imageFormats)
    ..addAll(videoFormats);

  final String name;
  final String url;
  const DrcPreview({Key key, this.name, this.url}) : super(key: key);

  @override
  _DrcPreviewState createState() => _DrcPreviewState();
}

class _DrcPreviewState extends State<DrcPreview> {
  ChewieController _controller;
  String ext;

  @override
  void initState() {
    super.initState();
    int indexOfDot = widget.name.lastIndexOf(".");
    if (indexOfDot == -1) {
      return;
    }
    ext = widget.name.substring(indexOfDot + 1);
    if (DrcPreview.videoFormats.contains(ext)) {
      var videoPlayerController = VideoPlayerController.network(widget.url)
        ..initialize().then((_) {
          // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
          setState(() {});
        });
      _controller = ChewieController(
        videoPlayerController: videoPlayerController,
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Text("不支持的文件格式");
    if (DrcPreview.imageFormats.contains(ext)) {
      content = Image.network(widget.url);
    } else if (DrcPreview.videoFormats.contains(ext)) {
      content = Chewie(controller: _controller);
    }

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${widget.name}"),
          actions: [],
        ),
        body: Center(child: content),
      ),
    );
  }

  @override
  void deactivate() {
    if (_controller != null) {
      _controller.pause();
    }
    super.deactivate();
  }
}
