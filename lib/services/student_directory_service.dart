import 'dart:convert';
import 'package:http/http.dart' as http;

class CcsaDirectoryStudent {
  final String name;
  final String course; // BCA, MCA, PGDCA
  final int semester; // 1 to 8

  const CcsaDirectoryStudent({
    required this.name,
    required this.course,
    required this.semester,
  });

  factory CcsaDirectoryStudent.fromMap(Map<String, dynamic> map) {
    return CcsaDirectoryStudent(
      name: (map['name'] ?? '').toString().trim(),
      course: (map['course'] ?? 'BCA').toString().trim(),
      semester: int.tryParse(map['semester']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'course': course,
    'semester': semester,
  };

  String get semesterDisplay {
    if (semester == 1) return '1st Sem';
    if (semester == 2) return '2nd Sem';
    if (semester == 3) return '3rd Sem';
    return '${semester}th Sem';
  }
}

class StudentDirectoryService {
  static final StudentDirectoryService instance = StudentDirectoryService._init();
  StudentDirectoryService._init();

  List<CcsaDirectoryStudent> _dynamicStudents = [];

  /// Returns full directory (live cloud proxy merged with master roster)
  List<CcsaDirectoryStudent> get allStudents => _dynamicStudents.isNotEmpty ? _dynamicStudents : ccsaMasterStudents;

  /// Fetches live student directory from proxy API on ccsdu.in
  Future<List<CcsaDirectoryStudent>> fetchLiveDirectory() async {
    final urls = [
      'https://ccsdu.in/endpoints/get_directory_students.php',
      'https://ccsdu.in/src/proxy/students.php',
      'https://ccsdu.in/src/cache/students_dept_25.json',
    ];

    for (final u in urls) {
      try {
        final res = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          List<CcsaDirectoryStudent> parsed = [];

          if (decoded is Map && decoded['students'] is List) {
            for (final item in decoded['students']) {
              parsed.add(CcsaDirectoryStudent.fromMap(item as Map<String, dynamic>));
            }
          } else if (decoded is List) {
            for (final dept in decoded) {
              if (dept is Map && dept['programmes'] is List) {
                for (final prog in dept['programmes']) {
                  final progName = (prog['programme'] ?? '').toString();
                  final course = progName.contains('BCA')
                      ? 'BCA'
                      : (progName.contains('MCA')
                          ? 'MCA'
                          : (progName.contains('PGDCA') ? 'PGDCA' : 'BCA'));

                  for (final sem in (prog['semesters'] ?? [])) {
                    final semTitle = (sem['semester'] ?? '').toString();
                    int semNum = 1;
                    if (semTitle.contains('1st')) {
                      semNum = 1;
                    } else if (semTitle.contains('2nd')) {
                      semNum = 2;
                    } else if (semTitle.contains('3rd')) {
                      semNum = 3;
                    } else if (semTitle.contains('4th')) {
                      semNum = 4;
                    } else if (semTitle.contains('5th')) {
                      semNum = 5;
                    } else if (semTitle.contains('6th')) {
                      semNum = 6;
                    } else if (semTitle.contains('7th')) {
                      semNum = 7;
                    } else if (semTitle.contains('8th')) {
                      semNum = 8;
                    }

                    for (final s in (sem['students'] ?? [])) {
                      final name = (s['name'] ?? '').toString().trim();
                      if (name.isNotEmpty) {
                        parsed.add(CcsaDirectoryStudent(name: name, course: course, semester: semNum));
                      }
                    }
                  }
                }
              }
            }
          }

          if (parsed.isNotEmpty) {
            _dynamicStudents = parsed;
            return parsed;
          }
        }
      } catch (e) {
        // Fall back to master list
      }
    }

    _dynamicStudents = ccsaMasterStudents;
    return _dynamicStudents;
  }

  /// Search across all students with optional course and semester filter
  List<CcsaDirectoryStudent> searchStudents(String query, {String? course, int? semester}) {
    var list = allStudents;
    if (course != null && course.isNotEmpty) {
      list = list.where((s) => s.course.toUpperCase() == course.toUpperCase()).toList();
    }
    if (semester != null) {
      list = list.where((s) => s.semester == semester).toList();
    }
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase().trim();
    return list.where((s) {
      return s.name.toLowerCase().contains(q) || s.course.toLowerCase().contains(q);
    }).toList();
  }

  /// Official CCSA Dibrugarh University Student Master Directory (All 311 students from DU proxy)
  static const List<CcsaDirectoryStudent> ccsaMasterStudents = [
    CcsaDirectoryStudent(name: 'Abhigyan Konwar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Abhipran Subadar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Abinash Khatowal', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Abiyon Saikia', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Aditya Kiran Konwar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Afsara Akhtar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'AHIRON SARMA BARUAH', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Aishwarya Bhuyan', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Akangkhya Medhi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'ANCHIT DAS', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Angelina Deori', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'ANINDAM BORA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Anmol Singh', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Anwesha Chutia', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Arif Aman Ahmed', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Aruhon Boruah', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'ARYAN GOGOI', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Asfak hasmi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'ASHISH SAUD', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ayandeep Das', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ayesha Yasmeen', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ayon Baruah', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'AYON MAHAJAN', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ayush Dey', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ayush Karmakar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Baishnabi Boruah', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Bhahil Das', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Bibash Das', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Bibek Tamang', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'BINITA PURTY', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Bishal karmakar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Bitupan Deka', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'CATHRINE TOPNO', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Chandan Chetry', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Danish ullah', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Debojit Deb', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'DIBYADARSHAN KALITA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Dimpal Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Disha Borgohain', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'DORPON BORUAH', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'FANINDRA SHARMA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'GEETASHREE CHUTIA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Gorima Handique', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Gouri Sankar Chetia', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Hrisikesh Rajkonwar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Jaswanta Phukan', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Jenifa ahmed', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Junaid Chaudhary', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kartik Pasi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'KASMIR KACHARI', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Khanjon Borgohain', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Khusi Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kimonraj Doley', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kiyan Pegu', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kousi Pradhan', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kripa Sundar Bhuyan', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'KRISHNANAN SAIKIA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Krishtianu Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kriti Saikia', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kuldip Kumar Neog', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kunal Bharati', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'LAYAD KONWAR', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Lord Ripan Dhan', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Lovely Dutta', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Luna  Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Maharnab Phukan', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Md Fardeen Rahman', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Miss Sabnam Sultana', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Nandita Deori', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Nibir Junak Boruah', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Nirman Nilim Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Oeishiki Deb', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Padmanav Sarmah', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'PARTHA DAS', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Partha Protim Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Pranchi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Pranjal Nagbonshi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Prince Kumar Loram', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'RAJNISH CHETIA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rashmi Rekha Sutradhar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rimjhim Singpho', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rimpi Bora', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'RIYA KUMARI', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rocktim Nayan Das', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'RUPSIKHA DEB', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Sagar Pratap Bhaspar', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Sahanaj begum', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Sahinur Mallik', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'SAR IM RONGPHAR', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Sasanka Bora', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Satyaraj Das', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'SHIBANI GOGOI', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Shilpi Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'SHRIYA DAS', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Sintu Borgohain', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Somayya Tabasum Bora', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Somrik Sengupta', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Soumyadeep Das', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'subrata dev', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Sudipta Gogoi', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'TUSHAR SINGHA', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Udipta Sonowal', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'UPAKHANA DEORI', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'Vivek Upadhyaya', course: 'BCA', semester: 1),
    CcsaDirectoryStudent(name: 'ABHISHEK GOGOI', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'ABHISHEK PAUL', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Aditya Dowarah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Agarstin Malik Duarte Milton', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'AKASH BORUAH', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Alongkita Baruah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Ananaya Bora', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Anirban Gogoi', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Anishya Gogoi', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'ankursri mahanta', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Anshuman Bose', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Ayush Giri', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'BITUPAN TAW', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'DANIEL KHAKHLARY', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Deb Doley', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'DEBASISH BHUYAN', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Debojit Bora', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Diksha Hazarika', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Gonesh sahu', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Gourovraj Boruah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Gyan Jyoti Gogoi', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'HARAMOHAN SONOWAL', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Harshika Jain', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'HIMADRIZA PHUKAN', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'ISHANI DUTTA', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'JILMIL BORTHAKUR', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Kabir Boruah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'KHUSBU SAH', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'MANASHEE TANTI', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Mayuri Panging', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'MD FARHAN', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Monuj Majumder', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Moyuri phukan', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'MRIDURAJ BORBORUAH', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'NIKUMONI CHUTIA', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Nisha Doley', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Om Saikia', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Palak Shah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Palden Tamang', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'PIYUSH BHADRA', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Prabal gohain', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'PRANOTI SUNIL TANDALE', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Pratyasha Kakoty', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Priyanganabh Baruah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'PRIYANKA PHOOKAN', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Rajdeep Gogoi', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Rajdeep kaushik', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'RIMJHIM KUMARI SHAH', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Rishita Dutta', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'RUBUL GAN', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Saadat Zameer Rahman', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Sahr Emmanuel Morsay', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'SANJIB  RISHI', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Sanju Pegu', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Santipriya gogoi', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'SATYAJIT MONDAL', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Somudra Borah', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Sudeep Sarkar', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'sukh deb mandal', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'Suvraj kashyap', course: 'BCA', semester: 3),
    CcsaDirectoryStudent(name: 'AAYUSHRI HAZARIKA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'ABHISHEK BEHERA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Akshita Thapa', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Andy Ricardo Deposi', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'ANIKET TOPNO', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Ankita Kumari', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Anuj Rai', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'ANURAG PRIYAM CHUTIA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Arijit Sarkar', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'ARYA BORAH', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'ARYAN SHARMA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Asish Sahu', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'BARBI GOGOI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'BIDYOT BIKASH BORUAH', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'BINIT SONOWAL', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Bondita Boruah', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Chanuj duarah', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Chenkham chowlu', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'CHINMOY SONOWAL', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'CHINNAY MILI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Debasish borthakur', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'DERION SONOWAL', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'DIGBIJOY SENAPOTI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'DRUB NAMASUDRA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Farhana Khanam', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'GAYATRI SAIKIA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Gouri Saikia', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Hari Sah', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'HARSHIT RAJGURU', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Ishpita chutia', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Jagannath Baba', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Jhorna gogoi', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Jyotishmoy Barman', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'LUCETA BORDOLOI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Mehdi Hassan', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Miss. Sheshadree Dasgupta', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'MOHARNAVA GOGOI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Mousamraj Phukon', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Nabidul Hassan Duha', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'NIKHIL HAZARIKA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Nilutpal Saikia Borah', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'NISHA SINGH', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'PADMA PALASH SAUD', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'POOJA KALITA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Prerona Rajowar', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Progyan Boruah', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Raman Upadhyaya', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'RAVI SHARMA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'RISHI RAJ SHARMA', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Rishiraj Gorh', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Rohit Thongam', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Roktim Taye', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Sahista Hussain', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Sayantani Mazumder', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'SHUBHAM KUMAR SHAH', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'SMEETA PAUL', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'SOYONIKA GOGOI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Susmriti Bora', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'TINA GOGOI', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'trishna saikia', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'TUDIP KEOT', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'UMESH SAHU', course: 'BCA', semester: 5),
    CcsaDirectoryStudent(name: 'Abhilash Bhuyan', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Abhilash Hazarika', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Aftab Ansari', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'ARYAMAN SAIKIA', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ayush Sharma', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Baishali Bhattacharjee', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'BINAYAK UPADHYAY', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Brinchi Gogoi', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Debabrata Saikia', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Deep Jyoti Boruah', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Gargi Dutta', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Gaurav dehingia', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Gyandeep Dehingia', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Hanshika Bhardwaj', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Janmijoy Borah', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Jeet sonowal', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Karanraj Karmakar', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'KISHOR HAZARIKA', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Krishaloy Dutta', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Manash Pratim Gogoi', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'MD Bilaluddin Rahman', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Mohit Gupta', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Mowsomee Hatimuria', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Panchami sarkar', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Phulan Boro', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Plabon Jyoti Bora', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Pratyush Priyam Borah', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Pritisha Gogoi', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rahul Nath', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rimonjit Saikia', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'RUNAX CHANGMAI', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Samir Ranjan Hazarika', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'SANCHITA GOGOI', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Shahil Deori', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'Wasim Ishaan Ahmed', course: 'MCA', semester: 1),
    CcsaDirectoryStudent(name: 'ABHI CHETRI', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Aditya Karmakar', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Amar Chetry', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Arghajit Saha', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Artha Jyoti Hazarika', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Bibek sarkar', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Daisy Sonowal', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Dhiraj Borah', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Gouri Gayan', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Gouri Saikia', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'HIMAKHI BHARALI', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'John Jason Opiyo', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'juman das', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'KALYAN KUMAR GUPTA', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Manakh Gohain', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'MANASH JYOTI BARUAH', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'MEHAR SULTANA', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Mridu moloy saikia', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'MRINALI BORAH', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'NIRAJNIL DUTTA', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Niyar Mukuta Dutta', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Praduniya Pran Konwar', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'PRINCI DUTTA', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Raja Thakur', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Rupam Phukan', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Sahil Zamal Saikia', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'SARFARAZ PARVEZ HAQUE', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Shyamal Handique', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Sororphy Hongray', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Srishti Mallick', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Ummidul Anjar Bin Altab', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'Yanjan Agarwal', course: 'MCA', semester: 3),
    CcsaDirectoryStudent(name: 'ALAKESH BORAH', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'ANGIKA DEHINGIA', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Ankita Bhowmick', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Bipasha Kakoty', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'BORSHARANI BORUAH', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Dikshita Phukan', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Drenlee Das', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Gourav Gohain', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Islan Rahman', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Jahnabi Boro', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'JAYANTA BORUAH', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kankana Baishya', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Kironjyoti Saikia', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'NIKHITA GOGOI', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'PRITOM KONWAR', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'RINA CHUTIA', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Rittika Singh', course: 'PGDCA', semester: 1),
    CcsaDirectoryStudent(name: 'Roshmi Borgohain', course: 'PGDCA', semester: 1),
  ];
}
