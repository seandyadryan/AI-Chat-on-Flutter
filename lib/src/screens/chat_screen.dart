import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/session_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

enum _AppearanceMode { system, dark, light }

enum _LanguageMode { system, indonesian, english }

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
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _uuid = const Uuid();
  final List<ChatMessage> _messages = [];
  final List<_AttachmentDraft> _attachments = [];

  _AppearanceMode _appearance = _AppearanceMode.dark;
  _LanguageMode _language = _LanguageMode.system;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showAttachMenu = false;
  bool _showModelMenu = false;
  String _searchQuery = '';
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
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || _isSending) return;

    final attachmentText = _attachments
        .map((item) => '- ${item.source}: ${item.name}')
        .join('\n');
    final content = attachmentText.isEmpty
        ? text
        : [
            if (text.isNotEmpty) text,
            'Lampiran dipilih:',
            attachmentText,
          ].join('\n');

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );

    setState(() {
      _controller.clear();
      _attachments.clear();
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
        message: content,
      );
      if (!mounted) return;
      setState(() => _messages.add(assistant.copyWith(content: '')));
      await _typeAssistantReply(assistant);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _typeAssistantReply(ChatMessage assistant) async {
    final messageIndex = _messages.indexWhere(
      (item) => item.id == assistant.id,
    );
    if (messageIndex == -1) return;

    final words = assistant.content.trim().split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
      if (!mounted) return;
      if (wordIndex > 0) buffer.write(' ');
      buffer.write(words[wordIndex]);
      setState(() {
        _messages[messageIndex] = assistant.copyWith(
          content: buffer.toString(),
        );
      });
      _scrollToBottom();
      await Future<void>.delayed(const Duration(milliseconds: 34));
    }
  }

  Future<void> _pickCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnack('Izin kamera belum diberikan.');
      return;
    }
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (image == null) return;
    _addAttachment('Camera', image.name);
  }

  Future<void> _pickGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (image == null) return;
    _addAttachment('Gallery', image.name);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: false);
    final file = result?.files.single;
    if (file == null) return;
    _addAttachment('Files', file.name);
  }

  Future<void> _requestMicrophone() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (status.isGranted) {
      _showSnack('Izin mikrofon aktif. Tombol rekam suara sudah siap izin.');
    } else {
      _showSnack('Izin mikrofon belum diberikan.');
    }
  }

  void _addAttachment(String source, String name) {
    setState(() {
      _attachments.add(_AttachmentDraft(source: source, name: name));
      _showAttachMenu = false;
    });
    _showSnack('$source ditambahkan: $name');
  }

  void _removeAttachment(_AttachmentDraft attachment) {
    setState(() => _attachments.remove(attachment));
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _error = null;
    });
    _showSnack('Chat dibersihkan dari tampilan lokal.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsSheet(
        user: widget.user,
        appearance: _appearance,
        language: _language,
        onAppearanceChanged: (value) => setState(() => _appearance = value),
        onLanguageChanged: (value) => setState(() => _language = value),
        onSignOut: _signOut,
      ),
    );
  }

  List<ChatMessage> get _visibleMessages {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _messages;
    return _messages
        .where((message) => message.content.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ChatPalette.resolve(context, _appearance);
    final visibleMessages = _visibleMessages;

    return Scaffold(
      backgroundColor: palette.background,
      drawer: _NeuraXDrawer(
        user: widget.user,
        messages: _messages,
        searchController: _searchController,
        searchQuery: _searchQuery,
        palette: palette,
        onSearchChanged: (value) => setState(() => _searchQuery = value),
        onSettings: _openSettings,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(
                  palette: palette,
                  onRefresh: _loadMessages,
                  onClearChat: _clearChat,
                ),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: palette.primaryText,
                          ),
                        )
                      : visibleMessages.isEmpty
                      ? _EmptyState(palette: palette)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 132),
                          itemCount:
                              visibleMessages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == visibleMessages.length) {
                              return _TypingBlock(palette: palette);
                            }
                            return _MessageBlock(
                              message: visibleMessages[index],
                              palette: palette,
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF5C64),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (_showAttachMenu)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _AttachMenu(
                        palette: palette,
                        onCamera: _pickCamera,
                        onGallery: _pickGallery,
                        onFiles: _pickFile,
                      ),
                    ),
                  if (_showModelMenu)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ModelMenu(palette: palette),
                    ),
                  _Composer(
                    controller: _controller,
                    attachments: _attachments,
                    isSending: _isSending,
                    palette: palette,
                    onSend: _send,
                    onAttach: () => setState(() {
                      _showAttachMenu = !_showAttachMenu;
                      _showModelMenu = false;
                    }),
                    onModel: () => setState(() {
                      _showModelMenu = !_showModelMenu;
                      _showAttachMenu = false;
                    }),
                    onMic: _requestMicrophone,
                    onRemoveAttachment: _removeAttachment,
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
  const _TopBar({
    required this.palette,
    required this.onRefresh,
    required this.onClearChat,
  });

  final _ChatPalette palette;
  final VoidCallback onRefresh;
  final VoidCallback onClearChat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(
                  Icons.menu_rounded,
                  size: 28,
                  color: palette.primaryText,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Ask',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Opsi',
              color: palette.panel,
              icon: Icon(
                Icons.more_vert_rounded,
                color: palette.primaryText,
                size: 27,
              ),
              onSelected: (value) {
                if (value == 'refresh') onRefresh();
                if (value == 'clear') onClearChat();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Text('Refresh chat', style: palette.menuTextStyle),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear chat', style: palette.menuTextStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: palette.isLight ? .12 : .09,
        child: Image.asset(
          'assets/branding/app_icon.png',
          width: 132,
          height: 132,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.message, required this.palette});

  final ChatMessage message;
  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .74,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: palette.userBubble,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: palette.userBubbleText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: palette.secondaryText,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Thoughts',
                style: TextStyle(color: palette.secondaryText, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message.content,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 16,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('HH:mm').format(message.createdAt.toLocal()),
            style: TextStyle(color: palette.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TypingBlock extends StatelessWidget {
  const _TypingBlock({required this.palette});

  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.primaryText,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'NeuraX is thinking...',
            style: TextStyle(color: palette.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.attachments,
    required this.isSending,
    required this.palette,
    required this.onSend,
    required this.onAttach,
    required this.onModel,
    required this.onMic,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final List<_AttachmentDraft> attachments;
  final bool isSending;
  final _ChatPalette palette;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onModel;
  final VoidCallback onMic;
  final ValueChanged<_AttachmentDraft> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.composer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return InputChip(
                      label: Text(
                        attachment.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () => onRemoveAttachment(attachment),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(color: palette.primaryText, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Ask anything',
              hintStyle: TextStyle(color: palette.mutedText, fontSize: 15),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.add_rounded,
                palette: palette,
                onTap: onAttach,
              ),
              const SizedBox(width: 8),
              _ModePill(palette: palette, onTap: onModel),
              const Spacer(),
              _RoundIconButton(
                icon: Icons.mic_none_rounded,
                palette: palette,
                onTap: onMic,
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isSending ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primaryText,
                  disabledBackgroundColor: palette.disabled,
                  foregroundColor: palette.background,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                ),
                child: Icon(
                  isSending
                      ? Icons.more_horiz_rounded
                      : Icons.arrow_upward_rounded,
                  size: 23,
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
  const _RoundIconButton({
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final _ChatPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: palette.button,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.primaryText, size: 24),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.palette, required this.onTap});

  final _ChatPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: palette.button,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: palette.primaryText, size: 21),
            const SizedBox(width: 6),
            Text(
              'Fast',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: palette.secondaryText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  const _AttachMenu({
    required this.palette,
    required this.onCamera,
    required this.onGallery,
    required this.onFiles,
  });

  final _ChatPalette palette;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      margin: const EdgeInsets.only(left: 18, bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuRow(
            icon: Icons.photo_camera_outlined,
            label: 'Camera',
            palette: palette,
            onTap: onCamera,
          ),
          _MenuRow(
            icon: Icons.image_outlined,
            label: 'Gallery',
            palette: palette,
            onTap: onGallery,
          ),
          _MenuRow(
            icon: Icons.insert_drive_file_outlined,
            label: 'Files',
            palette: palette,
            onTap: onFiles,
          ),
        ],
      ),
    );
  }
}

class _ModelMenu extends StatelessWidget {
  const _ModelMenu({required this.palette});

  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NeuraX',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _SelectedMenuRow(
            icon: Icons.bolt_rounded,
            label: 'Fast',
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.palette,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final _ChatPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: palette.secondaryText, size: 23),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMenuRow extends StatelessWidget {
  const _SelectedMenuRow({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.selected,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.primaryText, size: 24),
          const SizedBox(width: 15),
          Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 42),
          Icon(Icons.check_rounded, color: palette.primaryText, size: 23),
        ],
      ),
    );
  }
}

