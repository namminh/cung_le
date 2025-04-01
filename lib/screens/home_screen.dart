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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 600; // Web > 600px
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _dietType,
                      decoration: InputDecoration(
                        labelText: 'Loại lễ',
                        labelStyle: TextStyle(
                          color: Colors.red[600],
                          fontSize: isWideScreen ? 16 : 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.red[200]!,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.red[200]!,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.red[600]!,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.food_bank,
                          color: Colors.red[600],
                        ),
                        filled: true,
                        fillColor: Colors.red[50],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isWideScreen ? 16 : 12,
                          vertical: isWideScreen ? 12 : 10,
                        ),
                      ),
                      items:
                          ['mặn', 'chay']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(
                                        type == 'mặn'
                                            ? Icons.fastfood
                                            : Icons.local_florist,
                                        color: Colors.red[400],
                                        size: isWideScreen ? 20 : 16,
                                      ),
                                      SizedBox(width: isWideScreen ? 8 : 4),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: isWideScreen ? 14 : 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(() => _dietType = value!),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.red[600]),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _ceremonyStyle,
                      decoration: InputDecoration(
                        labelText: 'Mức độ cầu kỳ',
                        labelStyle: TextStyle(
                          color: Colors.red[600],
                          fontSize: isWideScreen ? 16 : 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.red[200]!,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.red[200]!,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.red[600]!,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.design_services,
                          color: Colors.red[600],
                        ),
                        filled: true,
                        fillColor: Colors.red[50],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isWideScreen ? 16 : 12,
                          vertical: isWideScreen ? 12 : 10,
                        ),
                      ),
                      items:
                          ['đơn giản', 'cầu kỳ']
                              .map(
                                (style) => DropdownMenuItem(
                                  value: style,
                                  child: Row(
                                    children: [
                                      Icon(
                                        style == 'đơn giản'
                                            ? Icons.hourglass_empty
                                            : Icons.hourglass_full,
                                        color: Colors.red[400],
                                        size: isWideScreen ? 20 : 16,
                                      ),
                                      SizedBox(width: isWideScreen ? 8 : 4),
                                      Text(
                                        style,
                                        style: TextStyle(
                                          fontSize: isWideScreen ? 14 : 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(() => _ceremonyStyle = value!),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.red[600]),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600; // Web thường > 600px
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: isWideScreen ? 16 : 8, // Khoảng cách lớn hơn trên web
          runSpacing: 8, // Khoảng cách dòng khi xuống hàng
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _getPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isWideScreen ? 24 : 16, // Thu nhỏ trên mobile
                  vertical: isWideScreen ? 12 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                textStyle: TextStyle(
                  fontSize: isWideScreen ? 16 : 14, // Font lớn hơn trên web
                ),
              ).copyWith(
                // Hiệu ứng hover cho web
                overlayColor: WidgetStateProperty.all(
                  Colors.white.withOpacity(0.2),
                ),
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
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lightbulb, size: 20),
                          SizedBox(width: isWideScreen ? 8 : 4),
                          const Text('Gợi ý kế hoạch'),
                        ],
                      ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestConsultation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[600],
                padding: EdgeInsets.symmetric(
                  horizontal: isWideScreen ? 24 : 16,
                  vertical: isWideScreen ? 12 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                elevation: 0, // Không bóng cho nút viền
                textStyle: TextStyle(fontSize: isWideScreen ? 16 : 14),
              ).copyWith(
                overlayColor: WidgetStateProperty.all(Colors.red[100]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent, size: 20),
                  SizedBox(width: isWideScreen ? 8 : 4),
                  const Text('Yêu cầu tư vấn'),
                ],
              ),
            ),
          ],
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600; // Web thường > 600px
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(
            isWideScreen ? 16 : 12,
          ), // Padding lớn hơn trên web
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[100]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Biểu tượng theo loại mục
              Icon(
                _getIconForTitle(title),
                color: Colors.red[600],
                size: isWideScreen ? 24 : 20,
              ),
              SizedBox(width: isWideScreen ? 12 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isWideScreen ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[600],
                      ),
                    ),
                    SizedBox(height: isWideScreen ? 8 : 6),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: isWideScreen ? 14 : 12,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Hàm chọn biểu tượng theo tiêu đề
  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Thực đơn':
        return Icons.restaurant_menu;
      case 'Vật dụng':
        return Icons.inventory;
      case 'Nghi thức':
        return Icons.event_note;
      case 'Văn khấn':
        return Icons.book;
      case 'Ngân sách ước tính':
        return Icons.attach_money;
      case 'Giải thích ngày lễ':
        return Icons.info;
      default:
        return Icons.circle; // Mặc định
    }
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
