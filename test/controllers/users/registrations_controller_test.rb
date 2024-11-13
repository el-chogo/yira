require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "sign up view renders" do
    get new_user_registration_url
    assert_response :success
  end

  test "sign up shows OTP secret" do
    get new_user_registration_url

    assert_match @controller.session[:otp_secret], @response.body
  end

  test "sign up with no OTP is an error" do
    get new_user_registration_url

    post user_registration_url(
           user: {
             email: "example@example.com",
             password: "example_password",
             password_confirmation: "example_password"
           },
         )

    assert_response :bad_request
    assert User.all.size == 0
  end

  test "sign up with invalid OTP is an error" do
    get new_user_registration_url

    otp_secret = @controller.session[:otp_secret]
    otp_code = ROTP::TOTP.new(otp_secret).now

    otp_code[0] = otp_code[0] == "0" ? "9" : "0"

    post user_registration_url(
           user: {
             email: "example@example.com",
             password: "example_password",
             password_confirmation: "example_password",
             otp_attempt: otp_code
           },
         )

    assert_response :bad_request
    assert User.all.size == 0
  end

  test "sign up with valid OTP succeeds" do
    get new_user_registration_url

    otp_secret = @controller.session[:otp_secret]
    otp_code = ROTP::TOTP.new(otp_secret).now

    post user_registration_url(
           user: {
             email: "example@example.com",
             password: "example_password",
             password_confirmation: "example_password",
             otp_attempt: otp_code
           },
         )

    assert_response :redirect

    assert User.all.size == 1
  end

  test "edit profile with no current otp fails" do
    otp_secret = User.generate_otp_secret

    user = User.create(
      email: "example@example.com",
      password: "example123",
      password_confirmation: "example123",
      otp_secret: otp_secret,
      otp_required_for_login: true
    )

    sign_in user

    patch user_registration_url(
           user: {
             email: user.email,
             current_password: user.password,
             password: user.password,
             password_confirmation: user.password
           }
         )

    assert_response :unprocessable_content
  end

  test "edit profile with current otp succeeds" do
    otp_secret = User.generate_otp_secret

    user = User.create(
      email: "example@example.com",
      password: "example123",
      password_confirmation: "example123",
      otp_secret: otp_secret,
      otp_required_for_login: true
    )

    sign_in user

    patch user_registration_url(
            user: {
              email: user.email,
              current_password: user.password,
              password: user.password,
              password_confirmation: user.password,
              otp_attempt: ROTP::TOTP.new(user.otp_secret).now
            }
          )

    assert_response :redirect
  end
end
