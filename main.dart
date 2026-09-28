import 'package:flutter/material.dart';
 
void main() {
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Profile',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const ProfileScreen(),
    );
  }
}
 
// ===== Màu sắc dùng chung =====
const kBg = Color(0xFFF8FAFC);
const kBorder = Color(0xFFE2E8F0);
const kTextDark = Color(0xFF0F172A);
const kTextGrey = Color(0xFF64748B);
 
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        // FittedBox tự thu nhỏ toàn bộ giao diện (giữ nguyên tỉ lệ 390px)
        // để vừa khít một tab trình duyệt, không cần cuộn.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 390,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 23),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: kBorder, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    TopBar(),
                    SizedBox(height: 30),
                    ProfileHeader(),
                    SizedBox(height: 30),
                    StatsCard(),
                    SizedBox(height: 30),
                    AboutMe(),
                    SizedBox(height: 30),
                    SkillsSection(),
                    SizedBox(height: 30),
                    FeaturedProjects(),
                    SizedBox(height: 30),
                    ContactCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
 
// ===== Tiêu đề phần dùng chung (cao 21) =====
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 21,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: kTextDark,
        ),
      ),
    );
  }
}
 
// ===== 1. TopBar: 336 x 42 =====
class TopBar extends StatelessWidget {
  const TopBar({super.key});
 
  // Nút icon: rộng 20, cao 42
  Widget _iconButton(IconData icon) {
    return Container(
      width: 20,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Center(child: Icon(icon, size: 20, color: kTextDark)),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _iconButton(Icons.chevron_left),
          const SizedBox(
            height: 22,
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ),
          _iconButton(Icons.share_outlined),
        ],
      ),
    );
  }
}
 
// ===== 2. Profile Header =====
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar nhiều lớp: vòng gradient 140 > viền trắng 132 > ảnh 124
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFB088),
                        Color(0xFFFF8080),
                        Color(0xFFFFD166),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                ClipOval(
                  child: Image.asset(
                    'images/A1.jpg',
                    width: 124,
                    height: 124,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 124,
                      height: 124,
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.person, size: 60, color: kTextGrey),
                    ),
                  ),
                ),
                // Huy hiệu xác minh
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 29,
            child: Text(
              'NyanShiro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kTextDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(
            height: 18,
            child: Text(
              'Senior Mobile Developer',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kTextGrey,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Location pill
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF475569)),
                SizedBox(width: 4),
                Text(
                  'TP. Hồ Chí Minh',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
// ===== 3. Stats Card: 336 x 78 =====
class StatsCard extends StatelessWidget {
  const StatsCard({super.key});
 
  // Mỗi cột: 100 x 43
  Widget _stat(String value, String label, {Color color = kTextDark}) {
    return SizedBox(
      width: 100,
      height: 43,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              height: 22 / 18, // cố định chiều cao dòng 22px
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 14 / 12, // cố định chiều cao dòng 14px
              color: kTextGrey,
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _divider() {
    return Container(width: 1, height: 28, color: kBorder);
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat('32', 'Projects'),
          _divider(),
          _stat('5 Yrs', 'Experience'),
          _divider(),
          _stat('4.8 ★', 'Rating', color: const Color(0xFFD4A017)),
        ],
      ),
    );
  }
}
 
// ===== 4. About Me: 336 x 90 =====
class AboutMe extends StatelessWidget {
  const AboutMe({super.key});
 
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('About Me'),
          // Đoạn văn cao 84 (4 dòng x 21), bị cắt gọn trong khung 90
          Expanded(
            child: ClipRect(
              child: Text(
                'Lập trình vì đam mê chuyên xây dựng '
                'ứng dụng đa nền tảng hiệu năng cao. Luôn hướng đến giao diện '
                'đẹp. Có kinh nghiệm làm việc nhóm.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 21 / 14, // line-height 21px
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 
// ===== 5. Skills & Expertise: 336 x 105 (21 + 12 + 32 + 8 + 32) =====
class SkillsSection extends StatelessWidget {
  const SkillsSection({super.key});
 
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Skills & Expertise'),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SkillChip(
                label: 'Flutter',
                icon: Icons.flutter_dash,
                bg: Color(0xFFE0F2FE),
                fg: Color(0xFF0369A1),
              ),
              SkillChip(
                label: 'Dart',
                icon: Icons.code,
                bg: Color(0xFFDCFCE7),
                fg: Color(0xFF15803D),
              ),
              SkillChip(
                label: 'Clean Arch',
                icon: Icons.layers_outlined,
                bg: Color(0xFFFFE4E6),
                fg: Color(0xFFBE123C),
              ),
              SkillChip(
                label: 'UI/UX',
                icon: Icons.brush_outlined,
                bg: Color(0xFFF3E8FF),
                fg: Color(0xFF7E22CE),
              ),
              SkillChip(
                label: 'Firebase',
                icon: Icons.local_fire_department_outlined,
                bg: Color(0xFFFEF3C7),
                fg: Color(0xFFB45309),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
 
// Chip kỹ năng: cao 32
class SkillChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
 
  const SkillChip({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
 
// ===== 6. Featured Projects: 336 x 185 =====
class FeaturedProjects extends StatelessWidget {
  const FeaturedProjects({super.key});
 
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Featured Projects'),
          SizedBox(height: 19),
          // Hàng 336 x 145: hai thẻ 165 + khoảng cách 6
          SizedBox(
            height: 145,
            child: Row(
              children: [
                Expanded(
                  child: ProjectCard(
                    title: 'E-Shop Flutter',
                    subtitle: 'Mobile App • 2026',
                    imageUrl: 'images/A2.jpg',
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: ProjectCard(
                    title: 'Chat Realtime',
                    subtitle: 'Mobile • Firebase',
                    imageUrl: 'images/A3.jpg',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class ProjectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final List<Color>? gradient;
 
  const ProjectCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.gradient,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 145,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gradient != null)
            Container(
              width: double.infinity,
              height: 85,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient!,
                ),
              ),
            )
          else
            Image.network(
              imageUrl!,
              width: double.infinity,
              height: 85,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 85,
                color: const Color(0xFFE2E8F0),
                child: const Icon(Icons.image_outlined, color: kTextGrey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: kTextGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
// ===== 7. Contact Card: 336 x 192 =====
class ContactCard extends StatelessWidget {
  const ContactCard({super.key});
 
  // Mỗi hàng cao 62
  Widget _row(IconData icon, String text, {bool bold = false}) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: bold ? kTextDark : kTextGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w400,
                  color: kTextDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
 
  Widget _divider() => Container(height: 1, color: const Color(0xFFF1F5F9));
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 192,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _row(Icons.alternate_email, 'Contact Information', bold: true),
          _divider(),
          _row(Icons.mail_outline, 'nyanshiro@shiro.com'),
          _divider(),
          _row(Icons.phone_outlined, '+84 123 456 789'),
        ],
      ),
    );
  }
}
