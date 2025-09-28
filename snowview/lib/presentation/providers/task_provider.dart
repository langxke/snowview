import 'package:flutter/foundation.dart';

class TaskItem {
	final String title;
	final bool completed;
	const TaskItem({required this.title, this.completed = false});
	TaskItem toggle() => TaskItem(title: title, completed: !completed);
}

class TaskProvider extends ChangeNotifier {
	final List<TaskItem> _items = <TaskItem>[];
	List<TaskItem> get items => List.unmodifiable(_items);

	void addTodo(String title) {
		_items.insert(0, TaskItem(title: title));
		notifyListeners();
	}

	void toggle(int index) {
		_items[index] = _items[index].toggle();
		notifyListeners();
	}

	void removeAt(int index) {
		_items.removeAt(index);
		notifyListeners();
	}
}
