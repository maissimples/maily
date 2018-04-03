module Maily
  class EmailsController < Maily::ApplicationController
    before_action :allowed_action?, only: [:edit, :update, :deliver]
    before_action :load_mailers, only: [:index, :show, :edit]
    before_action :load_mailer_and_email, except: [:index]
    around_action :perform_with_locale, only: [:show, :raw, :deliver]

    def index
    end

    def show
      valid, message = @maily_email.validate_arguments

      unless valid
        redirect_to(root_path, alert: message)
      end
    end

    def raw
      content = if @email.parts.present?
        params[:part] == 'text' ? @email.text_part.body.raw_source : htmlized
      else
        @email.body.raw_source
      end

      render text: content, layout: false
    end

    def attachment
      attachment = @email.attachments.find { |elem| elem.filename == params[:attachment] }

      send_data attachment.body, filename: attachment.filename, type: attachment.content_type
    end

    def edit
      @template = @maily_email.template(params[:part])
    end

    def update
      @maily_email.update_template(params[:body], params[:part])

      redirect_to maily_email_path(mailer: params[:mailer], email: params[:email], part: params[:part])
    end

    def deliver
      @email.to = params[:to]

      @email.deliver

      redirect_to maily_email_path(mailer: params[:mailer], email: params[:email])
    end

    private

    def htmlized
      html = @email.html_part.body.raw_source
      @email.attachments.each do |attachment|
        base64_src = "data:#{attachment.mime_type}\;base64,#{attachment.body.encoded}"
        html.gsub!(attachment.url, base64_src)
      end
      html
    end

    def allowed_action?
      Maily.allowed_action?(action_name) || redirect_to(root_path, alert: "Maily: action #{action_name} not allowed!")
    end

    def load_mailers
      @mailers = Maily::Mailer.all
    end

    def load_mailer_and_email
      mailer = Maily::Mailer.find(params[:mailer])
      @maily_email = mailer.find_email(params[:email])
      @email = @maily_email.call
    end

    def perform_with_locale
      I18n.with_locale(params[:locale]) do
        yield
      end
    end
  end
end
