import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/session_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.apiClient,
    required this.authService,
    required this.token,
    required this.user,
    super.key,
  });

  final ApiClient apiClient;
  final AuthService authService;
  final String token;
  final SessionUser user;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  final List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showAttachMenu = false;
  bool _showModelMenu = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final messages = await widget.apiClient.getMessages(widget.token);
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _controller.clear();
      _messages.add(userMessage);
      _isSending = true;
      _showAttachMenu = false;
      _showModelMenu = false;
      _error = null;
    });
    _scrollToBottom();

    try {
      final assistant = await widget.apiClient.sendMessage(
        token: widget.token,
        message: text,
      );
      setState(() => _messages.add(assistant));
      _scrollToBottom();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          apiClient: widget.apiClient,
          authService: widget.authService,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SettingsSheet(user: widget.user, onSignOut: _signOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111113),
      drawer: _NeuraXDrawer(user: widget.user, onSettings: _openSettings),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(onNewChat: _loadMessages),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 160),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const _TypingBlock();
                            }
                            return _MessageBlock(message: _messages[index]);
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF6565)),
                      ),
                    ),
                  if (_showAttachMenu)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _AttachMenu(),
                    ),
                  if (_showModelMenu)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _ModelMenu(),
                    ),
                  _Composer(
                    controller: _controller,
                    isSending: _isSending,
                    onSend: _send,
                    onAttach: () => setState(() {
                      _showAttachMenu = !_showAttachMenu;
                      _showModelMenu = false;
                    }),
                    onModel: () => setState(() {
                      _showModelMenu = !_showModelMenu;
                      _showAttachMenu = false;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 34),
              ),
            ),
            const Spacer(),
            const _ModeTabs(),
            const Spacer(),
            IconButton(
              tooltip: 'Percakapan baru',
              onPressed: onNewChat,
              icon: const Icon(Icons.edit_square, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Ask',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 28),
            Text(
              'Imagine',
              style: TextStyle(
                color: Color(0xFF808087),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 30,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF68686E),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: .08,
        child: Image.asset(
          'assets/branding/app_icon.png',
          width: 210,
          height: 210,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 22),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF24262A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Color(0xFFEFEFF1),
              fontSize: 18,
              height: 1.38,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF87878D)),
              SizedBox(width: 12),
              Text(
                'Thoughts',
                style: TextStyle(color: Color(0xFF87878D), fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            message.content,
            style: const TextStyle(
              color: Color(0xFFE7E7E9),
              fontSize: 20,
              height: 1.52,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('HH:mm').format(message.createdAt.toLocal()),
            style: const TextStyle(color: Color(0xFF727278), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TypingBlock extends StatelessWidget {
  const _TypingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Text(
            'NeuraX is thinking...',
            style: TextStyle(color: Color(0xFFB8B8BD), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onAttach,
    required this.onModel,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF313237)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(color: Color(0xFFEFEFF1), fontSize: 19),
            decoration: const InputDecoration(
              hintText: 'Ask anything',
              hintStyle: TextStyle(color: Color(0xFF787980), fontSize: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RoundIconButton(icon: Icons.add_rounded, onTap: onAttach),
              const SizedBox(width: 8),
              _ModePill(onTap: onModel),
              const Spacer(),
              _RoundIconButton(icon: Icons.mic_none_rounded, onTap: () {}),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isSending ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFECEDEF),
                  disabledBackgroundColor: const Color(0xFF4A4B50),
                  foregroundColor: const Color(0xFF111113),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
                child: Icon(
                  isSending
                      ? Icons.more_horiz_rounded
                      : Icons.arrow_upward_rounded,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFF2A2B30),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFE9E9EB), size: 28),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2B30),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Fast',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFB6B6BB)),
          ],
        ),
      ),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  const _AttachMenu();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      margin: const EdgeInsets.only(left: 28, bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF313237)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuRow(icon: Icons.photo_camera_outlined, label: 'Camera'),
          _MenuRow(icon: Icons.image_outlined, label: 'Gallery'),
          _MenuRow(icon: Icons.insert_drive_file_outlined, label: 'Files'),
          _MenuRow(icon: Icons.grid_view_rounded, label: 'Connectors'),
        ],
      ),
    );
  }
}

