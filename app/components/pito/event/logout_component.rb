# frozen_string_literal: true

module Pito
  module Event
    class LogoutComponent < ViewComponent::Base
      def initialize(payload: {})
        @text = payload[:text].presence || I18n.t("pito.auth.logouts").sample
      end
    end
  end
end
