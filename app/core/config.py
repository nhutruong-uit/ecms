"""Cấu hình ứng dụng, đọc từ file .env ở thư mục gốc repo (xem .env.example)."""
import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")


def _flag(name: str, default: str = "no") -> bool:
    return os.getenv(name, default).strip().lower() in ("1", "yes", "true", "on")


@dataclass(frozen=True)
class DbConfig:
    server: str = os.getenv("DB_SERVER", "localhost")
    port: str = os.getenv("DB_PORT", "1433")
    database: str = os.getenv("DB_NAME", "ECMS")
    driver: str = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
    user: str = os.getenv("DB_USER", "ecms_app")
    password: str = os.getenv("DB_PASSWORD", "")
    trust_cert: bool = _flag("DB_TRUST_CERT", "yes")
    trusted: bool = _flag("DB_TRUSTED", "no")

    @property
    def connection_string(self) -> str:
        parts = [
            f"DRIVER={{{self.driver}}}",
            # SQL Server Express dùng tên instance (localhost\SQLEXPRESS) và để trống DB_PORT → không ghép ",cổng"
            f"SERVER={self.server},{self.port}" if self.port.strip() else f"SERVER={self.server}",
            f"DATABASE={self.database}",
            f"TrustServerCertificate={'yes' if self.trust_cert else 'no'}",
            "Encrypt=yes",
        ]
        if self.trusted:
            parts.append("Trusted_Connection=yes")
        else:
            parts += [f"UID={self.user}", f"PWD={self.password}"]
        return ";".join(parts) + ";"


DB = DbConfig()
APP_TITLE = "ECMS – Quản lý Trung tâm Tiếng Anh"
# Hiện hộp "Tài khoản demo" ở trang Đăng nhập – chỉ cho môi trường phát triển, đặt ECMS_SHOW_DEMO=no khi triển khai
SHOW_DEMO_ACCOUNTS = _flag("ECMS_SHOW_DEMO", "yes")
