# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]
  before_action :configure_sign_up_params, only: [:create]
  before_action :regenerate_otp_secret, only: [:new]

  def create
    build_resource(sign_up_params)

    if sign_up_params[:otp_attempt].nil?
      fail_otp and return
    end

    otp_code = sign_up_params[:otp_attempt]
    otp_secret = session[:otp_secret]

    valid_otp = verify_totp otp_secret, otp_code

    if valid_otp
      super do |resource|
        if resource.persisted?
          resource.otp_required_for_login = true
          resource.otp_secret = session[:otp_secret]
          resource.save!

          session.delete :otp_secret
        else
          regenerate_otp_secret
        end
      end
    else
      fail_otp
    end
  end

  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)

    if account_update_params[:otp_attempt].nil?
      resource.errors.add(:base, :"wrong otp")
      respond_with resource and return
    end

    otp_code = account_update_params[:otp_attempt]
    valid_otp = verify_totp resource.otp_secret, otp_code

    if valid_otp
      super
    else
      resource.errors.add(:base, :"wrong otp")
      respond_with resource
    end
  end

  protected

  def verify_totp(otp_secret, otp_code)
    totp = ROTP::TOTP.new(otp_secret)

    totp.verify(
      otp_code.gsub(/\s+/, ""),
      drift_behind: User.otp_allowed_drift,
      drift_ahead: User.otp_allowed_drift,
    )
  end

  def fail_otp
    resource.errors.add(:base, :"user-registrations-otp-not-valid")
    regenerate_otp_secret
    render :new, status: :bad_request
  end

  def regenerate_otp_secret
    @otp_secret = User.generate_otp_secret
    session[:otp_secret] = @otp_secret

    @qrcode = RQRCode::QRCode.new(@otp_secret)

    @svg = @qrcode.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 6
    )
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :otp_attempt ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :otp_attempt ])
  end
end
