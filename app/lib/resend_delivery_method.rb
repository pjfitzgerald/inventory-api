# ActionMailer delivery method that sends via Resend's HTTP API instead of
# SMTP. Registered as :resend in config/environments/production.rb — see
# Gemfile for why (smtp.resend.com is unreachable from Railway's network).
class ResendDeliveryMethod
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    Resend.api_key = @settings.fetch(:api_key)

    params = {
      from: mail[:from].to_s,
      to: Array(mail.to),
      subject: mail.subject
    }
    params[:cc] = Array(mail.cc) if mail.cc.present?
    params[:bcc] = Array(mail.bcc) if mail.bcc.present?

    if mail.multipart?
      params[:html] = mail.html_part.body.decoded
      params[:text] = mail.text_part.body.decoded
    elsif mail.content_type.to_s.include?("html")
      params[:html] = mail.body.decoded
    else
      params[:text] = mail.body.decoded
    end

    Resend::Emails.send(params)
  end
end
