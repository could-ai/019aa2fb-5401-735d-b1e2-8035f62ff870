import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotifications();
  runApp(const MyApp());
}

Future<void> _initializeNotifications() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المخطط الإسلامي اليومي',
      debugShowCheckedModeBanner: false,
      textDirection: TextDirection.rtl,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'ArabicFont',
      ),
      home: const IslamicPlannerHome(),
    );
  }
}

class IslamicPlannerHome extends StatefulWidget {
  const IslamicPlannerHome({super.key});

  @override
  State<IslamicPlannerHome> createState() => _IslamicPlannerHomeState();
}

class _IslamicPlannerHomeState extends State<IslamicPlannerHome> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const PrayerTimesScreen(),
    const KinshipScreen(),
    const EisenhowerScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Opacity(
            opacity: 0.1,
            child: SvgPicture.asset(
              'assets/images/islamic_pattern.svg',
              fit: BoxFit.cover,
            ),
          ),
          _screens[_selectedIndex],
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'أوقات الصلاة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom),
            label: 'الصلة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task),
            label: 'المهام',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Map<String, dynamic>? _prayerTimes;
  String? _nextPrayer;
  Timer? _timer;
  bool _morningAdhkar = false;
  bool _eveningAdhkar = false;
  bool _quranWird = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchPrayerTimes();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morningAdhkar = prefs.getBool('morningAdhkar') ?? false;
      _eveningAdhkar = prefs.getBool('eveningAdhkar') ?? false;
      _quranWird = prefs.getBool('quranWird') ?? false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morningAdhkar', _morningAdhkar);
    await prefs.setBool('eveningAdhkar', _eveningAdhkar);
    await prefs.setBool('quranWird', _quranWird);
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final url = 'https://api.aladhan.com/v1/timings?latitude=${position.latitude}&longitude=${position.longitude}&method=2';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _prayerTimes = data['data']['timings'];
          _nextPrayer = _getNextPrayer(_prayerTimes!);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  String _getNextPrayer(Map<String, dynamic> timings) {
    final now = DateTime.now();
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (var prayer in prayers) {
      final time = _parseTime(timings[prayer]);
      if (time.isAfter(now)) {
        return prayer;
      }
    }
    return 'Fajr'; // Next day
  }

  DateTime _parseTime(String time) {
    final now = DateTime.now();
    final parts = time.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_prayerTimes != null) {
        final next = _getNextPrayer(_prayerTimes!);
        if (next != _nextPrayer) {
          setState(() {
            _nextPrayer = next;
          });
          _showNotification(_nextPrayer!);
        }
      }
    });
  }

  Future<void> _showNotification(String prayer) async {
    const androidDetails = AndroidNotificationDetails(
      'prayer_channel',
      'Prayer Times',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await FlutterLocalNotificationsPlugin().show(
      0,
      'وقت الصلاة',
      'حان وقت صلاة $prayer',
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوقات الصلاة'),
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
      body: _prayerTimes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_nextPrayer != null)
                  Container(
                    color: Colors.green.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'الصلاة التالية: $_nextPrayer',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _prayerTimes!.length,
                    itemBuilder: (context, index) {
                      final prayer = _prayerTimes!.keys.elementAt(index);
                      final time = _prayerTimes![prayer];
                      return ListTile(
                        title: Text(prayer),
                        trailing: Text(time),
                      );
                    },
                  ),
                ),
                const Divider(),
                CheckboxListTile(
                  title: const Text('أذكار الصباح'),
                  value: _morningAdhkar,
                  onChanged: (value) {
                    setState(() {
                      _morningAdhkar = value ?? false;
                    });
                    _saveData();
                  },
                ),
                CheckboxListTile(
                  title: const Text('أذكار المساء'),
                  value: _eveningAdhkar,
                  onChanged: (value) {
                    setState(() {
                      _eveningAdhkar = value ?? false;
                    });
                    _saveData();
                  },
                ),
                CheckboxListTile(
                  title: const Text('ورد القرآن'),
                  value: _quranWird,
                  onChanged: (value) {
                    setState(() {
                      _quranWird = value ?? false;
                    });
                    _saveData();
                  },
                ),
              ],
            ),
    );
  }
}

class KinshipScreen extends StatefulWidget {
  const KinshipScreen({super.key});

  @override
  State<KinshipScreen> createState() => _KinshipScreenState();
}