class _NeuraXDrawer extends StatelessWidget {
  const _NeuraXDrawer({
    required this.user,
    required this.messages,
    required this.searchController,
    required this.searchQuery,
    required this.palette,
    required this.onSearchChanged,
    required this.onSettings,
  });

  final SessionUser user;
  final List<ChatMessage> messages;
  final TextEditingController searchController;
  final String searchQuery;
  final _ChatPalette palette;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final conversations = messages
        .where((item) => item.isUser)
        .where(
          (item) => searchQuery.trim().isEmpty
              ? true
              : item.content.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList()
        .reversed
        .take(12)
        .toList();

    return Drawer(
      backgroundColor: palette.sheet,
      width: MediaQuery.sizeOf(context).width * .86,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: user.photoUrl == null
                        ? null
                        : NetworkImage(user.photoUrl!),
                    child: user.photoUrl == null
                        ? Text(_initial(user.name))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      color: palette.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Conversations',
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: conversations.isEmpty
                    ? Center(
                        child: Text(
                          searchQuery.isEmpty
                              ? 'Belum ada chat.'
                              : 'Chat tidak ditemukan.',
                          style: TextStyle(color: palette.secondaryText),
                        ),
                      )
                    : ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) => _ConversationTile(
                          message: conversations[index],
                          palette: palette,
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.panel,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: palette.secondaryText,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: onSearchChanged,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                  color: palette.secondaryText,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.settings_rounded,
                    palette: palette,
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.message, required this.palette});

