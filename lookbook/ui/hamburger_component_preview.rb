# frozen_string_literal: true

class Ui::HamburgerComponentPreview < Lookbook::Preview
  # @label Default Dropdown
  def default
    render Ui::HamburgerComponent.new
  end

  # @label Position Left
  def position_left
    render Ui::HamburgerComponent.new(position: "left")
  end

  # @label Custom Trigger Button
  def custom_trigger
    render Ui::HamburgerComponent.new
  end
end
