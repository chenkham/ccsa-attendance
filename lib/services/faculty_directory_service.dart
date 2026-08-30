class CcsaFacultyMember {
  final String name;
  final String designation;

  const CcsaFacultyMember({
    required this.name,
    this.designation = 'Assistant Professor',
  });
}

class FacultyDirectoryService {
  static final FacultyDirectoryService instance = FacultyDirectoryService._init();
  FacultyDirectoryService._init();

  /// Official CCSA Teaching Faculty Directory from Dibrugarh University
  static const List<CcsaFacultyMember> ccsaFacultyList = [
    CcsaFacultyMember(name: 'Dr. Rizwan Rehman', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Dr. Utpala Borgohain', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Dr. Toralima Bora', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Dr. Ujjal Saikia', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Dr. Kimasha Borah', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Dr. Pranjal Kumar Bora', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Mr. Ankumon Sarmah', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Ms. Kankana Dutta', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Dr. Sumpi Saikia', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Ms. Pinakshi Konwar', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Mr. Pranjit Lahon', designation: 'Assistant Professor'),
    CcsaFacultyMember(name: 'Guest Faculty', designation: 'Guest Lecturer'),
  ];

  static List<String> get facultyOptions => ccsaFacultyList.map((f) => f.name).toList();
}
