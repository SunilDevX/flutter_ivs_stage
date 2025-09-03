import 'package:flutter/material.dart';
import 'package:flutter_ivs_stage/flutter_ivs_stage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IVS Stage Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TokenSelectionPage(),
    );
  }
}

class TokenConfig {
  final String key;
  final String url;
  final String token;
  final String displayName;

  const TokenConfig({
    required this.key,
    required this.url,
    required this.token,
    required this.displayName,
  });
}

class TokenSelectionPage extends StatelessWidget {
  const TokenSelectionPage({super.key});

  static const List<TokenConfig> _tokenConfigs = [
    TokenConfig(
      key: "sk_us-east-1_u0AwAFbvFgns_RB85KQEnyoHTKc2Bc2eHIRQZYBMyes",
      url: "rtmps://7453a0e95db4.global-contribute.live-video.net:443/app/",
      token:
          "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjE3NTY5MjMxMTgsImlhdCI6MTc1NjcwNzExOCwianRpIjoiYTVYUzdzODNIaWdpIiwicmVzb3VyY2UiOiJhcm46YXdzOml2czp1cy1lYXN0LTE6NjU1NzU4MjM3OTc0OnN0YWdlL3VBVkRGZFNUeXRIRSIsInRvcGljIjoidUFWREZkU1R5dEhFIiwiZXZlbnRzX3VybCI6IndzczovL2dsb2JhbC5ldmVudHMubGl2ZS12aWRlby5uZXQiLCJ3aGlwX3VybCI6Imh0dHBzOi8vNzQ1M2EwZTk1ZGI0Lmdsb2JhbC1ibS53aGlwLmxpdmUtdmlkZW8ubmV0IiwidXNlcl9pZCI6Imd1ZXN0LTE3NTY3MDcxMTciLCJjYXBhYmlsaXRpZXMiOnsiYWxsb3dfcHVibGlzaCI6dHJ1ZSwiYWxsb3dfc3Vic2NyaWJlIjp0cnVlfSwidmVyc2lvbiI6IjAuMCJ9.MGYCMQCZxkZ53StQOz4StAA-gAu2NE8iYFuhOrFaAqIUXW8lMewqEBPI9mZwYxWgNJy7DAsCMQC8VlQUDiCNQHY1SGCuP321vlr2JxcIcY2mded-nugzdbfQ8CROoOzCOnX3-Juk7Fo",
      displayName: "Room 1",
    ),
    TokenConfig(
      key: "sk_us-east-1_RSL7QAIDuoWE_79iUJnsoDPLWBtg3n3FBDEfe4W1sAH",
      url: "rtmps://7453a0e95db4.global-contribute.live-video.net:443/app/",
      token:
          "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjE3NTY5MjMxNDEsImlhdCI6MTc1NjcwNzE0MSwianRpIjoiUGpKclZVNEVrcVRuIiwicmVzb3VyY2UiOiJhcm46YXdzOml2czp1cy1lYXN0LTE6NjU1NzU4MjM3OTc0OnN0YWdlL3VBVkRGZFNUeXRIRSIsInRvcGljIjoidUFWREZkU1R5dEhFIiwiZXZlbnRzX3VybCI6IndzczovL2dsb2JhbC5ldmVudHMubGl2ZS12aWRlby5uZXQiLCJ3aGlwX3VybCI6Imh0dHBzOi8vNzQ1M2EwZTk1ZGI0Lmdsb2JhbC1ibS53aGlwLmxpdmUtdmlkZW8ubmV0IiwidXNlcl9pZCI6Imd1ZXN0LTE3NTY3MDcxNDAiLCJjYXBhYmlsaXRpZXMiOnsiYWxsb3dfcHVibGlzaCI6dHJ1ZSwiYWxsb3dfc3Vic2NyaWJlIjp0cnVlfSwidmVyc2lvbiI6IjAuMCJ9.MGQCMDXgvX6LtdZY5Zqkt7QH9DMU65fTW8eWMS251dzy6AN9Pig26-xOBHOCCubPRKnO7AIwMFczEn8Eg91P9XlLTDbJdAW1tjllrIWS7YGZubt3DBI5M4Jx-m49GVej1OdYzCiL",
      displayName: "Room 2",
    ),
    TokenConfig(
      key: "sk_us-east-1_vLeJoSeVSWSK_Rp8caMzIUmB6j4Oa0Dd0Ldzde8otVi",
      url: "rtmps://7453a0e95db4.global-contribute.live-video.net:443/app/",
      token:
          "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjE3NTY5MjMxODIsImlhdCI6MTc1NjcwNzE4MiwianRpIjoibU1FNFI2M1lxU25iIiwicmVzb3VyY2UiOiJhcm46YXdzOml2czp1cy1lYXN0LTE6NjU1NzU4MjM3OTc0OnN0YWdlL3VBVkRGZFNUeXRIRSIsInRvcGljIjoidUFWREZkU1R5dEhFIiwiZXZlbnRzX3VybCI6IndzczovL2dsb2JhbC5ldmVudHMubGl2ZS12aWRlby5uZXQiLCJ3aGlwX3VybCI6Imh0dHBzOi8vNzQ1M2EwZTk1ZGI0Lmdsb2JhbC1ibS53aGlwLmxpdmUtdmlkZW8ubmV0IiwidXNlcl9pZCI6Imd1ZXN0LTE3NTY3MDcxODEiLCJjYXBhYmlsaXRpZXMiOnsiYWxsb3dfcHVibGlzaCI6dHJ1ZSwiYWxsb3dfc3Vic2NyaWJlIjp0cnVlfSwidmVyc2lvbiI6IjAuMCJ9.MGQCMA8HAvLy-LSbRHg02iKlmqSa-g_c0qO6YcxWpHHCyNNHg8ANgzyrcYELWdbY_0_jsQIwRD_KbYqjkEXOD2Uj4U_K4qNbpF-jChqkUCC9DQ6O2tRv9od17D1IIrAv70GQuoF6",
      displayName: "Room 3",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select Room'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.video_call, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Flutter IVS Stage Demo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose a room to join:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            ..._tokenConfigs.asMap().entries.map((entry) {
              final config = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyHomePage(tokenConfig: config),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.meeting_room),
                      const SizedBox(width: 12),
                      Text(
                        config.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 40),
            Text(
              'Tap any room to join the stage',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final TokenConfig tokenConfig;

  const MyHomePage({super.key, required this.tokenConfig});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.tokenConfig.displayName} - Flutter IVS Stage'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: StageView(
        initialToken: widget.tokenConfig.token,
        streamKey: widget.tokenConfig.key,
        streamUrl: widget.tokenConfig.url,
        showControls: true,
        backgroundColor: Colors.black,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
