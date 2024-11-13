require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "sign in view renders" do
    get new_user_session_url
    assert_response :success
  end

  test "sign in without otp fails" do
    otp_secret = User.generate_otp_secret

    user = User.create(
      email: "example@example.com",
      password: "example123",
      password_confirmation: "example123",
      otp_secret: otp_secret,
      otp_required_for_login: true
    )

    post user_session_url(
           user: {
             email: user.email,
             password: user.password,
           }
         )

    assert_response :unprocessable_content
  end

  test "sign in with invalid otp fails" do
    otp_secret = User.generate_otp_secret

    user = User.create(
      email: "example@example.com",
      password: "example123",
      password_confirmation: "example123",
      otp_secret: otp_secret,
      otp_required_for_login: true
    )

    otp_code = ROTP::TOTP.new(otp_secret).now

    otp_code[0] = otp_code[0] == "9" ? "0" : "9"

    post user_session_url(
           user: {
             email: user.email,
             password: user.password,
             otp_attempt: otp_code
           }
         )

    assert_response :unprocessable_content
  end

  test "sign in with valid otp succeeds" do
    otp_secret = User.generate_otp_secret

    user = User.create(
      email: "example@example.com",
      password: "example123",
      password_confirmation: "example123",
      otp_secret: otp_secret,
      otp_required_for_login: true
    )

    post user_session_url(
           user: {
             email: user.email,
             password: user.password,
             otp_attempt: ROTP::TOTP.new(otp_secret).now
           }
         )

    assert_response :redirect
  end
end
