# Action Cable Examples: Real-Time Features
#
# Complete examples of Action Cable channels and broadcasting patterns

# ==============================================================================
# EXAMPLE 1: Chat Room Channel
# ==============================================================================

# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find(params[:room_id])

    # Authorize access
    reject unless @room.accessible_by?(current_user)

    # Subscribe to room broadcasts
    stream_from "chat_room_#{@room.id}"

    # Notify others user joined
    broadcast_presence("joined")
  end

  def unsubscribed
    broadcast_presence("left") if @room
  end

  def speak(data)
    message = @room.messages.create!(
      user: current_user,
      content: sanitize_content(data['message'])
    )
    # Message broadcasts itself via after_create_commit callback
  end

  def typing(data)
    # Ephemeral typing indicator (not persisted)
    ActionCable.server.broadcast(
      "chat_room_#{@room.id}_typing",
      {
        user_id: current_user.id,
        username: current_user.name,
        typing: data['typing']
      }
    )
  end

  private

  def broadcast_presence(action)
    ActionCable.server.broadcast(
      "chat_room_#{@room.id}_presence",
      {
        user_id: current_user.id,
        username: current_user.name,
        action: action,
        timestamp: Time.current.to_i
      }
    )
  end

  def sanitize_content(content)
    ActionController::Base.helpers.sanitize(content)
  end
end

# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :room
  belongs_to :user

  validates :content, presence: true, length: { maximum: 500 }

  # Broadcast after creation
  after_create_commit :broadcast_message

  private

  def broadcast_message
    ActionCable.server.broadcast(
      "chat_room_#{room_id}",
      {
        type: 'new_message',
        id: id,
        html: ApplicationController.render(
          partial: 'messages/message',
          locals: { message: self }
        ),
        user_id: user_id,
        timestamp: created_at.to_i
      }
    )
  end
end

# ==============================================================================
# EXAMPLE 2: User-Specific Notification Channel
# ==============================================================================

# app/channels/notification_channel.rb
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    # Stream notifications for current user only
    stream_for current_user
  end

  def mark_as_read(data)
    notification = current_user.notifications.find_by(id: data['id'])
    return unless notification

    notification.update(read_at: Time.current)

    # Broadcast updated count to user
    NotificationChannel.broadcast_to(
      current_user,
      {
        type: 'count_updated',
        unread_count: current_user.notifications.unread.count
      }
    )
  end

  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)

    NotificationChannel.broadcast_to(
      current_user,
      {
        type: 'all_read',
        unread_count: 0
      }
    )
  end
end

# Broadcasting from anywhere in the app
class NotificationService
  def self.notify(user, message, link = nil)
    notification = user.notifications.create!(
      message: message,
      link: link
    )

    # Broadcast to user's channel
    NotificationChannel.broadcast_to(
      user,
      {
        type: 'new_notification',
        html: render_notification(notification),
        unread_count: user.notifications.unread.count
      }
    )
  end

  private

  def self.render_notification(notification)
    ApplicationController.render(
      partial: 'notifications/notification',
      locals: { notification: notification }
    )
  end
end

# Usage:
# NotificationService.notify(user, "New comment on your post", post_path(post))

# ==============================================================================
# EXAMPLE 3: Presence/Online Status Channel
# ==============================================================================

# app/channels/appearance_channel.rb
class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "appearances"
    appear("online")
  end

  def unsubscribed
    appear("offline")
  end

  def appear(status = "online")
    current_user.update(
      online_status: status,
      last_seen_at: Time.current
    )

    broadcast_appearance(status)
  end

  def away
    appear("away")
  end

  private

  def broadcast_appearance(status)
    ActionCable.server.broadcast("appearances", {
      user_id: current_user.id,
      username: current_user.name,
      avatar_url: current_user.avatar_url,
      status: status,
      last_seen: current_user.last_seen_at.to_i
    })
  end
end

# Periodic cleanup of stale online statuses
class CleanupOnlineStatusJob < ApplicationJob
  def perform
    User.where(online_status: "online")
        .where("last_seen_at < ?", 10.minutes.ago)
        .update_all(online_status: "offline")
  end
end

# ==============================================================================
# EXAMPLE 4: Live Dashboard Channel (Admin Only)
# ==============================================================================

# app/channels/dashboard_channel.rb
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user.admin?

    stream_from "admin_dashboard"
  end

  def refresh
    # Manual refresh requested
    DashboardUpdateJob.perform_now
  end
end

# Background job to update dashboard
class DashboardUpdateJob < ApplicationJob
  queue_as :default

  def perform
    stats = {
      revenue_today: Order.today.sum(:total),
      orders_today: Order.today.count,
      new_users_today: User.where('created_at > ?', Date.today).count,
      active_users: User.where(online_status: "online").count
    }

    ActionCable.server.broadcast("admin_dashboard", {
      type: 'stats_update',
      stats: stats,
      html: render_dashboard(stats)
    })
  end

  private

  def render_dashboard(stats)
    ApplicationController.render(
      partial: 'dashboard/stats',
      locals: { stats: stats }
    )
  end
