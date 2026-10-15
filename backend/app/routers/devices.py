"""Registro de tokens de dispositivo para notificaciones push."""

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import DeviceToken, User
from ..schemas import DeviceTokenCreate, DeviceTokenOut
from ..security import get_current_user

router = APIRouter(prefix="/devices", tags=["Dispositivos"])


@router.post(
    "",
    response_model=DeviceTokenOut,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar el token de notificaciones del dispositivo",
)
def register_device(
    payload: DeviceTokenCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceTokenOut:
    # Idempotente: un mismo token se reasigna al usuario que lo registra.
    device = db.execute(
        select(DeviceToken).where(DeviceToken.token == payload.token)
    ).scalar_one_or_none()
    if device is None:
        device = DeviceToken(token=payload.token, platform=payload.platform, user_id=current_user.id)
        db.add(device)
    else:
        device.user_id = current_user.id
        device.platform = payload.platform

    db.commit()
    db.refresh(device)
    return DeviceTokenOut.model_validate(device)


@router.get("", response_model=list[DeviceTokenOut], summary="Listar mis dispositivos registrados")
def list_devices(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[DeviceTokenOut]:
    devices = db.execute(
        select(DeviceToken).where(DeviceToken.user_id == current_user.id).order_by(DeviceToken.id)
    ).scalars().all()
    return [DeviceTokenOut.model_validate(device) for device in devices]
