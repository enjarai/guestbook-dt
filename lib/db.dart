import 'dart:io';

import 'package:endec/endec.dart';
import 'package:mysql_client/mysql_client.dart';
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
  final MySQLConnectionPool pool;

  MariaDbDataSource(this.pool);

  static Future<MariaDbDataSource> create() async {
    MySQLConnectionPool pool;
    while (true) {
      try {
        pool = MySQLConnectionPool(
          host: Platform.environment["DB_HOST"] ?? "localhost",
          port: int.parse(Platform.environment["DB_PORT"] ?? "3306"),
          userName: Platform.environment["DB_USER"] ?? "root",
          password: Platform.environment["DB_PASS"],
          databaseName: Platform.environment["DB_DB"],
          maxConnections: 4
        );
        await pool.execute("SELECT 1");
        break;
      } catch (e) {
        print(e);
        sleep(Duration(seconds: 2));
      }
    }

    await pool.execute("""
      CREATE TABLE IF NOT EXISTS posts (
        id UUID PRIMARY KEY,
        createdAt DATETIME NOT NULL,
        name VARCHAR(255) NOT NULL,
        website VARCHAR(255) NOT NULL,
        message TEXT NOT NULL
      )
    """);

    return MariaDbDataSource(pool);
  }

  Post toPost(ResultSetRow post) {
    return Post(
      post.typedColByName<String>("id")!,
      post.typedColByName<DateTime>("createdAt")!,
      post.typedColByName<String>("name")!,
      post.typedColByName<String>("website")!,
      post.typedColByName<String>("message")!
    );
  }

  @override
  Future<List<Post>> getAll() async {
    final result = await pool.execute("""
      SELECT * FROM posts
    """);

    return result.rows.map(toPost).toList();
  }

  @override
  Future<bool> postPost(Post post) async {
    final result = await pool.execute("""
      INSERT INTO posts (id, createdAt, name, website, message) VALUES (:id, :createdAt, :name, :website, :message)
    """, {
      "id": post.id, 
      "createdAt": post.createdAt, 
      "name": post.name, 
      "website": post.website, 
      "message": post.message
    });

    return result.affectedRows > BigInt.from(0);
  }

  @override
  Future<bool> deletePost(String uuid) async {
    final result = await pool.execute("""
      DELETE FROM posts WHERE id = :id
    """, {"id": uuid});

    return result.affectedRows > BigInt.from(0);
  }
}
