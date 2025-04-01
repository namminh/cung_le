import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/ceremony_suggestion.dart';
import '../utils/lunar_converter.dart';

class GeminiService {
  static const _primaryKeyName = 'primary_api_key';
  static const _backupKeyName = 'backup_api_key';
  static const _statusKeyName = 'api_key_status';

  // Key mặc định (nên lấy từ biến môi trường trong production)
  static const String _defaultPrimaryKey =
      'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY';
  static const String _defaultBackupKey =
      'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY';

  late GenerativeModel _model;
  bool _isInitialized = false;

  GeminiService() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    if (_isInitialized) return; // Tránh khởi tạo nhiều lần
    final apiKey = await _getApiKey();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash', // Đảm bảo model này tồn tại
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.35,
        topP: 0.95,
        maxOutputTokens: 10000,
        responseMimeType: 'application/json',
      ),
    );
    _isInitialized = true;
    print('GeminiService initialized with key: $apiKey');
  }

  Future<CeremonySuggestion> getSuggestion(
    String input,
    DateTime selectedDay,
  ) async {
    final lunarDate = LunarConverter.getLunarDate(selectedDay);
    final prompt = '''
<Prompt>
  <Role type="generator">Vietnamese Ceremony Planner</Role>
  <TaskParameters>
    <Quantitative>
      <MenuItems min="0" max="6" style="cost_effective_region_specific"/>
      <Budget value="${input.contains('ngân sách') ? input.split('ngân sách')[1].split(',')[0].trim() : '2 triệu'}" unit="VND" instruction="keep_within_budget"/>
      <Participants count="${input.contains('cho') ? input.split('cho')[1].split('người')[0].trim() : '5'}" instruction="scale_menu_and_items"/>
    </Quantitative>
    <Qualitative>
      <Region value="${input.contains('miền') ? input.split('miền')[1].split(',')[0].trim() : 'Bắc'}" context="Vietnam"/>
      <DietType value="${input.contains('loại lễ') ? input.split('loại lễ')[1].split(',')[0].trim() : 'mặn'}"/>
      <CeremonyStyle value="${input.contains('mức độ') ? input.split('mức độ')[1].split(',')[0].trim() : 'đơn giản'}" instruction="adjust_rituals_and_items"/>
      <Language lang="Vietnamese" tone="practical_cultural" vocab="simple_clear"/>
    </Qualitative>
    <DateContext>
      <SolarDate day="${selectedDay.day}" month="${selectedDay.month}" year="${selectedDay.year}"/>
      <LunarDate value="$lunarDate"/>
    
    </DateContext>
  </TaskParameters>

  <ProcessingPipeline>
    <Stage name="EventIdentification" input="DateContext,KnownEvent,CeremonyType" 
           target="confirm_ceremony" priority="KnownEvent_over_CeremonyType"/>
    <Stage name="MenuPlanning" input="Budget,Participants,DietType,Region,CeremonyType" 
           target="generate_practical_menu" condition="fit_budget_and_diet"/>
    <Stage name="RitualPlanning" input="CeremonyType,Region,CeremonyStyle,KnownEvent" 
           source="Vietnamese_tradition" target="list_clear_steps"/>
    <Stage name="PrayerGeneration" input="CeremonyType,KnownEvent" 
           target="short_traditional_prayer" condition="relevant_to_event"/>
    <Stage name="BudgetCalculation" input="MenuItems,RitualPlanning" 
           target="total_cost" instruction="stay_within_budget"/>
    <Stage name="AdviceCrafting" input="KnownEvent,LunarDate,CeremonyType" 
           target="practical_cultural_advice" instruction="short_clear_relevant_to_event"/>
  </ProcessingPipeline>

  <ResponseFeatures>
    <Accuracy>
      <EventSignificance source="KnownEvent" fallback="CeremonyType" 
                        instruction="ensure_historical_accuracy_for_Vietnam"/>
      <Practicality target="realistic_implementable" context="everyday_household"/>
    </Accuracy>
    <Clarity>
      <AdviceLength maxWords="50" style="concise_actionable"/>
      <OutputFormat instruction="strict_JSON_structure"/>
    </Clarity>
  </ResponseFeatures>

  <ResponseTemplate>
    Trả về JSON với cấu trúc:
    ```json
    {
      "menu": [{"name": "món ăn", "price": "giá VNĐ"}],
      "items": ["vật dụng cần thiết"],
      "rituals": ["bước nghi thức ngắn gọn"],
      "prayer": "văn khấn ngắn gọn",
      "budgetEstimate": "tổng chi phí trong ngân sách",
      "advice": "ý nghĩa ngày lễ chính xác và lời khuyên thiết thực (dưới 50 từ)"
    }
    ```
  </ResponseTemplate>
</Prompt>
''';

    return await _generateSuggestion(prompt);
  }

  Future<CeremonySuggestion> _generateSuggestion(String prompt) async {
    await _initializeModel(); // Đảm bảo model đã sẵn sàng
    const maxRetries = 2; // Số lần thử lại tối đa
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        final content = [Content.text(prompt)];
        final response = await _model.generateContent(content);
        final jsonString = response.text ?? '{}';
        print('Raw response from Gemini: $jsonString');

        // Xử lý dữ liệu trả về linh hoạt
        dynamic jsonData = jsonDecode(jsonString);
        Map<String, dynamic> jsonMap;

        if (jsonData is List<dynamic>) {
          // Trường hợp web: dữ liệu là mảng
          if (jsonData.isNotEmpty && jsonData[0] is Map<String, dynamic>) {
            jsonMap = jsonData[0] as Map<String, dynamic>;
          } else {
            throw Exception(
              'Dữ liệu từ Gemini không chứa Map hợp lệ trong mảng',
            );
          }
        } else if (jsonData is Map<String, dynamic>) {
          // Trường hợp mobile: dữ liệu là Map trực tiếp
          jsonMap = jsonData;
        } else {
          throw Exception(
            'Dữ liệu từ Gemini không đúng định dạng (không phải List hoặc Map)',
          );
        }

        print('Parsed JSON: $jsonMap');
        return CeremonySuggestion.fromJson(jsonMap);
      } catch (e) {
        attempt++;
        print('Error in GeminiService (attempt $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          // Chuyển sang key dự phòng nếu lỗi
          final currentKey = await _getApiKey();
          final newKey = await _switchToBackupKey(
            currentKey == _defaultPrimaryKey ? _primaryKeyName : _backupKeyName,
          );
          _model = GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: newKey,
            generationConfig: GenerationConfig(
              temperature: 0.35,
              topP: 0.95,
              maxOutputTokens: 10000,
              responseMimeType: 'application/json',
            ),
          );
          print('Retrying with new key: $newKey');
        } else {
          throw Exception('Không thể tạo gợi ý sau $maxRetries lần thử: $e');
        }
      }
    }
    throw Exception('Không thể tạo gợi ý: quá số lần thử');
  }

  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final status =
        prefs.getString(_statusKeyName) ?? '{"active": "$_primaryKeyName"}';
    final statusMap = jsonDecode(status) as Map<String, dynamic>;
    String activeKeyName = statusMap['active'] as String;

    String? storedKey = prefs.getString(activeKeyName);
    if (storedKey == null || storedKey.isEmpty) {
      storedKey =
          activeKeyName == _primaryKeyName
              ? _defaultPrimaryKey
              : _defaultBackupKey;
      await prefs.setString(activeKeyName, storedKey);
    }
    return storedKey;
  }

  Future<String> _switchToBackupKey(String currentKeyName) async {
    final prefs = await SharedPreferences.getInstance();
    final newKeyName =
        currentKeyName == _primaryKeyName ? _backupKeyName : _primaryKeyName;
    String? newKey = prefs.getString(newKeyName);

    if (newKey == null || newKey.isEmpty) {
      newKey =
          newKeyName == _primaryKeyName
              ? _defaultPrimaryKey
              : _defaultBackupKey;
      await prefs.setString(newKeyName, newKey);
    }

    await prefs.setString(_statusKeyName, jsonEncode({'active': newKeyName}));
    print('Switched to $newKeyName');
    return newKey;
  }
}
