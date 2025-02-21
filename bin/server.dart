import 'dart:convert';
import 'dart:io';

import 'package:endec/endec.dart';
import 'package:endec_json/endec_json.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:guestbook_dt/db.dart';

String moderatorPassword = Platform.environment["MOD_PASSWORD"]!;
late DataSource dataSource;

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..post('/post/create', _createPost)
  ..get('/post', _getPosts)
  ..delete('/post/<id>', _deletePost);

Response _rootHandler(Request req) {
  return Response.ok('meow! haiii!!!\n');
}

Future<Response> _createPost(Request request) async {
  final json = jsonDecode(await request.readAsString());
  final newPost = Post.createEndec.decode(SerializationContext(), JsonDeserializer(json));

  if (newPost.name.isEmpty || newPost.message.isEmpty) {
    return Response.badRequest();
  }

  try {
    if (await dataSource.postPost(newPost)) {
      return Response.ok('Ok!\n');
    } else {
      return Response.badRequest();
    }
  } catch (e) {
    return Response.badRequest(body: e.toString());
  }
}

Future<Response> _getPosts(Request request) async {
  final posts = await dataSource.getAll();
  posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final encodedPosts = posts.map((p) {
    final serializer = JsonSerializer();
    Post.endec.encode(SerializationContext(), serializer, p);
    return serializer.result;
  }).toList();

  return Response.ok(jsonEncode(encodedPosts), headers: {
    "Content-Type": "application/json"
  });
}

Future<Response> _deletePost(Request request) async {
  final id = request.params["id"]!;

  if (request.headers["auth"] != moderatorPassword) {
    return Response.unauthorized("Get out!\n");
  }

  try {
    if (await dataSource.deletePost(id)) {
      return Response.ok('Ok! Yay!\n');
    } else {
      return Response.badRequest();
    }
  } catch (e) {
    return Response.badRequest(body: e.toString());
  }
}

void main(List<String> args) async {
  dataSource = await MariaDbDataSource.create();

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler(_router.call);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
