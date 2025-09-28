// 存储服务（文件存储占位）
abstract class StorageService {
	Future<String> readText(String path);
	Future<void> writeText(String path, String content);
}
