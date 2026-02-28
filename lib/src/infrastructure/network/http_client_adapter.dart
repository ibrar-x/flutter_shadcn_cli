import 'package:http/http.dart' as http;

class HttpClientAdapter {
  final http.Client client;

  HttpClientAdapter({http.Client? client}) : client = client ?? http.Client();
}
