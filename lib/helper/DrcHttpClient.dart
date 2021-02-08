import 'dart:convert';

import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:http/http.dart';

class DrcHttpClient extends BaseClient {
  final AuthManager auth;
  final GlobalConfig config;
  final Map<String, String> cachedTokens = Map();
  static Client _inner = Client();

  DrcHttpClient(this.auth, this.config);

  Future<StreamedResponse> send(BaseRequest request) async {
    String repository = request.headers['repository'];
    if (repository != null && cachedTokens.containsKey(repository)) {
      request.headers['Authorization'] = "Bearer ${cachedTokens[repository]}";
    }
    request.headers['user-agent'] = config.userAgent;
    StreamedResponse response = await _inner.send(request);
    if (response.statusCode == 401) {
      RegExpMatch challengeMatch = RegExp(
              '^Bearer realm="(?<server>.*?)",service="(?<service>.*?)"(,scope="(?<scope>.*?)"|)')
          .firstMatch(response.headers["www-authenticate"]);
      if (challengeMatch == null) {
        return null;
      }
      String challengeServer = challengeMatch.namedGroup("server");
      String challengeService = challengeMatch.namedGroup("service");
      String challengeScope = challengeMatch.namedGroup("scope");
      String challengeUrl;
      if (challengeScope == null) {
        challengeUrl = "$challengeServer?service=$challengeService";
      } else {
        challengeUrl =
            "$challengeServer?service=$challengeService&scope=$challengeScope";
      }
      String cretificate =
          config.repositoryCretificates[request.headers['repository']];
      Response challegeResponse;
      if (cretificate == null) {
        challegeResponse = await _inner
            .get(challengeUrl, headers: {"User-Agent": config.userAgent});
      } else {
        challegeResponse = await _inner.get(challengeUrl, headers: {
          "User-Agent": config.userAgent,
          "Authorization": "Basic $cretificate"
        });
      }
      if (challegeResponse.statusCode == 401) {
        throw PermissionDeniedException(config.currentRepository);
      }
      String token;
      if (challegeResponse.statusCode >= 200 &&
          challegeResponse.statusCode < 300) {
        Map<String, dynamic> resposeBody = json.decode(challegeResponse.body);
        if (resposeBody.containsKey("token")) {
          token = resposeBody["token"];
          cachedTokens[repository] = token;
        }
      } else {
        throw challegeResponse.statusCode;
      }
      request = _copyRequest(request);
      request.headers['Authorization'] = "Bearer $token";
      StreamedResponse retryResponse = await _inner.send(request);
      if (retryResponse.statusCode == 401) {
        throw PermissionDeniedException(config.currentRepository);
      }
      return retryResponse;
    }
    return response;
  }

  BaseRequest _copyRequest(BaseRequest request) {
    BaseRequest requestCopy;

    if (request is Request) {
      requestCopy = Request(request.method, request.url)
        ..encoding = request.encoding
        ..bodyBytes = request.bodyBytes;
    } else if (request is MultipartRequest) {
      requestCopy = MultipartRequest(request.method, request.url)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
    } else if (request is StreamedRequest) {
      throw Exception('copying streamed requests is not supported');
    } else {
      throw Exception('request type is unknown, cannot copy');
    }

    requestCopy
      ..persistentConnection = request.persistentConnection
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..headers.addAll(request.headers);

    return requestCopy;
  }
}
