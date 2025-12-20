# Action Cable Patterns: Common Use Cases

## Real-Time Chat

### Server-Side

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find(params[:room_id])
    reject unless room.accessible_by?(current_user)

    stream_from "chat_#{params[:room_id]}"
  end

  def speak(data)
    message = Message.create!(
      room_id: params[:room_id],
      user: current_user,
      content: data['message']
    )
  end

  def typing(data)
    ActionCable.server.broadcast(
      "chat_#{params[:room_id]}_typing",
      { user: current_user.name, typing: data['typing'] }
    )
  end
end

# app/models/message.rb
class Message < ApplicationRecord
  after_create_commit :broadcast_message

  private

  def broadcast_message
    ActionCable.server.broadcast(
      "chat_#{room_id}",
      {
        type: 'message',
        html: ApplicationController.render(
          partial: 'messages/message',
          locals: { message: self }
        ),
        user_id: user_id
      }
    )
  end
end
```

### Client-Side

```javascript
// app/javascript/channels/chat_channel.js
import consumer from "./consumer"

const chatChannel = consumer.subscriptions.create(
  { channel: "ChatChannel", room_id: getRoomId() },
  {
    received(data) {
      if (data.type === 'message') {
        appendMessage(data.html)
        scrollToBottom()
      }
    },

    speak(message) {
      this.perform("speak", { message: message })
    },

    startTyping() {
      this.perform("typing", { typing: true })
    },

    stopTyping() {
      this.perform("typing", { typing: false })
    }
  }
)

// Send message on form submit
document.querySelector("#message-form").addEventListener("submit", (e) => {
  e.preventDefault()
  const input = e.target.querySelector("input")
  chatChannel.speak(input.value)
  input.value = ""
})
```

## Live Notifications

### Server-Side

```ruby
# app/channels/notification_channel.rb
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def mark_as_read(data)
    notification = current_user.notifications.find(data['id'])
    notification.update(read_at: Time.current)
  end
end

# Broadcasting from anywhere in app
class CommentService
  def create_comment(post, user, content)
    comment = post.comments.create!(user: user, content: content)

    # Notify post author
    NotificationChannel.broadcast_to(
      post.user,
      {
        html: render_notification(comment),
        count: post.user.notifications.unread.count
      }
    )
  end

  private

  def render_notification(comment)
    ApplicationController.render(
      partial: 'notifications/comment',
      locals: { comment: comment }
    )
  end
end
```

### Client-Side

```javascript
import consumer from "./consumer"

consumer.subscriptions.create("NotificationChannel", {
  received(data) {
    // Add notification to list
    document.getElementById("notifications").insertAdjacentHTML("afterbegin", data.html)

    // Update counter
    document.getElementById("notification-count").textContent = data.count

    // Optional: Show toast
    showToast("New notification")
  },

  markAsRead(id) {
    this.perform("mark_as_read", { id: id })
  }
})
```

## Presence Tracking

### Server-Side

```ruby
# app/channels/appearance_channel.rb
class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "appearances"
    appear
  end

  def unsubscribed
    disappear
  end

  def appear
    current_user.update(online: true, last_seen_at: Time.current)
    broadcast_presence("online")
  end

  def away
    current_user.update(online: false)
    broadcast_presence("away")
  end

  private

  def broadcast_presence(status)
    ActionCable.server.broadcast("appearances", {
      user_id: current_user.id,
      username: current_user.name,
      avatar_url: current_user.avatar_url,
      status: status,
      timestamp: Time.current.to_i
    })
  end

  def disappear
    current_user.update(online: false)
    broadcast_presence("offline")
  end
end
```

### Client-Side

```javascript
import consumer from "./consumer"

const appearanceChannel = consumer.subscriptions.create("AppearanceChannel", {
  received(data) {
    updateUserPresence(data.user_id, data.status)
  }
})

