"""Calculate carbon for a new spend record using its month's database factor."""

from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .models import CarbonCalculation, EmissionsFactor, Spending


class CarbonFactorError(ValueError):
    """The spending month must match exactly one factor for its category."""


def calculate_spending_carbon(session: Session, spending: Spending) -> CarbonCalculation:
    """Build the calculation to save with a new Spending row in one transaction."""
    amount = spending.amount_gbp
    if not amount.is_finite() or amount < 0:
        raise ValueError("Spending amount must be a finite, non-negative GBP amount.")

    period = spending.period_month
    matching_factors = session.scalars(
        select(EmissionsFactor)
        .where(
            EmissionsFactor.category_id == spending.category_id,
            EmissionsFactor.effective_from <= period,
            or_(EmissionsFactor.effective_to.is_(None), EmissionsFactor.effective_to > period),
        )
        .limit(2)
    ).all()

    if len(matching_factors) != 1:
        raise CarbonFactorError(
            f"Expected one emissions factor for category {spending.category_id} "
            f"in {period:%Y-%m}; found {'at least two' if matching_factors else 'none'}."
        )

    factor = matching_factors[0]
    carbon_kg = (amount * factor.kg_co2e_per_gbp).quantize(
        Decimal("0.001"), rounding=ROUND_HALF_UP
    )
    if carbon_kg > Decimal("999999999.999"):
        raise ValueError("Calculated emissions exceed the supported range.")

    return CarbonCalculation(
        spending=spending,
        factor_id=factor.factor_id,
        carbon_kg=carbon_kg,
        calculated_at=spending.submitted_at,
    )