  final ChatMessage message;
  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    final title = message.content.split('\n').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'New conversation' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.primaryText, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.createdAt.toLocal()),
                  style: TextStyle(color: palette.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.more_vert_rounded, color: palette.secondaryText, size: 20),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.user,
    required this.appearance,
    required this.language,
    required this.onAppearanceChanged,
    required this.onLanguageChanged,
    required this.onSignOut,
  });

  final SessionUser user;
  final _AppearanceMode appearance;
  final _LanguageMode language;
  final ValueChanged<_AppearanceMode> onAppearanceChanged;
  final ValueChanged<_LanguageMode> onLanguageChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    var selectedAppearance = appearance;
    var selectedLanguage = language;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final palette = _ChatPalette.resolve(context, selectedAppearance);
        return Container(
          color: Colors.transparent,
          child: DraggableScrollableSheet(
            initialChildSize: .82,
            minChildSize: .48,
            maxChildSize: .94,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: palette.sheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: palette.primaryText,
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AccountCard(user: user, palette: palette),
                    const SizedBox(height: 24),
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AppearancePicker(
                      palette: palette,
                      value: selectedAppearance,
                      onChanged: (value) {
                        setSheetState(() => selectedAppearance = value);
                        onAppearanceChanged(value);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Language',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LanguagePicker(
                      palette: palette,
                      value: selectedLanguage,
                      onChanged: (value) {
                        setSheetState(() => selectedLanguage = value);
                        onLanguageChanged(value);
                      },
                    ),
                    const SizedBox(height: 24),
                    _SettingsRow(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Voice',
                      value: 'Permission ready',
                      palette: palette,
                    ),
                    _SettingsRow(
                      icon: Icons.policy_outlined,
                      label: 'Privacy Policy',
                      value: 'amarlo.online',
                      palette: palette,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://amarlo.online/ai-chat/kebijakan-privasi/',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SignOutRow(onTap: onSignOut, palette: palette),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'NeuraX 1.0.0',
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  final _ChatPalette palette;
  final _LanguageMode value;
  final ValueChanged<_LanguageMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LanguageTile(
          label: 'Default perangkat',
          value: 'System language',
          selected: value == _LanguageMode.system,
          palette: palette,
          onTap: () => onChanged(_LanguageMode.system),
        ),
        _LanguageTile(
          label: 'Bahasa Indonesia',
          value: 'Indonesian',
          selected: value == _LanguageMode.indonesian,
          palette: palette,
          onTap: () => onChanged(_LanguageMode.indonesian),
        ),
        _LanguageTile(
          label: 'English',
          value: 'English',
          selected: value == _LanguageMode.english,
          palette: palette,
          onTap: () => onChanged(_LanguageMode.english),
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.value,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final _ChatPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? palette.selected : palette.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.primaryText : palette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.language_rounded,
              color: palette.secondaryText,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: palette.primaryText, size: 22),
          ],
        ),
      ),
    );
  }
}

