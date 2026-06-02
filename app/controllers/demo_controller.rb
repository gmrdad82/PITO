# frozen_string_literal: true

class DemoController < ApplicationController
  before_action { raise ActionController::RoutingError, "Not Found" unless Rails.env.development? }

  def show
  end
end
