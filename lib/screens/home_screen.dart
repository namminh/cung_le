import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../models/ceremony_suggestion.dart';
import '../utils/lunar_converter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _lunarDay;
  String? _lunarEvent;
  final _typeController = TextEditingController();
  final _budgetController = TextEditingController(text: '2 triệu');
  final _regionController = TextEditingController(text: 'miền Bắc');
  final _guestController = TextEditingController(text: '5');
  String _dietType = 'mặn';
  String _ceremonyStyle = 'đơn giản';
  CeremonySuggestion? _suggestion;
  String? _suggestedCeremonyType;
  bool _isLoading = false;
  String? _errorMessage;

  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _checkCeremonyForDate(_focusedDay);
  }

  Future<void> _checkCeremonyForDate(DateTime day) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _lunarDay = LunarConverter.getLunarDate(day);
      final ceremonyType = await _firebaseService.getCeremonyByDate(_lunarDay!);
      setState(() {
        _suggestedCeremonyType = ceremonyType;
        _lunarEvent = ceremonyType ?? _getLunarEventName(_lunarDay!);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể lấy dữ liệu lễ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getLunarEventName(String lunarDate) {
    const lunarEventNames = {
      '1-1': 'Tết Nguyên Đán',
      '15-1': 'Rằm Tháng Giêng',
      '15-7': 'Lễ Vu Lan',
      '15-8': 'Rằm Tháng Tám',
      '23-12': 'Cúng Ông Công Ông Táo',
    };
    return lunarEventNames[lunarDate] ?? '';
  }

  Future<void> _getPlan() async {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày!')));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestion = null;
    });
    try {
      String input =
          'Cúng ${_suggestedCeremonyType ?? _typeController.text}, ngân sách ${_budgetController.text}, '
          '${_regionController.text}, cho ${_guestController.text} người, '
          'loại lễ $_dietType, mức độ $_ceremonyStyle';
      final result = await _geminiService.getSuggestion(input, _selectedDay!);
      setState(() {
        _suggestion = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi gọi Gemini API: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestConsultation() async {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày trước khi yêu cầu tư vấn!'),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final consultationData = {
        'date':
            '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
        'lunarDate': _lunarDay,
        'ceremonyType': _suggestedCeremonyType ?? _typeController.text,
        'budget': _budgetController.text,
        'region': _regionController.text,
        'guests': _guestController.text,
        'dietType': _dietType,
        'ceremonyStyle': _ceremonyStyle,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('consultations')
          .add(consultationData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yêu cầu tư vấn đã được gửi thành công!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi gửi yêu cầu tư vấn: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gửi yêu cầu thất bại, vui lòng thử lại!'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Màu nền nhẹ nhàng
      appBar: AppBar(
        title: const Text(
          'Cúng Lễ',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red[800], // Màu đỏ truyền thống
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCalendarCard(),
              const SizedBox(height: 16),
              _buildLunarInfoCard(),
              const SizedBox(height: 24),
              _buildInputSection(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 24),
              _buildSuggestionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _checkCeremonyForDate(selectedDay);
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.orange[300],
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.red[600],
              shape: BoxShape.circle,
            ),
            defaultTextStyle: const TextStyle(color: Colors.black87),
            holidayTextStyle: const TextStyle(color: Colors.redAccent),
            weekendTextStyle: const TextStyle(color: Colors.grey),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.red),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: Colors.red,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              if (LunarConverter.isLunarEvent(day)) {
                return Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLunarInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.yellow[50], // Màu vàng nhạt gợi lễ
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ngày âm: ${_lunarDay ?? "Chưa chọn"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (_lunarEvent != null && _lunarEvent!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Sự kiện: $_lunarEvent',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin lễ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typeController,
              decoration: InputDecoration(
                labelText: 'Loại lễ',
                hintText: 'Ví dụ: Cúng giỗ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.event, color: Colors.red),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budgetController,
              decoration: InputDecoration(
                labelText: 'Ngân sách',
                hintText: 'Ví dụ: 2 triệu',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.money, color: Colors.red),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regionController,
              decoration: InputDecoration(
                labelText: 'Vùng miền',
                hintText: 'Ví dụ: Miền Bắc',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.location_on, color: Colors.red),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _guestController,
              decoration: InputDecoration(
                labelText: 'Số người tham gia',
                hintText: 'Ví dụ: 5',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.people, color: Colors.red),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _dietType,
              decoration: InputDecoration(
                labelText: 'Loại lễ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.food_bank, color: Colors.red),
              ),
              items:
                  ['mặn', 'chay']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _dietType = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _ceremonyStyle,
              decoration: InputDecoration(
                labelText: 'Mức độ cầu kỳ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(
                  Icons.design_services,
                  color: Colors.red,
                ),
              ),
              items:
                  ['đơn giản', 'cầu kỳ']
                      .map(
                        (style) =>
                            DropdownMenuItem(value: style, child: Text(style)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _ceremonyStyle = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _getPlan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                  : const Row(
                    children: [
                      Icon(Icons.lightbulb),
                      SizedBox(width: 8),
                      Text('Gợi ý kế hoạch', style: TextStyle(fontSize: 16)),
                    ],
                  ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: _isLoading ? null : _requestConsultation,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[600],
            side: BorderSide(color: Colors.red[600]!, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.support_agent),
              SizedBox(width: 8),
              Text('Yêu cầu tư vấn', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    if (_errorMessage != null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }
    if (_suggestion != null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_suggestion!.advice.isNotEmpty) ...[
                const Text(
                  'Giải thích ngày lễ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _suggestion!.advice,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const Divider(color: Colors.grey, height: 24),
              ],
              const Text(
                'Thực đơn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              ..._suggestion!.menu.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        item['price'] ?? '0 VNĐ',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.grey, height: 24),
              _buildSuggestionItem('Vật dụng', _suggestion!.items.join(', ')),
              const Divider(color: Colors.grey, height: 24),
              _buildSuggestionItem(
                'Nghi thức',
                _suggestion!.rituals.join(', '),
              ),
              const Divider(color: Colors.grey, height: 24),
              _buildSuggestionItem('Văn khấn', _suggestion!.prayer),
              const Divider(color: Colors.grey, height: 24),
              _buildSuggestionItem(
                'Ngân sách ước tính',
                _suggestion!.budgetEstimate,
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSuggestionItem(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _budgetController.dispose();
    _regionController.dispose();
    _guestController.dispose();
    super.dispose();
  }
}
