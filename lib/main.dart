import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const XSilentApp());
}

// Translation helper for English, Hindi and Nepali
String translate(String selectedLang, String eng, String hin, String nep) {
  if (selectedLang == 'Hindi') return hin;
  if (selectedLang == 'Nepali') return nep;
  return eng;
}

// Root application widget
class XSilentApp extends StatefulWidget {
  const XSilentApp({super.key});

  @override
  State<XSilentApp> createState() => _XSilentAppState();
}

class _XSilentAppState extends State<XSilentApp> {
  // Currently selected language
  String _selectedLanguage = 'English';

  // Switch app language
  void _switchLanguage(String newLang) {
    setState(() => _selectedLanguage = newLang);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XSilent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1A1A2E),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0F3460),
          secondary: Color(0xFF00B4D8),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F3460),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F3460),
          selectedItemColor: Color(0xFF00B4D8),
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: AppNavigator(
        selectedLanguage: _selectedLanguage,
        onLanguageSwitch: _switchLanguage,
      ),
    );
  }
}

// Main navigation controller with bottom nav bar
class AppNavigator extends StatefulWidget {
  final String selectedLanguage;
  final Function(String) onLanguageSwitch;

  const AppNavigator({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSwitch,
  });

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  // Active tab index
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    // Define all app screens
    final appScreens = [
      DashboardScreen(selectedLanguage: widget.selectedLanguage),
      MeetingScheduler(selectedLanguage: widget.selectedLanguage),
      GlobalClockScreen(selectedLanguage: widget.selectedLanguage),
      PreferencesScreen(
        selectedLanguage: widget.selectedLanguage,
        onLanguageSwitch: widget.onLanguageSwitch,
      ),
    ];

    return Scaffold(
      body: appScreens[_activeTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeTab,
        onTap: (tabIndex) => setState(() => _activeTab = tabIndex),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: translate(
                widget.selectedLanguage, 'Home', 'होम', 'गृह'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.schedule),
            label: translate(widget.selectedLanguage,
                'Schedule', 'शेड्यूल', 'तालिका'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.public),
            label: translate(widget.selectedLanguage,
                'World Clock', 'विश्व घड़ी', 'विश्व घडी'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: translate(widget.selectedLanguage,
                'Settings', 'सेटिंग्स', 'सेटिङ्ग'),
          ),
        ],
      ),
    );
  }
}

// ==================== DASHBOARD SCREEN ====================
class DashboardScreen extends StatefulWidget {
  final String selectedLanguage;
  const DashboardScreen({super.key, required this.selectedLanguage});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Live clock variables
  String _liveTime = '';
  String _liveDate = '';
  bool _meetingRunning = false;
  String _runningMeetingName = '';
  // Track sent alerts to avoid duplicates
  final Set<String> _sentAlerts = {};

