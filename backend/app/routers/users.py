"""Perfil del usuario autenticado. El correo no se puede editar (regla 10)."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..errors import ValidationError, documented_errors
from ..models import User
from ..schemas import UserOut, UserUpdate
from ..security import get_current_user

router = APIRouter(prefix="/users", tags=["Usuarios"])


@router.get(
    "/me",
    response_model=UserOut,
    responses=documented_errors(401),
    summary="Ver mi perfil",
)
def read_profile(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)


@router.patch(
    "/me",
    response_model=UserOut,
    responses=documented_errors(400, 401),
    summary="Editar mi perfil (el correo no se puede cambiar)",
)
def update_profile(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if payload.email is not None and payload.email.strip().lower() != current_user.email:
        raise ValidationError(
            "El correo electrónico no se puede modificar.", code="email_not_editable"
        )

    # Los nombres ya vienen recortados y validados por UserUpdate (no vacíos tras strip()).
    if payload.first_name is not None:
        current_user.first_name = payload.first_name
    if payload.last_name is not None:
        current_user.last_name = payload.last_name
    # model_fields_set distingue "no lo mandó" de "lo mandó en null": null borra la fecha.
    if "birth_date" in payload.model_fields_set:
        current_user.birth_date = payload.birth_date

    db.commit()
    db.refresh(current_user)
    return UserOut.model_validate(current_user)
