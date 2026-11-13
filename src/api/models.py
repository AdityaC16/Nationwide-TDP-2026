"""SQLAlchemy models for the carbon footprint and savings advisor."""

from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Identity, Integer, Numeric, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    """Base class for all database models."""

c = Challange.new()

class Challenge(Base):
    __tablename__ = "Challenge"

    challenge_id: Mapped[int] = mapped_column("ChallengeId", Integer, Identity(), primary_key=True)
    title: Mapped[str] = mapped_column("Title", String(100), nullable=False)
    description: Mapped[str] = mapped_column("Description", String(500), nullable=False)
    target_carbon_kg: Mapped[Decimal] = mapped_column("TargetCarbonKg", Numeric(10, 2), nullable=False)
    duration_days: Mapped[int] = mapped_column("DurationDays", Integer, nullable=False)
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, nullable=False, default=True)

    customer_challenges: Mapped[list["CustomerChallenge"]] = relationship(
        back_populates="challenge"
    )


class Customer(Base):
    __tablename__ = "Customer"

    customer_id: Mapped[int] = mapped_column("CustomerId", Integer, Identity(), primary_key=True)
    customer_ref: Mapped[str] = mapped_column("CustomerRef", String(20), nullable=False, unique=True)
    display_name: Mapped[str] = mapped_column("DisplayName", String(100), nullable=False)
    persona_type: Mapped[Optional[str]] = mapped_column("PersonaType", String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column("CreatedAt", DateTime, nullable=False)

    customer_challenges: Mapped[list["CustomerChallenge"]] = relationship(
        back_populates="customer"
    )
    spending: Mapped[list["Spending"]] = relationship(back_populates="customer")
    recommendations: Mapped[list["CustomerRecommendation"]] = relationship(
        back_populates="customer"
    )


class Category(Base):
    __tablename__ = "Category"

    category_id: Mapped[int] = mapped_column("CategoryId", Integer, Identity(), primary_key=True)
    name: Mapped[str] = mapped_column("Name", String(50), nullable=False, unique=True)
    description: Mapped[Optional[str]] = mapped_column("Description", String(255), nullable=True)
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, nullable=False, default=True)

    assumptions: Mapped[list["Assumption"]] = relationship(back_populates="category")
    emissions_factors: Mapped[list["EmissionsFactor"]] = relationship(
        back_populates="category"
    )
    spending: Mapped[list["Spending"]] = relationship(back_populates="category")
    recommendation_rules: Mapped[list["RecommendationRule"]] = relationship(
        back_populates="category"
    )


class Assumption(Base):
    __tablename__ = "Assumption"

    assumption_id: Mapped[int] = mapped_column("AssumptionId", Integer, Identity(), primary_key=True)
    category_id: Mapped[Optional[int]] = mapped_column(
        "CategoryId", ForeignKey("Category.CategoryId"), nullable=True
    )
    name: Mapped[str] = mapped_column("Name", String(100), nullable=False)
    value: Mapped[Decimal] = mapped_column("Value", Numeric(10, 4), nullable=False)
    unit: Mapped[str] = mapped_column("Unit", String(30), nullable=False)
    source: Mapped[str] = mapped_column("Source", String(200), nullable=False)
    version: Mapped[str] = mapped_column("Version", String(20), nullable=False)

    category: Mapped[Optional["Category"]] = relationship(back_populates="assumptions")