class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker({
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  final _ChatPalette palette;
  final _AppearanceMode value;
  final ValueChanged<_AppearanceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AppearanceButton(
          icon: Icons.settings_suggest_rounded,
          label: 'Default',
          selected: value == _AppearanceMode.system,
          palette: palette,
          onTap: () => onChanged(_AppearanceMode.system),
        ),
        const SizedBox(width: 8),
        _AppearanceButton(
          icon: Icons.dark_mode_rounded,
          label: 'Dark',
          selected: value == _AppearanceMode.dark,
          palette: palette,
          onTap: () => onChanged(_AppearanceMode.dark),
        ),
        const SizedBox(width: 8),
        _AppearanceButton(
          icon: Icons.light_mode_rounded,
          label: 'Light',
          selected: value == _AppearanceMode.light,
          palette: palette,
          onTap: () => onChanged(_AppearanceMode.light),
        ),
      ],
    );
  }
}

class _AppearanceButton extends StatelessWidget {
  const _AppearanceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final _ChatPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: selected ? palette.primaryText : palette.panel,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? palette.background : palette.primaryText,
                size: 25,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? palette.background : palette.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.palette});

  final SessionUser user;
  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: user.photoUrl == null
                ? null
                : NetworkImage(user.photoUrl!),
            child: user.photoUrl == null ? Text(_initial(user.name)) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.palette,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final _ChatPalette palette;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 62,
        margin: const EdgeInsets.only(bottom: 2),
        color: palette.panel,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Row(
          children: [
            Icon(icon, color: palette.secondaryText, size: 24),
            const SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.secondaryText, fontSize: 13),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                color: palette.secondaryText,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onTap, required this.palette});

  final VoidCallback onTap;
  final _ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF5C64), size: 25),
            SizedBox(width: 15),
            Text(
              'Sign out',
              style: TextStyle(
                color: Color(0xFFFF5C64),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentDraft {
  const _AttachmentDraft({required this.source, required this.name});

  final String source;
  final String name;
}

class _ChatPalette {
  const _ChatPalette({
    required this.isLight,
    required this.background,
    required this.sheet,
    required this.panel,
    required this.composer,
    required this.button,
    required this.selected,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.userBubble,
    required this.userBubbleText,
    required this.disabled,
  });

  final bool isLight;
  final Color background;
  final Color sheet;
  final Color panel;
  final Color composer;
  final Color button;
  final Color selected;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color userBubble;
  final Color userBubbleText;
  final Color disabled;

  TextStyle get menuTextStyle => TextStyle(color: primaryText, fontSize: 14);

  static _ChatPalette resolve(BuildContext context, _AppearanceMode mode) {
    final useLight = switch (mode) {
      _AppearanceMode.light => true,
      _AppearanceMode.dark => false,
      _AppearanceMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.light,
    };

    if (useLight) {
      return const _ChatPalette(
        isLight: true,
        background: Color(0xFFF6F6F3),
        sheet: Color(0xFFFFFFFF),
        panel: Color(0xFFE9E9E5),
        composer: Color(0xFFFFFFFF),
        button: Color(0xFFE8E8E4),
        selected: Color(0xFFDADAD4),
        border: Color(0xFFD8D8D2),
        primaryText: Color(0xFF111113),
        secondaryText: Color(0xFF6F7077),
        mutedText: Color(0xFF8F9096),
        userBubble: Color(0xFF111113),
        userBubbleText: Color(0xFFFFFFFF),
        disabled: Color(0xFFC9C9C5),
      );
    }

    return const _ChatPalette(
      isLight: false,
      background: Color(0xFF111113),
      sheet: Color(0xFF171719),
      panel: Color(0xFF222326),
      composer: Color(0xFF202124),
      button: Color(0xFF2A2B30),
      selected: Color(0xFF34363B),
      border: Color(0xFF313237),
      primaryText: Color(0xFFEFEFF1),
      secondaryText: Color(0xFF9B9CA2),
      mutedText: Color(0xFF77787D),
      userBubble: Color(0xFF2B2D31),
      userBubbleText: Color(0xFFEFEFF1),
      disabled: Color(0xFF4A4B50),
    );
  }
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'N';
  return trimmed.characters.first.toUpperCase();
}
