import 'package:face_input/models.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:face_input/face_input.dart' as face_input;
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MyPlayer extends StatefulWidget {
  const MyPlayer({super.key});

  @override
  State<MyPlayer> createState() => _MyPlayerState();
}

class _MyPlayerState extends State<MyPlayer> {
  double headAngle = 0.0;
  double headAngleStart = 0.0;
  double posStart = 0.0;
  int timeStart = 0;
  double pos = 0.0;
  bool isOnlyLeftOpened = false;
  double sensitivity = 1;

  late YoutubePlayerController _controller;
  late PlayerState _playerState;
  late YoutubeMetaData _videoMetaData;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void ylistener() {
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      setState(() {
        _playerState = _controller.value.playerState;
        _videoMetaData = _controller.metadata;
      });
    }
  }

  Future<void> init() async {
    // youtube video
    _controller = YoutubePlayerController(
      initialVideoId: YoutubePlayer.convertUrlToId(
          "https://www.youtube.com/watch?v=EUGZVX2b1TM")!,
      flags: const YoutubePlayerFlags(
        mute: false,
        autoPlay: true,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    )..addListener(ylistener);

    // permissions
    PermissionStatus cameraPermissionStatus;
    do {
      cameraPermissionStatus = await Permission.camera.request();
      if (cameraPermissionStatus == PermissionStatus.permanentlyDenied) {
        openAppSettings();
      }
    } while (cameraPermissionStatus != PermissionStatus.granted);

    // face input
    Stream<FaceState> stream = await face_input.create();
    stream.listen((event) {
      setState(() {
        final now = DateTime.now();
        headAngle = (event.headEulerAngleY + 40) / 80;
        headAngle = headAngle <= 0 ? 0 : headAngle;
        headAngle = headAngle > 1 ? 1 : headAngle;

        bool wasOnlyLeftOpened = isOnlyLeftOpened;
        bool isRightOpened = event.rightEyeOpenProbability > 0.5;
        bool isLeftOpened = event.leftEyeOpenProbability > 0.5;
        isOnlyLeftOpened = isLeftOpened;
        if (isRightOpened) {
          if (isOnlyLeftOpened) {
            if (!wasOnlyLeftOpened) {
              if (now.millisecondsSinceEpoch - timeStart < 500) {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              }
            }
          } else {
            if (wasOnlyLeftOpened) {
              headAngleStart = headAngle;
              posStart = pos;
              timeStart = now.millisecondsSinceEpoch;
            } else if (!_controller.value.isPlaying) {
              pos = posStart + sensitivity * (headAngle - headAngleStart);
              pos = pos <= 0 ? 0 : pos;
              pos = pos > 1 ? 1 : pos;
              _controller.seekTo(Duration(
                  milliseconds:
                      (_controller.metadata.duration.inMilliseconds * pos)
                          .toInt()));
              _controller.pause();
            }
          }
        }
      });
    }, onError: (error) {});
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.amber,
        controlsTimeOut: const Duration(seconds: 10000000000),
        progressColors: const ProgressBarColors(
          playedColor: Colors.amber,
          handleColor: Colors.amberAccent,
        ),
        onReady: () {
          _isPlayerReady = true;
        },
      ),
      builder: (context, player) {
        return player;
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Pauses video while navigating to next page.
    _controller.pause();
    super.deactivate();
  }
}
