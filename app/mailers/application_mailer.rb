class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Inventory <noreply@optimisedthought.com>")
  layout "mailer"
end