class _KinshipScreenState extends State<KinshipScreen> {
  bool _father = false;
  bool _mother = false;
  bool _brother = false;
  bool _sister = false;
  List<String> _extendedFamily = [];
  String? _todayCall;
  bool _todayChecked = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _father = prefs.getBool('father') ?? false;
      _mother = prefs.getBool('mother') ?? false;
      _brother = prefs.getBool('brother') ?? false;
      _sister = prefs.getBool('sister') ?? false;
      _extendedFamily = prefs.getStringList('extendedFamily') ?? [];
      _todayChecked = prefs.getBool('todayChecked') ?? false;
      _setTodayCall();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('father', _father);
    await prefs.setBool('mother', _mother);
    await prefs.setBool('brother', _brother);
    await prefs.setBool('sister', _sister);
    await prefs.setStringList('extendedFamily', _extendedFamily);
    await prefs.setBool('todayChecked', _todayChecked);
  }

  void _setTodayCall() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prefs = SharedPreferences.getInstance();
    final lastDate = prefs.then((p) => p.getString('lastDate'));
    lastDate.then((date) {
      if (date != today) {
        // Reset checkboxes
        setState(() {
          _father = false;
          _mother = false;
          _brother = false;
          _sister = false;
          _todayChecked = false;
        });
        _saveData();
        prefs.then((p) => p.setString('lastDate', today));
      }
      if (_extendedFamily.isNotEmpty) {
        final dayIndex = DateTime.now().day % _extendedFamily.length;
        setState(() {
          _todayCall = _extendedFamily[dayIndex];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صلة الرحم'),
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
      body: Column(
        children: [
          const Text('الأسرة المباشرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          CheckboxListTile(
            title: const Text('الأب'),
            value: _father,
            onChanged: (value) {
              setState(() {
                _father = value ?? false;
              });
              _saveData();
            },
          ),
          CheckboxListTile(
            title: const Text('الأم'),
            value: _mother,
            onChanged: (value) {
              setState(() {
                _mother = value ?? false;
              });
              _saveData();
            },
          ),
          CheckboxListTile(
            title: const Text('الأخ'),
            value: _brother,
            onChanged: (value) {
              setState(() {
                _brother = value ?? false;
              });
              _saveData();
            },
          ),
          CheckboxListTile(
            title: const Text('الأخت'),
            value: _sister,
            onChanged: (value) {
              setState(() {
                _sister = value ?? false;
              });
              _saveData();
            },
          ),
          const Divider(),
          if (_todayCall != null)
            Column(
              children: [
                Text('الاتصال اليومي: $_todayCall', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  title: const Text('تم الاتصال'),
                  value: _todayChecked,
                  onChanged: (value) {
                    setState(() {
                      _todayChecked = value ?? false;
                    });
                    _saveData();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class EisenhowerScreen extends StatefulWidget {
  const EisenhowerScreen({super.key});

  @override
  State<EisenhowerScreen> createState() => _EisenhowerScreenState();
}

class _EisenhowerScreenState extends State<EisenhowerScreen> {
  List<String> _urgentImportant = [];
  List<String> _importantNotUrgent = [];
  List<String> _urgentNotImportant = [];
  List<String> _notImportantNotUrgent = [];
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _startAlertTimer();
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urgentImportant = prefs.getStringList('urgentImportant') ?? [];
      _importantNotUrgent = prefs.getStringList('importantNotUrgent') ?? [];
      _urgentNotImportant = prefs.getStringList('urgentNotImportant') ?? [];
      _notImportantNotUrgent = prefs.getStringList('notImportantNotUrgent') ?? [];
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('urgentImportant', _urgentImportant);
    await prefs.setStringList('importantNotUrgent', _importantNotUrgent);
    await prefs.setStringList('urgentNotImportant', _urgentNotImportant);
    await prefs.setStringList('notImportantNotUrgent', _notImportantNotUrgent);
  }

  void _addTask(String task, int category) {
    setState(() {
      switch (category) {
        case 0:
          _urgentImportant.add(task);
          break;
        case 1:
          _importantNotUrgent.add(task);
          break;
        case 2:
          _urgentNotImportant.add(task);
          break;
        case 3:
          _notImportantNotUrgent.add(task);
          break;
      }
    });
    _saveTasks();
  }

  void _deleteTask(int category, int index) {
    setState(() {
      switch (category) {
        case 0:
          _urgentImportant.removeAt(index);
          break;
        case 1:
          _importantNotUrgent.removeAt(index);
          break;
        case 2:
          _urgentNotImportant.removeAt(index);
          break;
        case 3:
          _notImportantNotUrgent.removeAt(index);
          break;
      }
    });
    _saveTasks();
  }

  void _startAlertTimer() {
    _alertTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (_urgentImportant.isNotEmpty) {
        // Show alert
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تذكير'),
            content: const Text('لديك مهام عاجلة ومهمة غير مكتملة!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مصفوفة أيزنهاور'),
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          _buildQuadrant('عاجل ومهم', Colors.red.withOpacity(0.1), _urgentImportant, 0),
          _buildQuadrant('مهم وليس عاجل', Colors.blue.withOpacity(0.1), _importantNotUrgent, 1),
          _buildQuadrant('عاجل وليس مهم', Colors.yellow.withOpacity(0.1), _urgentNotImportant, 2),
          _buildQuadrant('ليس عاجل وليس مهم', Colors.grey.withOpacity(0.1), _notImportantNotUrgent, 3),
        ],
      ),
    );
  }

  Widget _buildQuadrant(String title, Color color, List<String> tasks, int category) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      color: color,
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(tasks[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTask(category, index),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _showAddTaskDialog(category);
            },
            child: const Text('إضافة مهمة'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(int category) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مهمة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'أدخل المهمة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addTask(controller.text, category);
                Navigator.of(context).pop();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _extendedFamily = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExtendedFamily();
  }

  Future<void> _loadExtendedFamily() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _extendedFamily = prefs.getStringList('extendedFamily') ?? [];
    });
  }

  Future<void> _saveExtendedFamily() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('extendedFamily', _extendedFamily);
  }

  void _addMember() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _extendedFamily.add(_controller.text);
        _controller.clear();
      });
      _saveExtendedFamily();
    }
  }

  void _removeMember(int index) {
    setState(() {
      _extendedFamily.removeAt(index);
    });
    _saveExtendedFamily();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
      body: Column(
        children: [
          const Text('إدارة الأسرة الممتدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'اسم العضو'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addMember,
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _extendedFamily.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_extendedFamily[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeMember(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