class _ModelMenu extends StatelessWidget {
  const _ModelMenu();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF313237)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NeuraX',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10),
          _MenuRow(icon: Icons.psychology_alt_outlined, label: 'Expert'),
          _SelectedMenuRow(icon: Icons.bolt_rounded, label: 'Fast'),
          _MenuRow(icon: Icons.rocket_launch_outlined, label: 'Auto'),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFBEBEC4), size: 28),
          const SizedBox(width: 22),
          Text(
            label,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SelectedMenuRow extends StatelessWidget {
  const _SelectedMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF34363B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(width: 22),
          Text(
            label,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

class _NeuraXDrawer extends StatelessWidget {
  const _NeuraXDrawer({required this.user, required this.onSettings});

  final SessionUser user;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF171719),
      width: MediaQuery.sizeOf(context).width * .92,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user.photoUrl == null
                        ? null
                        : NetworkImage(user.photoUrl!),
                    child: user.photoUrl == null
                        ? Text(_initial(user.name))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _DrawerTile(icon: Icons.alarm_on_rounded, label: 'Tasks'),
              const SizedBox(height: 28),
              const Text(
                'Conversations',
                style: TextStyle(
                  color: Color(0xFF8C8C92),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _ConversationTile(title: 'New conversation', time: 'Today'),
              const _ConversationTile(
                title: 'Oracle AI setup',
                time: 'Yesterday',
              ),
              const _ConversationTile(
                title: 'Firebase login',
                time: 'Yesterday',
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242426),
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: Color(0xFFB8B8BD)),
                          SizedBox(width: 10),
                          Text(
                            'Search',
                            style: TextStyle(
                              color: Color(0xFFB8B8BD),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      onSettings();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 20),
          Text(
            label,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.title, required this.time});

  final String title;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 5),
                Text(time, style: const TextStyle(color: Color(0xFF8C8C92))),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, color: Color(0xFF9A9AA0)),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.user, required this.onSignOut});

  final SessionUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .86,
      minChildSize: .5,
      maxChildSize: .94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF171719),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 34),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _AccountCard(user: user),
              const SizedBox(height: 28),
              const _SettingsSection(
                title: 'App',
                children: [
                  _SettingsRow(
                    icon: Icons.contrast_rounded,
                    label: 'Appearance',
                    value: 'Dark',
                  ),
                  _SettingsRow(icon: Icons.vibration_rounded, label: 'Haptics'),
                  _SettingsRow(icon: Icons.widgets_outlined, label: 'Widget'),
                  _SettingsRow(icon: Icons.tune_rounded, label: 'Advanced'),
                ],
              ),
              const SizedBox(height: 26),
              const _SettingsSection(
                title: 'NeuraX',
                children: [
                  _SettingsRow(
                    icon: Icons.graphic_eq_rounded,
                    label: 'Voice',
                    value: 'Ara',
                  ),
                  _SettingsRow(
                    icon: Icons.link_rounded,
                    label: 'Shared Conversations',
                  ),
                  _SettingsRow(
                    icon: Icons.storage_rounded,
                    label: 'Data Controls',
                  ),
                  _SettingsRow(
                    icon: Icons.policy_outlined,
                    label: 'Privacy Policy',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SignOutRow(onTap: onSignOut),
              const SizedBox(height: 22),
              const Center(
                child: Text(
                  'NeuraX 1.0.0',
                  style: TextStyle(color: Color(0xFF77787D), fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundImage: user.photoUrl == null
                ? null
                : NetworkImage(user.photoUrl!),
            child: user.photoUrl == null ? Text(_initial(user.name)) : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFA8A8AD),
                    fontSize: 16,
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8C8C92),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: const Color(0xFF242426),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB8B8BD), size: 30),
          const SizedBox(width: 18),
          Text(
            label,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(color: Color(0xFFA8A8AD), fontSize: 16),
            ),
        ],
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF242426),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF5C64), size: 30),
            SizedBox(width: 18),
            Text(
              'Sign out',
              style: TextStyle(
                color: Color(0xFFFF5C64),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'N';
  return trimmed.characters.first.toUpperCase();
}
