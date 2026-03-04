"""
Email utility for sending verification codes and password reset links.
Uses SMTP (Gmail / any SMTP provider).
"""
import logging
import random
import string
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config import settings

logger = logging.getLogger("aura.email")


def generate_verification_code(length: int = 6) -> str:
    """Generate a random numeric verification code."""
    return ''.join(random.choices(string.digits, k=length))


def generate_reset_token(length: int = 32) -> str:
    """Generate a random alphanumeric reset token."""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))


def _send_email(to_email: str, subject: str, html_body: str) -> bool:
    """Send an email via SMTP. Returns True on success."""
    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        logger.warning("SMTP not configured — email not sent to %s", to_email)
        return False

    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"{settings.FROM_NAME} <{settings.FROM_EMAIL or settings.SMTP_USER}>"
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_USER, to_email, msg.as_string())

        logger.info("Email sent to %s: %s", to_email, subject)
        return True
    except Exception as e:
        logger.error("Failed to send email to %s: %s", to_email, e)
        return False


def send_verification_email(to_email: str, code: str, name: str = "") -> bool:
    """Send email verification code."""
    greeting = f"Привет, {name}!" if name else "Привет!"
    html = f"""
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
        <div style="text-align: center; margin-bottom: 32px;">
            <div style="display: inline-block; width: 64px; height: 64px; border-radius: 50%; background: linear-gradient(135deg, #7B68EE, #4D8BF5); line-height: 64px; font-size: 28px; color: white; font-family: serif;">A</div>
            <h2 style="margin: 16px 0 4px; color: #333; font-weight: 300; font-size: 22px;">Подтверждение email</h2>
        </div>
        <p style="color: #555; line-height: 1.6;">{greeting}</p>
        <p style="color: #555; line-height: 1.6;">Ваш код подтверждения для AURA:</p>
        <div style="text-align: center; margin: 24px 0;">
            <div style="display: inline-block; padding: 16px 32px; background: linear-gradient(135deg, #7B68EE, #4D8BF5); border-radius: 12px; font-size: 32px; letter-spacing: 8px; color: white; font-weight: bold;">{code}</div>
        </div>
        <p style="color: #888; font-size: 13px; text-align: center;">Код действителен 15 минут</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">
        <p style="color: #aaa; font-size: 12px; text-align: center;">Если вы не регистрировались в AURA, проигнорируйте это письмо.</p>
    </div>
    """
    return _send_email(to_email, f"AURA — Код подтверждения: {code}", html)


def send_password_reset_email(to_email: str, code: str, name: str = "") -> bool:
    """Send password reset code."""
    greeting = f"Привет, {name}!" if name else "Привет!"
    html = f"""
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
        <div style="text-align: center; margin-bottom: 32px;">
            <div style="display: inline-block; width: 64px; height: 64px; border-radius: 50%; background: linear-gradient(135deg, #7B68EE, #4D8BF5); line-height: 64px; font-size: 28px; color: white; font-family: serif;">A</div>
            <h2 style="margin: 16px 0 4px; color: #333; font-weight: 300; font-size: 22px;">Сброс пароля</h2>
        </div>
        <p style="color: #555; line-height: 1.6;">{greeting}</p>
        <p style="color: #555; line-height: 1.6;">Вы запросили сброс пароля. Используйте этот код:</p>
        <div style="text-align: center; margin: 24px 0;">
            <div style="display: inline-block; padding: 16px 32px; background: linear-gradient(135deg, #EE6868, #F54D4D); border-radius: 12px; font-size: 32px; letter-spacing: 8px; color: white; font-weight: bold;">{code}</div>
        </div>
        <p style="color: #888; font-size: 13px; text-align: center;">Код действителен 15 минут</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">
        <p style="color: #aaa; font-size: 12px; text-align: center;">Если вы не запрашивали сброс пароля, проигнорируйте это письмо.</p>
    </div>
    """
    return _send_email(to_email, f"AURA — Сброс пароля", html)
