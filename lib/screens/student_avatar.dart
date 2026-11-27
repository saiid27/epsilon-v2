part of '../main.dart';

/// A student's photo. Without a photo: the boy or girl illustration by gender,
/// otherwise the first letter of the name.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    required this.name,
    required this.photo,
    required this.gender,
    this.size = 40,
    super.key,
  });

  final String name;
  final String photo;
  final String gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (photo.startsWith('data:')) {
      child = Image.memory(
        base64Decode(photo.split(',').last),
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    } else if (photo.startsWith('http')) {
      child = Image.network(
        photo,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    } else if (gender == 'female') {
      child = Image.asset('assets/home/student_girl.png', fit: BoxFit.cover);
    } else if (gender == 'male') {
      child = Image.asset('assets/home/student_boy.png', fit: BoxFit.cover);
    } else {
      child = Container(
        alignment: Alignment.center,
        color: Eps.blueSoft,
        child: Text(
          name.isEmpty ? '؟' : name.characters.first,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: Eps.blue,
          ),
        ),
      );
    }
    return ClipOval(
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// A student's row for the admin: photo or illustration, name, phone, gender
/// and account status.
class StudentLine extends StatelessWidget {
  const StudentLine({required this.info, super.key});

  final EpsStudentInfo? info;

  static String genderLabel(String g) => switch (g) {
    'male' => 'ذكر',
    'female' => 'أنثى',
    _ => 'غير محدد',
  };

  static String statusLabel(String s) => switch (s) {
    'active' => 'حساب نشط',
    'pending' => 'بانتظار التفعيل',
    'frozen' => 'مجمّد',
    _ => s,
  };

  @override
  Widget build(BuildContext context) {
    final i = info;
    return Row(
      children: [
        StudentAvatar(
          name: i?.name ?? '',
          photo: i?.photo ?? '',
          gender: i?.gender ?? '',
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (i?.name.isNotEmpty ?? false) ? i!.name : 'طالب',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Eps.ink,
                ),
              ),
              Text(
                '${i?.phone ?? ''} · ${genderLabel(i?.gender ?? '')} · ${statusLabel(i?.status ?? '')}',
                style: const TextStyle(fontSize: 10, color: Eps.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
