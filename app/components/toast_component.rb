# Usage:
#   <%= render Shared::Notifications::ToastComponent.new("Message text", type: "success", dismissible: true, auto_dismiss: 5000) %>
#   
# Parameters:
#   - message: String - notification message
#   - type: String - toast type (success, info, warning, error) - required
#   - dismissible: Boolean - show close button - required
#   - auto_dismiss: Integer - auto-dismiss timeout in ms (0 = no auto-dismiss) - required

module Shared
  module Notifications
    class ToastComponent < ViewComponent::Base
      attr_reader :message, :type, :dismissible, :auto_dismiss, :id

  def initialize(message, type: 'info', dismissible: true, auto_dismiss: 3000)
    @message = message
    @type = type.to_s
    @dismissible = dismissible
    @auto_dismiss = auto_dismiss
    @id = "toast-#{SecureRandom.hex(4)}"
    @alert_class = alert_class
  end

  def icon_class
    case @type
    when 'success'
      'mdi mdi-check-circle'
    when 'error'
      'mdi mdi-alert-circle'
    when 'warning'
      'mdi mdi-alert-outline'
    when 'info'
      'mdi mdi-information-outline'
    else
      'mdi mdi-information-outline'
    end
  end

  def alert_class
    case @type
    when 'success'
      'alert-success'
    when 'error'
      'alert-error'
    when 'warning'
      'alert-warning'
    when 'info'
      'alert-info'
    else
      'alert-info'
    end
  end
    end
  end
end

