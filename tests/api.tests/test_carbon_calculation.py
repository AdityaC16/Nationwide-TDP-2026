from datetime import date, datetime
from decimal import Decimal
from unittest import TestCase

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from src.api.carbon_calculation import CarbonFactorError, calculate_spending_carbon
from src.api.models import Base, CarbonCalculation, Category, Customer, EmissionsFactor, Spending


class CarbonCalculationTests(TestCase):
    def setUp(self):
        engine = create_engine("sqlite://")
        self.addCleanup(engine.dispose)
        Base.metadata.create_all(engine)
        self.session = Session(engine, autoflush=False)
        self.addCleanup(self.session.close)
        self.now = datetime(2026, 11, 13, 14, 0)
        self.session.add_all([
            Category(category_id=1, name="Travel"),
            Category(category_id=2, name="Food"),
            Customer(
                customer_id=1,
                customer_ref="CUST-1",
                username="demo",
                display_name="Demo Customer",
                created_at=self.now,
            ),
        ])
        self.session.flush()
        self.july = date(2026, 7, 1)
        self.first_id = self.add_factor(1, "0.4200", date(2026, 1, 1), self.july)
        self.current_id = self.add_factor(1, "0.4000", self.july)
        self.add_factor(2, "0.2750", self.july)

    def add_factor(self, category, value, start, end=None):
        factor = EmissionsFactor(
            category_id=category,
            kg_co2e_per_gbp=Decimal(value),
            source="Test fixture",
            version="test",
            effective_from=start,
            effective_to=end,
        )
        self.session.add(factor)
        self.session.flush()
        return factor.factor_id

    def spend(self, amount="120.00", month=None, category=1):
        return Spending(
            customer_id=1,
            category_id=category,
            period_month=month or self.july,
            amount_gbp=Decimal(amount),
            submitted_at=self.now,
        )

    def test_save_spending_and_calculation_together(self):
        spending = self.spend()
        calculation = calculate_spending_carbon(self.session, spending)
        self.session.add(calculation)
        self.session.commit()

        saved = self.session.scalars(select(CarbonCalculation)).one()
        self.assertEqual(saved.spending_id, spending.spending_id)
        self.assertEqual(saved.factor_id, self.current_id)
        self.assertEqual(saved.carbon_kg, Decimal("48.000"))

    def test_uses_factor_in_effect_before_changeover(self):
        result = calculate_spending_carbon(self.session, self.spend(month=date(2026, 6, 1)))
        self.assertEqual(result.factor_id, self.first_id)
        self.assertEqual(result.carbon_kg, Decimal("50.400"))

    def test_rounds_half_up_and_matches_the_spending_category(self):
        result = calculate_spending_carbon(self.session, self.spend("0.02", category=2))
        self.assertEqual(result.carbon_kg, Decimal("0.006"))

    def test_accepts_zero_spend(self):
        result = calculate_spending_carbon(self.session, self.spend("0.00"))
        self.assertEqual(result.carbon_kg, Decimal("0.000"))

    def test_rejects_invalid_amounts(self):
        for amount in ("-0.01", "NaN", "Infinity"):
            with self.subTest(amount=amount):
                with self.assertRaisesRegex(ValueError, "finite, non-negative"):
                    calculate_spending_carbon(self.session, self.spend(amount))

    def test_reports_missing_factor(self):
        with self.assertRaisesRegex(CarbonFactorError, "found none"):
            calculate_spending_carbon(self.session, self.spend(month=date(2025, 12, 1)))

    def test_reports_overlapping_factors(self):
        self.add_factor(1, "0.5000", self.july)
        with self.assertRaisesRegex(CarbonFactorError, "at least two"):
            calculate_spending_carbon(self.session, self.spend())

    def test_rejects_calculation_that_cannot_fit_the_database_column(self):
        self.add_factor(2, "999999.9999", date(2026, 1, 1), self.july)
        with self.assertRaisesRegex(ValueError, "exceed the supported range"):
            calculate_spending_carbon(
                self.session, self.spend("99999999.99", month=date(2026, 6, 1), category=2)
            )
