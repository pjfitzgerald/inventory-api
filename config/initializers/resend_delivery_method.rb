require Rails.root.join("app/lib/resend_delivery_method")

ActionMailer::Base.add_delivery_method :resend, ResendDeliveryMethod, api_key: ENV["RESEND_API_KEY"]
