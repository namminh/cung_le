class LunarConverter {
  // Bảng tra cứu ngày Tết (1-1 âm) theo năm dương
  static final Map<int, DateTime> tetDates = {
    2020: DateTime(2020, 1, 25),
    2021: DateTime(2021, 2, 12),
    2022: DateTime(2022, 2, 1),
    2023: DateTime(2023, 1, 22),
    2024: DateTime(2024, 2, 10),
    2025: DateTime(2025, 1, 29),
    2026: DateTime(2026, 2, 17),
    2027: DateTime(2027, 2, 6),
    2028: DateTime(2028, 1, 26),
    2029: DateTime(2029, 2, 13),
    2030: DateTime(2030, 2, 3),
  };

  // Bảng tra cứu các ngày lễ chính (âm lịch -> dương lịch)
  static final Map<String, Map<int, DateTime>> lunarEvents = {
    '1-1': {
      2020: DateTime(2020, 1, 25),
      2021: DateTime(2021, 2, 12),
      2022: DateTime(2022, 2, 1),
      2023: DateTime(2023, 1, 22),
      2024: DateTime(2024, 2, 10),
      2025: DateTime(2025, 1, 29),
      2026: DateTime(2026, 2, 17),
      2027: DateTime(2027, 2, 6),
    }, // Tết
    '15-1': {2025: DateTime(2025, 2, 12)}, // Rằm tháng Giêng
    '15-7': {2025: DateTime(2025, 8, 4)}, // Vu Lan
    '15-8': {2025: DateTime(2025, 9, 22)}, // Rằm Tháng Tám
    '23-12': {2025: DateTime(2025, 2, 11)}, // Ông Công Ông Táo
  };

  // Bảng năm nhuận (theo chu kỳ 19 năm có 7 tháng nhuận)
  static final Map<int, bool> leapYears = {
    2020: false,
    2021: false,
    2022: true, // Nhuận tháng 4
    2023: false,
    2024: false,
    2025: false,
    2026: true, // Nhuận tháng 2
    2027: false,
    2028: false,
    2029: true, // Nhuận tháng 8
    2030: false,
  };

  static String getLunarDate(DateTime solarDate) {
    final tetDate =
        tetDates[solarDate.year] ?? _estimateTetDate(solarDate.year);
    int diffDays = solarDate.difference(tetDate).inDays;

    // Kiểm tra ngày lễ đặc biệt trước
    for (var event in lunarEvents.entries) {
      final eventDate = event.value[solarDate.year];
      if (eventDate != null && _isSameDay(solarDate, eventDate)) {
        return event.key;
      }
    }

    // Tính ngày âm dựa trên ngày Tết
    if (diffDays < 0) {
      final lastTet =
          tetDates[solarDate.year - 1] ?? _estimateTetDate(solarDate.year - 1);
      diffDays = solarDate.difference(lastTet).inDays;
      return _calculateLunarFromDiff(diffDays, lastTet, solarDate.year - 1);
    } else {
      return _calculateLunarFromDiff(diffDays, tetDate, solarDate.year);
    }
  }

  static String _calculateLunarFromDiff(
    int diffDays,
    DateTime tetDate,
    int year,
  ) {
    const double avgDaysPerMonth = 29.53; // Chu kỳ Mặt Trăng thực tế
    int lunarMonth = 1;
    int lunarDay;

    if (diffDays < 0) {
      lunarDay =
          (diffDays + (avgDaysPerMonth * 12).round()) %
              avgDaysPerMonth.round() +
          1;
      lunarMonth = 12;
    } else if (diffDays == 0) {
      return '1-1'; // Ngày Tết
    } else {
      lunarDay = diffDays;
      while (lunarDay >= avgDaysPerMonth) {
        lunarDay -= avgDaysPerMonth.round();
        lunarMonth += 1;
      }
      lunarDay += 2; // Ngày bắt đầu từ 1
    }

    // Điều chỉnh cho năm nhuận
    bool isLeapYear = leapYears[year] ?? false;
    if (isLeapYear && lunarMonth > 6) {
      lunarMonth += 1; // Ước lượng tháng nhuận sau tháng 6
    }

    if (lunarMonth > 12) {
      lunarMonth = lunarMonth % 12;
      if (lunarMonth == 0) lunarMonth = 12;
    }

    return '$lunarDay-$lunarMonth';
  }

  static DateTime _estimateTetDate(int year) {
    // Ước lượng ngày Tết dựa trên chu kỳ trung bình (khoảng 21/1 - 20/2)
    return DateTime(year, 1, 29); // Mặc định nếu không có dữ liệu
  }

  static bool isLunarEvent(DateTime day) {
    for (var event in lunarEvents.values) {
      final eventDate = event[day.year];
      if (eventDate != null && _isSameDay(day, eventDate)) {
        return true;
      }
    }
    return false;
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
