import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../data/user_model.dart';
import '../data/user_repository.dart';
import 'add_user_screen.dart';
import 'user_search_delegate.dart';
import '../../movies/presentation/movie_list_screen.dart';
import '../../movies/presentation/providers/selected_user_provider.dart';
import '../../../core/network/network_status.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  static const _pageSize = 6;
  final PagingController<int, User> _pagingController = PagingController(firstPageKey: 1);

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.initState();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await ref.read(userRepositoryProvider).getPaginatedUsers(pageKey);
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(context: context, delegate: UserSearchDelegate(ref)),
          ),
        ],
        bottom: networkStatus == NetworkStatus.connecting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(20),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Text('Reconnecting...', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            : null,
      ),
      body: PagedListView<int, User>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<User>(
          itemBuilder: (context, item, index) => ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(item.avatar),
            ),
            title: Text('${item.firstName} ${item.lastName}'),
            subtitle: Text('ID: ${item.id}'),
            onTap: () async {
              ref.read(selectedUserProvider.notifier).state = item.id; 
              
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MovieListScreen()),
                );
              }
            },
          ),
          firstPageErrorIndicatorBuilder: (context) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Something went wrong. Retrying...'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _pagingController.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddUserScreen()),
          );
          _pagingController.refresh(); // Reload to show new local user
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
}
