import 'package:flutter/material.dart';
import 'package:frontend/models/message.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/utils/date_fomatter.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final User? sender;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.sender,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture on the left for other users
          if (!isMe) ...[_buildProfilePicture(theme), const SizedBox(width: 8)],

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name for other users
                if (!isMe && sender != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      sender!.fullName.isNotEmpty
                          ? sender!.fullName
                          : sender!.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Message content
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 18 : 4),
                      topRight: Radius.circular(isMe ? 4 : 18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message content based on type
                      if (message.type == MessageType.image)
                        _buildImageContent(textColor)
                      else if (message.type == MessageType.document)
                        _buildDocumentContent(textColor)
                      else
                        _buildTextContent(textColor),

                      const SizedBox(height: 4),

                      // Timestamp
                      Text(
                        DateFormatter.formatDateTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Profile picture on the right for current user
          if (isMe) ...[const SizedBox(width: 8), _buildProfilePicture(theme)],
        ],
      ),
    );
  }

  Widget _buildProfilePicture(ThemeData theme) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.primary,
      backgroundImage: sender?.profilePicture != null
          ? NetworkImage('http://10.0.2.2:3000/${sender!.profilePicture}')
          : null,
      child: sender?.profilePicture == null
          ? Text(
              sender?.getInitials() ?? '?',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildTextContent(Color textColor) {
    return Text(
      message.content,
      style: TextStyle(color: textColor, fontSize: 15),
    );
  }

  Widget _buildImageContent(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: message.mediaUrl != null
                ? DecorationImage(
                    image: NetworkImage(
                      'http://10.0.2.2:3000/${message.mediaUrl}',
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: message.mediaUrl == null
              ? Center(
                  child: Icon(
                    Icons.image,
                    color: textColor.withOpacity(0.7),
                    size: 32,
                  ),
                )
              : null,
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message.content, style: TextStyle(color: textColor)),
        ],
      ],
    );
  }

  Widget _buildDocumentContent(Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.insert_drive_file,
          color: textColor.withOpacity(0.7),
          size: 24,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
              if (message.mediaUrl != null)
                Text(
                  'Document',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