end

# Recurring job (with solid_queue)
# config/recurring.yml
# dashboard_update:
#   class: DashboardUpdateJob
#   schedule: "*/5 * * * *"  # Every 5 minutes

# ==============================================================================
# EXAMPLE 5: Multi-Room Chat with Private Messages
# ==============================================================================

# app/channels/multi_chat_channel.rb
class MultiChatChannel < ApplicationCable::Channel
  def subscribed
    # Can subscribe to multiple rooms
    room_ids = params[:room_ids] || []

    room_ids.each do |room_id|
      room = Room.find_by(id: room_id)
      next unless room&.accessible_by?(current_user)

      stream_from "chat_room_#{room_id}"
    end

    # Also subscribe to private messages
    stream_for current_user
  end

  def speak(data)
    room = Room.find(data['room_id'])
    return unless room.accessible_by?(current_user)

    message = room.messages.create!(
      user: current_user,
      content: data['message']
    )
  end

  def send_private_message(data)
    recipient = User.find(data['recipient_id'])

    # Broadcast to recipient only
    MultiChatChannel.broadcast_to(
      recipient,
      {
        type: 'private_message',
        from: current_user.name,
        message: data['message'],
        html: render_private_message(data['message'])
      }
    )
  end

  private

  def render_private_message(content)
    ApplicationController.render(
      partial: 'messages/private',
      locals: { content: content, from: current_user }
    )
  end
end

# ==============================================================================
# EXAMPLE 6: Collaborative Document Editing
# ==============================================================================

# app/channels/document_channel.rb
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    @document = Document.find(params[:document_id])
    reject unless @document.editable_by?(current_user)

    stream_from "document_#{@document.id}"
    stream_from "document_#{@document.id}_cursors"

    broadcast_editor_joined
  end

  def unsubscribed
    broadcast_editor_left if @document
  end

  def update_content(data)
    @document.update_column(:content, data['content'])

    ActionCable.server.broadcast(
      "document_#{@document.id}",
      {
        type: 'content_update',
        content: data['content'],
        user_id: current_user.id,
        version: @document.version
      }
    )
  end

  def cursor_position(data)
    ActionCable.server.broadcast(
      "document_#{@document.id}_cursors",
      {
        user_id: current_user.id,
        username: current_user.name,
        color: user_color,
        position: data['position']
      }
    )
  end

  def selection(data)
    ActionCable.server.broadcast(
      "document_#{@document.id}_cursors",
      {
        user_id: current_user.id,
        username: current_user.name,
        selection: data['range']
      }
    )
  end

  private

  def broadcast_editor_joined
    ActionCable.server.broadcast("document_#{@document.id}", {
      type: 'editor_joined',
      user_id: current_user.id,
      username: current_user.name
    })
  end

  def broadcast_editor_left
    ActionCable.server.broadcast("document_#{@document.id}", {
      type: 'editor_left',
      user_id: current_user.id
    })
  end

  def user_color
    # Consistent color per user
    colors = %w[#FF6B6B #4ECDC4 #45B7D1 #FFA07A #98D8C8]
    colors[current_user.id % colors.length]
  end
end

# ==============================================================================
# EXAMPLE 7: Live Feed Updates
# ==============================================================================

# app/channels/feed_channel.rb
class FeedChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def viewed(data)
    # Mark item as viewed
    FeedItem.find(data['id']).mark_viewed_by(current_user)
  end
end

# Broadcasting new feed items
class Post < ApplicationRecord
  after_create_commit :broadcast_to_followers

  private

  def broadcast_to_followers
    user.followers.find_each do |follower|
      FeedChannel.broadcast_to(
        follower,
        {
          type: 'new_post',
          html: ApplicationController.render(
            partial: 'posts/feed_item',
            locals: { post: self }
          )
        }
      )
    end
  end
end

# ==============================================================================
# KEY TAKEAWAYS
# ==============================================================================

# 1. CHANNELS:
#    - Like controllers for WebSockets
#    - subscribed() - when client connects
#    - unsubscribed() - when client disconnects
#    - Custom methods for client actions
#
# 2. STREAMING:
#    - stream_from "channel_name" - subscribe to broadcasts
#    - stream_for record - subscribe to record-specific broadcasts
#    - Use scoped streams for security and performance
#
# 3. BROADCASTING:
#    - ActionCable.server.broadcast() - send to channel
#    - ChannelName.broadcast_to(record, data) - send to record stream
#    - Broadcast from models, controllers, or jobs
#
# 4. AUTHENTICATION:
#    - Authenticate in ApplicationCable::Connection
#    - Authorize in channel's subscribed() method
#    - Reject unauthorized connections
#
# 5. SOLID CABLE:
#    - Database-backed pub/sub (Rails 8)
#    - No Redis needed
#    - ~100ms latency
#    - Perfect for most apps
#
# Master Action Cable and build real-time features that feel like magic!
