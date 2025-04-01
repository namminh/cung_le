import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final CollectionReference ceremoniesByDate = FirebaseFirestore.instance
      .collection('ceremonies_by_date');

  Future<String?> getCeremonyByDate(String lunarDate) async {
    QuerySnapshot query =
        await ceremoniesByDate
            .where('date', isEqualTo: lunarDate)
            .limit(1)
            .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first['type'] as String?;
    }
    return null;
  }
}