class CustomerChallenge(Base):
    __tablename__ = "CustomerChallenge"

    customer_challenge_id: Mapped[int] = mapped_column(
        "CustomerChallengeId", Integer, Identity(), primary_key=True
    )
    customer_id: Mapped[int] = mapped_column(
        "CustomerId", ForeignKey("Customer.CustomerId"), nullable=False
    )
    challenge_id: Mapped[int] = mapped_column(
        "ChallengeId", ForeignKey("Challenge.ChallengeId"), nullable=False
    )
    status: Mapped[str] = mapped_column("Status", String(20), nullable=False)
    started_at: Mapped[datetime] = mapped_column("StartedAt", DateTime, nullable=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column("CompletedAt", DateTime, nullable=True)

    customer: Mapped["Customer"] = relationship(back_populates="customer_challenges")
    challenge: Mapped["Challenge"] = relationship(back_populates="customer_challenges")


class Spending(Base):
    __tablename__ = "Spending"

    spending_id: Mapped[int] = mapped_column("SpendingId", Integer, Identity(), primary_key=True)
    customer_id: Mapped[int] = mapped_column(
        "CustomerId", ForeignKey("Customer.CustomerId"), nullable=False
    )
    category_id: Mapped[int] = mapped_column(
        "CategoryId", ForeignKey("Category.CategoryId"), nullable=False
    )
    period_month: Mapped[date] = mapped_column("PeriodMonth", Date, nullable=False)
    amount_gbp: Mapped[Decimal] = mapped_column("AmountGBP", Numeric(10, 2), nullable=False)
    submitted_at: Mapped[datetime] = mapped_column("SubmittedAt", DateTime, nullable=False)

    customer: Mapped["Customer"] = relationship(back_populates="spending")
    category: Mapped["Category"] = relationship(back_populates="spending")
    carbon_calculations: Mapped[list["CarbonCalculation"]] = relationship(
        back_populates="spending"
    )


class EmissionsFactor(Base):
    __tablename__ = "EmissionsFactor"

    factor_id: Mapped[int] = mapped_column("FactorId", Integer, Identity(), primary_key=True)
    category_id: Mapped[int] = mapped_column(
        "CategoryId", ForeignKey("Category.CategoryId"), nullable=False
    )
    kg_co2e_per_gbp: Mapped[Decimal] = mapped_column("KgCO2ePerGBP", Numeric(10, 4), nullable=False)
    source: Mapped[str] = mapped_column("Source", String(200), nullable=False)
    version: Mapped[str] = mapped_column("Version", String(20), nullable=False)
    effective_from: Mapped[date] = mapped_column("EffectiveFrom", Date, nullable=False)
    effective_to: Mapped[Optional[date]] = mapped_column("EffectiveTo", Date, nullable=True)

    category: Mapped["Category"] = relationship(back_populates="emissions_factors")
    carbon_calculations: Mapped[list["CarbonCalculation"]] = relationship(
        back_populates="factor"
    )


class CarbonCalculation(Base):
    __tablename__ = "CarbonCalculation"

    calculation_id: Mapped[int] = mapped_column("CalculationId", Integer, Identity(), primary_key=True)
    spending_id: Mapped[int] = mapped_column(
        "SpendingId", ForeignKey("Spending.SpendingId"), nullable=False
    )
    factor_id: Mapped[int] = mapped_column(
        "FactorId", ForeignKey("EmissionsFactor.FactorId"), nullable=False
    )
    carbon_kg: Mapped[Decimal] = mapped_column("CarbonKg", Numeric(12, 3), nullable=False)
    calculated_at: Mapped[datetime] = mapped_column("CalculatedAt", DateTime, nullable=False)

    spending: Mapped["Spending"] = relationship(back_populates="carbon_calculations")
    factor: Mapped["EmissionsFactor"] = relationship(
        back_populates="carbon_calculations"
    )


class RecommendationRule(Base):
    __tablename__ = "RecommendationRule"

    rule_id: Mapped[int] = mapped_column("RuleId", Integer, Identity(), primary_key=True)
    category_id: Mapped[int] = mapped_column(
        "CategoryId", ForeignKey("Category.CategoryId"), nullable=False
    )
    threshold_gbp: Mapped[Decimal] = mapped_column("ThresholdGBP", Numeric(10, 2), nullable=False)
    advice_text: Mapped[str] = mapped_column("AdviceText", String(500), nullable=False)
    reduction_pct: Mapped[Decimal] = mapped_column("ReductionPct", Numeric(5, 2), nullable=False)
    est_carbon_reduction_kg: Mapped[Decimal] = mapped_column(
        "EstCarbonReductionKg", Numeric(10, 2), nullable=False
    )
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, nullable=False, default=True)

    category: Mapped["Category"] = relationship(back_populates="recommendation_rules")
    customer_recommendations: Mapped[list["CustomerRecommendation"]] = relationship(
        back_populates="rule"
    )


class CustomerRecommendation(Base):
    __tablename__ = "CustomerRecommendation"

    customer_rec_id: Mapped[int] = mapped_column("CustomerRecId", Integer, Identity(), primary_key=True)
    customer_id: Mapped[int] = mapped_column(
        "CustomerId", ForeignKey("Customer.CustomerId"), nullable=False
    )
    rule_id: Mapped[int] = mapped_column(
        "RuleId", ForeignKey("RecommendationRule.RuleId"), nullable=False
    )
    period_month: Mapped[date] = mapped_column("PeriodMonth", Date, nullable=False)
    projected_savings_gbp: Mapped[Decimal] = mapped_column("ProjectedSavingsGBP", Numeric(10, 2), nullable=False)
    projected_carbon_kg: Mapped[Decimal] = mapped_column("ProjectedCarbonKg", Numeric(10, 2), nullable=False)
    status: Mapped[str] = mapped_column("Status", String(20), nullable=False)
    created_at: Mapped[datetime] = mapped_column("CreatedAt", DateTime, nullable=False)

    customer: Mapped["Customer"] = relationship(back_populates="recommendations")
    rule: Mapped["RecommendationRule"] = relationship(
        back_populates="customer_recommendations"
    )