// Track user activity
let activityTimeout
document.addEventListener("mousemove", () => {
  clearTimeout(activityTimeout)
  appearanceChannel.appear()

  activityTimeout = setTimeout(() => {
    appearanceChannel.away()
  }, 5 * 60 * 1000)  // 5 minutes
})
```

## Live Dashboard Updates

### Server-Side

```ruby
# app/channels/dashboard_channel.rb
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user.admin?
    stream_from "dashboard"
  end
end

# Broadcast from background job
class DashboardUpdateJob < ApplicationJob
  def perform
    stats = calculate_stats

    ActionCable.server.broadcast("dashboard", {
      revenue: stats[:revenue],
      orders: stats[:orders],
      users: stats[:users],
      html: ApplicationController.render(
        partial: 'dashboard/stats',
        locals: { stats: stats }
      )
    })
  end
end

# Schedule periodic updates
# config/recurring.yml (with solid_queue)
dashboard_update:
  class: DashboardUpdateJob
  schedule: "*/5 * * * *"  # Every 5 minutes
```

## Collaborative Editing

### Server-Side

```ruby
# app/channels/document_channel.rb
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    @document = Document.find(params[:document_id])
    reject unless @document.editable_by?(current_user)

    stream_from "document_#{params[:document_id]}"
  end

  def update(data)
    @document.update(content: data['content'])

    # Broadcast to others (not sender)
    ActionCable.server.broadcast(
      "document_#{params[:document_id]}",
      {
        type: 'update',
        content: data['content'],
        user_id: current_user.id,
        cursor_position: data['cursor']
      }
    )
  end

  def cursor_move(data)
    ActionCable.server.broadcast(
      "document_#{params[:document_id]}_cursors",
      {
        user_id: current_user.id,
        username: current_user.name,
        position: data['position']
      }
    )
  end
end
```

## Performance Patterns

### Scoped Broadcasts

Broadcast to specific subsets:

```ruby
# Per-user stream
stream_for current_user

# Per-room stream
stream_from "chat_room_#{room_id}"

# Per-organization stream
stream_from "org_#{current_user.organization_id}"
```

### Throttling Broadcasts

Avoid overwhelming clients:

```ruby
class PositionChannel < ApplicationCable::Channel
  def update_position(data)
    # Throttle to max 10 updates/second
    return if recently_updated?

    @last_update = Time.current
    broadcast_position(data)
  end

  private

  def recently_updated?
    @last_update && @last_update > 0.1.seconds.ago
  end
end
```

### Partial Rendering Caching

Cache rendered partials:

```ruby
def broadcast_product
  html = Rails.cache.fetch("product_#{id}/card", expires_in: 5.minutes) do
    ApplicationController.render(partial: 'products/card', locals: { product: self })
  end

  ActionCable.server.broadcast("products", { html: html })
end
```

## Security

### Authorization

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find(params[:room_id])

    if room.accessible_by?(current_user)
      stream_from "chat_#{params[:room_id]}"
    else
      reject
    end
  end
end
```

### Input Validation

```ruby
def speak(data)
  return unless data['message'].present?
  return if data['message'].length > 500

  message = Message.new(
    room_id: params[:room_id],
    user: current_user,
    content: sanitize_message(data['message'])
  )

  message.save! if message.valid?
end

private

def sanitize_message(content)
  ActionController::Base.helpers.sanitize(content)
end
```

## Monitoring

```ruby
# Number of active connections
ActionCable.server.connections.size

# Broadcast to all connections
ActionCable.server.broadcast("global", { message: "Server maintenance in 5 minutes" })

# Disconnect specific user
ActionCable.server.remote_connections.where(current_user: user).disconnect
```

## Best Practices

1. **Authenticate connections** in ApplicationCable::Connection
2. **Authorize channel subscriptions** in #subscribed
3. **Validate inputs** in channel actions
4. **Sanitize output** before broadcasting
5. **Use scoped streams** (per-user, per-room)
6. **Cache rendered partials** for broadcasts
7. **Throttle high-frequency updates**
8. **Monitor connection counts** and bandwidth
9. **Test channels** with ActionCable::Channel::TestCase
10. **Use Solid Cable** unless you need Redis performance

Master Action Cable and you'll build real-time features that delight users.