  @override
  void initState() {
    super.initState();
    _refreshClock();
    // Tick every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _refreshClock();
        await _scanMeetings();
        return true;
      }
      return false;
    });
  }

  // Refresh the live clock display
  void _refreshClock() {
    final nowTime = DateTime.now();
    setState(() {
      _liveTime = DateFormat('HH:mm:ss').format(nowTime);
      _liveDate = DateFormat('EEEE, MMM d yyyy').format(nowTime);
    });
  }

  // Scan saved meetings and trigger alerts
  Future<void> _scanMeetings() async {
    final storage = await SharedPreferences.getInstance();
    final String? savedData = storage.getString('meeting_list');
    if (savedData == null) return;

    final meetingList =
        List<Map<String, dynamic>>.from(json.decode(savedData));
    bool anyRunning = false;
    String runningName = '';

    for (int idx = 0; idx < meetingList.length; idx++) {
      final meeting = meetingList[idx];
      final nowTime = DateTime.now();

      // Calculate meeting start and end
      final meetingStart = DateTime(nowTime.year, nowTime.month,
          nowTime.day, meeting['fromHour'], meeting['fromMin']);
      final meetingEnd = DateTime(nowTime.year, nowTime.month,
          nowTime.day, meeting['toHour'], meeting['toMin']);

      // Minutes remaining until meeting starts
      final minsLeft = meetingStart.difference(nowTime).inMinutes;

      // Alert if meeting starts within 5 minutes
      final upcomingKey = 'upcoming_$idx';
      if (minsLeft >= 1 &&
          minsLeft <= 5 &&
          !_sentAlerts.contains(upcomingKey)) {
        _sentAlerts.add(upcomingKey);
        _triggerAlert(
          '⏰ Meeting Starting Soon!',
          '"${meeting['meetingTitle']}" starts in $minsLeft min',
          Colors.orange,
        );
      }

      // Check if meeting is currently running
      if (nowTime.isAfter(meetingStart) &&
          nowTime.isBefore(meetingEnd)) {
        anyRunning = true;
        runningName = meeting['meetingTitle'];

        // Alert when meeting goes active
        final runningKey = 'running_$idx';
        if (!_sentAlerts.contains(runningKey)) {
          _sentAlerts.add(runningKey);
          _triggerAlert(
            '🔇 Silent Mode Activated',
            '"${meeting['meetingTitle']}" is now active',
            const Color(0xFF00B4D8),
          );
        }
      }

      // Clear alert keys after meeting ends
      if (nowTime.isAfter(meetingEnd)) {
        _sentAlerts.remove('running_$idx');
        _sentAlerts.remove('upcoming_$idx');
      }
    }

    setState(() {
      _meetingRunning = anyRunning;
      _runningMeetingName = runningName;
    });
  }

  // Show floating alert banner
  void _triggerAlert(
      String alertTitle, String alertBody, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              alertTitle.contains('Silent')
                  ? Icons.volume_off
                  : Icons.alarm,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(alertTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text(alertBody,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.selectedLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          translate(
              lang, 'XSilent', 'एक्ससाइलेंट', 'एक्ससाइलेन्ट'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF00B4D8),
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // XSilent logo circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                    color: const Color(0xFF00B4D8), width: 3),
              ),
              child: const Icon(Icons.volume_off,
                  size: 50, color: Color(0xFF00B4D8)),
            ),
            const SizedBox(height: 30),

            // Live time display
            Text(
              _liveTime,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),

            // Live date display
            Text(_liveDate,
                style: const TextStyle(
                    fontSize: 16, color: Colors.white54)),
            const SizedBox(height: 40),

            // Meeting status display card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _meetingRunning
                    ? const Color(0xFF00B4D8).withOpacity(0.2)
                    : const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _meetingRunning
                      ? const Color(0xFF00B4D8)
                      : Colors.white24,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _meetingRunning
                        ? Icons.volume_off
                        : Icons.volume_up,
                    size: 40,
                    color: _meetingRunning
                        ? const Color(0xFF00B4D8)
                        : Colors.white54,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _meetingRunning
                        ? translate(
                            lang,
                            '🔇 Silent Mode ON — $_runningMeetingName',
                            '🔇 साइलेंट मोड चालू — $_runningMeetingName',
                            '🔇 साइलेन्ट मोड चालु — $_runningMeetingName',
                          )
                        : translate(
                            lang,
                            '🔔 No Active Meeting',
                            '🔔 कोई मीटिंग नहीं',
                            '🔔 कुनै बैठक छैन',
                          ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _meetingRunning
                          ? const Color(0xFF00B4D8)
                          : Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Alert status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_active,
                      color: Color(0xFF00B4D8), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    translate(lang, 'Alerts Enabled',
                        'सूचनाएं सक्रिय', 'सूचनाहरू सक्रिय'),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Helper tip text
            Text(
              translate(
                lang,
                'Go to Schedule tab to add meeting times',
                'मीटिंग समय जोड़ने के लिए शेड्यूल टैब पर जाएं',
                'बैठक समय थप्न तालिका ट्याबमा जानुहोस्',
              ),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MEETING SCHEDULER ====================
class MeetingScheduler extends StatefulWidget {
  final String selectedLanguage;
  const MeetingScheduler(
      {super.key, required this.selectedLanguage});

  @override
  State<MeetingScheduler> createState() => _MeetingSchedulerState();
}

class _MeetingSchedulerState extends State<MeetingScheduler> {
  // List of saved meeting entries
  List<Map<String, dynamic>> _meetingEntries = [];
  final TextEditingController _meetingNameInput =
      TextEditingController();
  TimeOfDay _fromTime = TimeOfDay.now();
  TimeOfDay _toTime = TimeOfDay.now();
  String _silenceType = 'Silent';

  @override
  void initState() {
    super.initState();
    _fetchMeetings();
  }

  // Fetch meetings from local JSON storage
  Future<void> _fetchMeetings() async {
    final storage = await SharedPreferences.getInstance();
    final String? savedData = storage.getString('meeting_list');
    if (savedData != null) {
      setState(() {
        _meetingEntries =
            List<Map<String, dynamic>>.from(json.decode(savedData));
      });
    }
  }

  // Persist meetings to local JSON storage
  Future<void> _persistMeetings() async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString(
        'meeting_list', json.encode(_meetingEntries));
  }

  // Save new meeting entry
  Future<void> _saveMeetingEntry() async {
    if (_meetingNameInput.text.isEmpty) return;
    setState(() {
      _meetingEntries.add({
        'meetingTitle': _meetingNameInput.text,
        'fromHour': _fromTime.hour,
        'fromMin': _fromTime.minute,
        'toHour': _toTime.hour,
        'toMin': _toTime.minute,
        'silenceType': _silenceType,
        'isEnabled': true,
      });
    });
    await _persistMeetings();
    _meetingNameInput.clear();
    Navigator.pop(context);
  }

  // Remove a meeting entry by position
  Future<void> _removeMeetingEntry(int position) async {
    setState(() => _meetingEntries.removeAt(position));
    await _persistMeetings();
  }

  // Open new meeting dialog
  void _openAddMeetingDialog() {
    final lang = widget.selectedLanguage;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0F3460),
          title: Text(
            translate(lang, 'Add New Meeting',
                'नई मीटिंग जोड़ें', 'नयाँ बैठक थप्नुहोस्'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Meeting name text field
              TextField(
                controller: _meetingNameInput,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: translate(lang, 'Meeting Name',
                      'मीटिंग का नाम', 'बैठकको नाम'),
                  labelStyle:
                      const TextStyle(color: Colors.white54),
                  enabledBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Color(0xFF00B4D8)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // From time selector
              ListTile(
                title: Text(
                  translate(lang, 'From', 'शुरू', 'देखि'),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(_fromTime.format(context),
                    style: const TextStyle(
                        color: Color(0xFF00B4D8))),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: context,
                      initialTime: _fromTime);
                  if (picked != null) {
                    refreshDialog(() => _fromTime = picked);
                  }
                },
              ),

              // To time selector
              ListTile(
                title: Text(
                  translate(lang, 'To', 'अंत', 'सम्म'),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(_toTime.format(context),
                    style: const TextStyle(
                        color: Color(0xFF00B4D8))),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: context,
                      initialTime: _toTime);
                  if (picked != null) {
                    refreshDialog(() => _toTime = picked);
                  }
                },
              ),

              // Silence type selector buttons
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: ['Silent', 'Vibrate'].map((type) {
                  final btnLabel = type == 'Silent'
                      ? translate(lang, 'Silent', 'साइलेंट',
                          'साइलेन्ट')
                      : translate(lang, 'Vibrate', 'वाइब्रेट',
                          'भाइब्रेट');
                  return GestureDetector(
                    onTap: () =>
                        refreshDialog(() => _silenceType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _silenceType == type
                            ? const Color(0xFF00B4D8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF00B4D8)),
                      ),
                      child: Text(btnLabel,
                          style: const TextStyle(
                              color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                translate(lang, 'Cancel', 'रद्द करें',
                    'रद्द गर्नुहोस्'),
                style:
                    const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8)),
              onPressed: _saveMeetingEntry,
              child: Text(translate(
                  lang, 'Save', 'सहेजें', 'सुरक्षित गर्नुहोस्')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.selectedLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(translate(lang, 'My Meetings',
            'मेरी मीटिंग्स', 'मेरा बैठकहरू')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00B4D8),
        onPressed: _openAddMeetingDialog,
        child: const Icon(Icons.add),
      ),
      body: _meetingEntries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy,
                      size: 80, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    translate(
                      lang,
                      'No meetings added yet.\nTap + to add one.',
                      'कोई मीटिंग नहीं।\n+ दबाएं।',
                      'कुनै बैठक छैन।\n+ थिच्नुहोस्।',
                    ),
                    style:
                        const TextStyle(color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _meetingEntries.length,
              itemBuilder: (context, position) {
                final entry = _meetingEntries[position];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      // Silence type icon
                      Icon(
                        entry['silenceType'] == 'Silent'
                            ? Icons.volume_off
                            : Icons.vibration,
                        color: const Color(0xFF00B4D8),
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // Meeting name
                            Text(entry['meetingTitle'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                )),
                            // Time range
                            Text(
                              '${entry['fromHour'].toString().padLeft(2, '0')}:${entry['fromMin'].toString().padLeft(2, '0')} — ${entry['toHour'].toString().padLeft(2, '0')}:${entry['toMin'].toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: Color(0xFF00B4D8),
                                  fontSize: 14),
                            ),
                            // Silence type label
                            Text(entry['silenceType'],
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      // Remove meeting button
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () =>
                            _removeMeetingEntry(position),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ==================== GLOBAL CLOCK SCREEN ====================
class GlobalClockScreen extends StatefulWidget {
  final String selectedLanguage;
  const GlobalClockScreen(
      {super.key, required this.selectedLanguage});

  @override
  State<GlobalClockScreen> createState() =>
      _GlobalClockScreenState();
}

class _GlobalClockScreenState extends State<GlobalClockScreen> {
  // Global city data with translations and UTC offsets
  final List<Map<String, dynamic>> _cityList = [
    {
      'cityEng': 'Sydney',
      'cityHin': 'सिडनी',
      'cityNep': 'सिड्नी',
      'utcOffset': 11
    },
    {
      'cityEng': 'Kathmandu',
      'cityHin': 'काठमांडू',
      'cityNep': 'काठमाडौं',
      'utcOffset': 6
    },
    {
      'cityEng': 'Tokyo',
      'cityHin': 'टोक्यो',
      'cityNep': 'टोकियो',
      'utcOffset': 9
    },
    {
      'cityEng': 'Dubai',
      'cityHin': 'दुबई',
      'cityNep': 'दुबई',
      'utcOffset': 4
    },
    {
      'cityEng': 'London',
      'cityHin': 'लंदन',
      'cityNep': 'लन्डन',
      'utcOffset': 0
    },
    {
      'cityEng': 'New York',
      'cityHin': 'न्यू यॉर्क',
      'cityNep': 'न्यु योर्क',
      'utcOffset': -5
    },
    {
      'cityEng': 'Los Angeles',
      'cityHin': 'लॉस एंजेलिस',
      'cityNep': 'लस एन्जलस',
      'utcOffset': -8
    },
    {
      'cityEng': 'Singapore',
      'cityHin': 'सिंगापुर',
      'cityNep': 'सिंगापुर',
      'utcOffset': 8
    },
  ];

  @override
  void initState() {
    super.initState();
    // Refresh clocks every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {});
        return true;
      }
      return false;
    });
  }

  // Calculate city time from UTC offset
  String _calculateCityTime(int utcOffset) {
    return DateFormat('HH:mm:ss').format(
        DateTime.now().toUtc().add(Duration(hours: utcOffset)));
  }

  // Calculate city date from UTC offset
  String _calculateCityDate(int utcOffset) {
    return DateFormat('MMM d').format(
        DateTime.now().toUtc().add(Duration(hours: utcOffset)));
  }

  // Get city display name based on language
  String _getCityDisplayName(
      Map<String, dynamic> cityData, String lang) {
    if (lang == 'Hindi') return cityData['cityHin'];
    if (lang == 'Nepali') return cityData['cityNep'];
    return cityData['cityEng'];
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.selectedLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(translate(
            lang, 'World Clock', 'विश्व घड़ी', 'विश्व घडी')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cityList.length,
        itemBuilder: (context, idx) {
          final cityData = _cityList[idx];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // City name
                    Text(
                      _getCityDisplayName(cityData, lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // UTC offset label
                    Text(
                      'UTC ${cityData['utcOffset'] >= 0 ? '+' : ''}${cityData['utcOffset']}',
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Live city time
                    Text(
                      _calculateCityTime(
                          cityData['utcOffset']),
                      style: const TextStyle(
                        color: Color(0xFF00B4D8),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    // City date
                    Text(
                      _calculateCityDate(
                          cityData['utcOffset']),
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== PREFERENCES SCREEN ====================
class PreferencesScreen extends StatefulWidget {
  final String selectedLanguage;
  final Function(String) onLanguageSwitch;

  const PreferencesScreen({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSwitch,
  });

  @override
  State<PreferencesScreen> createState() =>
      _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _alertsOn = true;
  bool _vibrateOn = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  // Load user preferences from storage
  Future<void> _loadUserPreferences() async {
    final storage = await SharedPreferences.getInstance();
    setState(() {
      _alertsOn = storage.getBool('alerts_enabled') ?? true;
      _vibrateOn = storage.getBool('vibrate_enabled') ?? false;
    });
  }

  // Save user preferences to storage
  Future<void> _saveUserPreferences() async {
    final storage = await SharedPreferences.getInstance();
    await storage.setBool('alerts_enabled', _alertsOn);
    await storage.setBool('vibrate_enabled', _vibrateOn);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.selectedLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            translate(lang, 'Preferences', 'सेटिंग्स', 'प्राथमिकता')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language section header
            Text(
              translate(lang, 'APP LANGUAGE', 'भाषा', 'भाषा'),
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // English language option
                  ListTile(
                    title: const Text('English',
                        style:
                            TextStyle(color: Colors.white)),
                    trailing:
                        widget.selectedLanguage == 'English'
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF00B4D8))
                            : null,
                    onTap: () =>
                        widget.onLanguageSwitch('English'),
                  ),
                  const Divider(
                      color: Colors.white12, height: 1),
                  // Hindi language option
                  ListTile(
                    title: const Text('हिंदी (Hindi)',
                        style:
                            TextStyle(color: Colors.white)),
                    trailing:
                        widget.selectedLanguage == 'Hindi'
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF00B4D8))
                            : null,
                    onTap: () =>
                        widget.onLanguageSwitch('Hindi'),
                  ),
                  const Divider(
                      color: Colors.white12, height: 1),
                  // Nepali language option
                  ListTile(
                    title: const Text('नेपाली (Nepali)',
                        style:
                            TextStyle(color: Colors.white)),
                    trailing:
                        widget.selectedLanguage == 'Nepali'
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF00B4D8))
                            : null,
                    onTap: () =>
                        widget.onLanguageSwitch('Nepali'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Alert settings header
            Text(
              translate(
                  lang, 'ALERT SETTINGS', 'सूचनाएं', 'सूचना सेटिङ'),
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Alerts on/off toggle
                  SwitchListTile(
                    title: Text(
                      translate(lang, 'Enable Alerts',
                          'सूचनाएं सक्षम करें',
                          'सूचनाहरू सक्षम गर्नुहोस्'),
                      style: const TextStyle(
                          color: Colors.white),
                    ),
                    subtitle: Text(
                      translate(
                          lang,
                          'Notify before meeting starts',
                          'मीटिंग से पहले सूचना',
                          'बैठक सुरु हुनुअघि सूचना'),
                      style: const TextStyle(
                          color: Colors.white38),
                    ),
                    value: _alertsOn,
                    activeColor: const Color(0xFF00B4D8),
                    onChanged: (val) {
                      setState(() => _alertsOn = val);
                      _saveUserPreferences();
                    },
                  ),
                  const Divider(
                      color: Colors.white12, height: 1),
                  // Vibrate on/off toggle
                  SwitchListTile(
                    title: Text(
                      translate(lang, 'Vibrate Mode',
                          'वाइब्रेशन मोड', 'भाइब्रेसन मोड'),
                      style: const TextStyle(
                          color: Colors.white),
                    ),
                    subtitle: Text(
                      translate(
                          lang,
                          'Use vibration instead of silent',
                          'साइलेंट की जगह वाइब्रेट',
                          'साइलेन्टको सट्टा भाइब्रेट'),
                      style: const TextStyle(
                          color: Colors.white38),
                    ),
                    value: _vibrateOn,
                    activeColor: const Color(0xFF00B4D8),
                    onChanged: (val) {
                      setState(() => _vibrateOn = val);
                      _saveUserPreferences();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.volume_off,
                      color: Color(0xFF00B4D8), size: 40),
                  const SizedBox(height: 8),
                  const Text('XSilent',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                  Text(
                    translate(lang, 'Version 1.0.0',
                        'संस्करण 1.0.0', 'संस्करण १.०.०'),
                    style: const TextStyle(
                        color: Colors.white38),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translate(
                      lang,
                      'Smart silence for your meetings',
                      'मीटिंग के लिए स्मार्ट साइलेंस',
                      'बैठकको लागि स्मार्ट साइलेन्स',
                    ),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}