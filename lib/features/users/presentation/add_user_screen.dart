import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_repository.dart';
import '../../movies/presentation/movie_list_screen.dart';
import '../../movies/presentation/providers/selected_user_provider.dart';

class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _nameController = TextEditingController();
  final _jobController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _jobController,
              decoration: const InputDecoration(labelText: 'Job', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isEmpty || _jobController.text.isEmpty) return;

                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        await ref.read(userRepositoryProvider).createUser(
                          name: _nameController.text,
                          job: _jobController.text,
                        );

                        // Success - the repository handles offline logic
                        // We then navigate to movie list as per assignment flow:
                        // "A candidate must be able to create a brand new user offline, 
                        // immediately navigate to the movie list, and bookmark movies..."
                        
                        // Let's get the internal ID of our newly created user
                        final users = await ref.read(userRepositoryProvider).getStoredUsers();
                        final newUser = users.last; // Most recent entry
                        
                        ref.read(selectedUserProvider.notifier).state = newUser.id;

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User added successfully!')),
                          );
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const MovieListScreen()),
                            (Route<dynamic> route) => route.isFirst,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: const Text('Add User'),
                  ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    super.dispose();
  }
}
