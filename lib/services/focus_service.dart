// 专注服务（番茄钟逻辑占位）
abstract class FocusService {
	Stream<Duration> startPomodoro({required Duration work, required Duration rest});
	void stop();
}
