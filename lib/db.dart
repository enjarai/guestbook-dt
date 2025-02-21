import 'dart:io';

import 'package:endec/endec.dart';
import 'package:mysql1/mysql1.dart';
import 'package:uuid/uuid.dart';

Endec<DateTime> dateTimeEndec = Endec.string.xmap(DateTime.parse, (d) => d.toIso8601String());

class Post {
  static StructEndec<Post> endec = structEndec<Post>().with5Fields(
    Endec.string.fieldOf("id", (p) => p.id),
    dateTimeEndec.fieldOf("created_at", (p) => p.createdAt),
    Endec.string.fieldOf("name", (p) => p.name),
    Endec.string.fieldOf("website", (p) => p.website),
    Endec.string.fieldOf("message", (p) => p.message),
    Post.new
  );
  static StructEndec<Post> createEndec = structEndec<Post>().with3Fields(
    Endec.string.fieldOf("name", (p) => p.name),
    Endec.string.fieldOf("website", (p) => p.website),
    Endec.string.fieldOf("message", (p) => p.message),
    Post.create
  );

  final String id;
  final DateTime createdAt;
  final String name;
  final String website;
  final String message;
  
  Post(this.id, this.createdAt, this.name, this.website, this.message);
  Post.create(this.name, this.website, this.message) : 
    id = const Uuid().v4(), 
    createdAt = DateTime.now().toUtc();
}

abstract interface class DataSource {
  Future<List<Post>> getAll();

  Future<bool> postPost(Post post);

  Future<bool> deletePost(String uuid);
}

class MariaDbDataSource implements DataSource {
  final MySqlConnection conn;

  MariaDbDataSource(this.conn);

  static Future<MariaDbDataSource> create() async {
    MySqlConnection conn;
    while (true) {
      try {
        conn = await MySqlConnection.connect(ConnectionSettings(
          host: Platform.environment["DB_HOST"] ?? "localhost",
          port: int.parse(Platform.environment["DB_PORT"] ?? "3306"),
          user: Platform.environment["DB_USER"],
          password: Platform.environment["DB_PASS"],
          db: Platform.environment["DB_DB"]
        ));
        break;
      } catch (e) {
        print(e);
        sleep(Duration(seconds: 2));
      }
    }

    conn.query("""
      CREATE TABLE IF NOT EXISTS posts (
        id UUID PRIMARY KEY,
        createdAt DATETIME NOT NULL,
        name VARCHAR(255) NOT NULL,
        website VARCHAR(255) NOT NULL,
        message TEXT NOT NULL
      )
    """);

    return MariaDbDataSource(conn);
  }

  Post toPost(ResultRow post) {
    return Post(
      post["id"] as String,
      post["createdAt"] as DateTime,
      post["name"] as String,
      post["website"] as String,
      (post["message"] as Blob).toString()
    );
  }

  @override
  Future<List<Post>> getAll() async {
    final result = await conn.query("""
      SELECT * FROM posts
    """);

    return result.map(toPost).toList();
  }

  @override
  Future<bool> postPost(Post post) async {
    final result = await conn.query("""
      INSERT INTO posts (id, createdAt, name, website, message) VALUES (?, ?, ?, ?, ?)
    """, [post.id, post.createdAt, post.name, post.website, post.message]);

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePost(String uuid) async {
    final result = await conn.query("""
      DELETE FROM posts WHERE id = ?
    """, [uuid]);

    return (result.affectedRows ?? 0) > 0;
  }
}
