import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sync/providers/user_provider.dart';
import 'package:study_sync/widgets/menu_list.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key});

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
   
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (_user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserData(_user);
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      elevation: 10,
      child: Column(
        children: [
          _buildUserHeader(context),
          const Expanded(child: MenuList()),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Container(
      
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(Icons.person, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? _buildShimmerText()
              : Text(
                  userProvider.name.isNotEmpty
                      ? userProvider.name
                      : _user?.displayName ?? 'StudySync User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
          const SizedBox(height: 4),
          _isLoading
              ? _buildShimmerText(width: 150)
              : Text(
                  userProvider.email.isNotEmpty
                      ? userProvider.email
                      : _user?.email ?? 'user@example.com',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerText({double width = 200}) {
    return Container(
      height: 24,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}