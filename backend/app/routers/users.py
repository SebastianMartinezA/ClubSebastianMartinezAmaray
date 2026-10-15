"""Perfil del usuario autenticado. El correo no se puede editar (regla 10)."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..errors import ValidationError
from ..models import User
from ..schemas import UserOut, UserUpdate
from ..security import get_current_user

router = APIRouter(prefix="/users", tags=["Usuarios"])


@router.get("/me", response_model=UserOut, summary="Ver mi perfil")
def read_profile(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)


@router.patch("/me", response_model=UserOut, summary="Editar mi perfil (el correo no se puede cambiar)")
def update_profile(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if payload.email is not None and payload.email.strip().lower() != current_user.email:
        raise ValidationError(
            "El correo electrónico no se puede modificar.", code="email_not_editable"
        )

    if payload.first_name is not None:
        current_user.first_name = payload.first_name.strip()
    if payload.last_name is not None:
        current_user.last_name = payload.last_name.strip()
    if payload.birth_date is not None:
        current_user.birth_date = payload.birth_date

    db.commit()
    db.refresh(current_user)
    return UserOut.model_validate(current_user)
