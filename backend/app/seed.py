"""Datos de ejemplo idempotentes: sedes, espacios deportivos y un usuario demo.

    python -m app.seed
"""

import logging
from datetime import date, time

from sqlalchemy import select
from sqlalchemy.orm import Session

from .database import SessionLocal
from .models import SportSpace, User, Venue
from .security import hash_password

logger = logging.getLogger(__name__)

DEMO_EMAIL = "demo@club.com"
DEMO_PASSWORD = "Demo1234!"

VENUES: list[dict] = [
    {
        "name": "Moron",
        "address": "Rivadavia 19850",
        "opening_time": time(8, 0),
        "closing_time": time(22, 0),
        "spaces": [("Paddle", 1), ("Paddle", 2), ("Futbol", 1)],
    },
    {
        "name": "Castelar",
        "address": "Av. Yrigoyen 1234",
        "opening_time": time(9, 0),
        "closing_time": time(23, 0),
        "spaces": [("Basquet", 1), ("Futbol", 2)],
    },
]


def build_space_name(venue: Venue, space_type: str, number: int) -> str:
    """Nombre compuesto por sede, dirección, tipo y número: Moron_Rivadavia_19850_Paddle_1."""
    raw = "_".join([venue.name, venue.address, space_type, str(number)])
    return "_".join(raw.split())


def seed_demo_data(db: Session | None = None) -> dict[str, int]:
    owns_session = db is None
    session = db or SessionLocal()
    created = {"venues": 0, "spaces": 0, "users": 0}
    try:
        for spec in VENUES:
            venue = session.execute(
                select(Venue).where(Venue.name == spec["name"])
            ).scalar_one_or_none()
            if venue is None:
                venue = Venue(
                    name=spec["name"],
                    address=spec["address"],
                    opening_time=spec["opening_time"],
                    closing_time=spec["closing_time"],
                )
                session.add(venue)
                session.flush()
                created["venues"] += 1

            for space_type, number in spec["spaces"]:
                name = build_space_name(venue, space_type, number)
                exists = session.execute(
                    select(SportSpace).where(SportSpace.name == name)
                ).scalar_one_or_none()
                if exists is None:
                    session.add(
                        SportSpace(venue_id=venue.id, space_type=space_type, number=number, name=name)
                    )
                    created["spaces"] += 1

        demo = session.execute(select(User).where(User.email == DEMO_EMAIL)).scalar_one_or_none()
        if demo is None:
            session.add(
                User(
                    email=DEMO_EMAIL,
                    password_hash=hash_password(DEMO_PASSWORD),
                    first_name="Sebastian",
                    last_name="Martinez Amaray",
                    birth_date=date(2000, 1, 1),
                )
            )
            created["users"] += 1

        session.commit()
        return created
    finally:
        if owns_session:
            session.close()


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    print("Datos creados:", seed_demo_data())
    print(f"Usuario demo: {DEMO_EMAIL} / {DEMO_PASSWORD}")


if __name__ == "__main__":
    main()
