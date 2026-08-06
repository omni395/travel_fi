# frozen_string_literal: true

#
# Custom WebPush delivery method for Noticed 2.0
#
class Noticed::DeliveryMethods::WebPush < Noticed::DeliveryMethod
  #
  # Deliver the notification using the web-push gem
  #
  def deliver
    # This assumes the recipient has a way to store and retrieve their push subscriptions.
    # For now, we'll implement the logic to send the push via the web-push gem.
    return unless recipient.respond_to?(:push_subscriptions)

    recipient.push_subscriptions.each do |subscription|
      begin
        Webpush.payload_send(
          message: JSON.generate(notification_payload),
          endpoint: subscription[:endpoint],
          p256dh: subscription[:p256dh],
          auth: subscription[:auth],
          vapid: {
            public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
            private_key: ENV.fetch("VAPID_PRIVATE_KEY")
          }
        )
      rescue Webpush::ExpiredSubscription => e
        # Handle expired subscription (e.g., remove it from the database)
        Rails.logger.warn("WebPush subscription expired: #{e.message}")
        # subscription.destroy if subscription.respond_to?(:destroy)
      rescue StandardError => e
        Rails.logger.error("WebPush delivery error: #{e.message}")
      end
    end
  end

  private

  #
  # Formats the notification payload for the push message
  #
  def notification_payload
    {
      title: notification.message,
      body: notification.params[:body] || "",
      icon: "/icon.png",
      data: {
        url: notification.params[:url] || "/",
        event_type: notification.params[:event_type]
      }
    }
  end
end
