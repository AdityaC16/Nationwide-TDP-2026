-- =============================================================
-- Carbon Footprint & Savings Advisor - Seed data
-- Portable SQL: runs on both SQLite (local dev) and Azure SQL / SQL Server.
-- Run AFTER the schema exists (python -m src.api.migrate does both).
-- Re-runnable: clears all tables first.
--
-- Portability rules for anyone editing this file:
--   * No N'' prefixes, CAST(... AS DATE), DATEADD, MONTH(), GO, or
--     (VALUES ...) AS v(cols) derived tables - SQLite rejects them.
--     Use SELECT ... UNION ALL SELECT ... for inline row sets instead.
--   * Dates are 'YYYY-MM-DD' and datetimes 'YYYY-MM-DD HH:MM:SS' strings.
--   * The first row of every UNION ALL set must have no NULLs (SQL Server
--     types an untyped NULL as INT).
--   * Customer IDs are explicit (1001-1005). On SQL Server, migrate.py turns
--     IDENTITY_INSERT on for Customer around this script.
--
-- Customer and spending records are synthetic. No real customers.
--   * Customers & spending: Appendix A personas (Oct 2026 = the
--     exact "typical monthly spend" figures; May-Sep vary around them).
--   * Thresholds, advice, savings %: Appendix B.
--   * Travel factor: synthetic, derived from Appendix B examples.
--   * Food and Utilities factors: Defra COICOP weighted by ONS household spending.
--   * EffectiveTo is EXCLUSIVE: a factor applies when
--       EffectiveFrom <= PeriodMonth AND (EffectiveTo IS NULL OR PeriodMonth < EffectiveTo)
-- =============================================================

-- ---------- Clear existing data (child tables first) ----------
DELETE FROM CustomerRecommendation;
DELETE FROM CarbonCalculation;
DELETE FROM CustomerChallenge;
DELETE FROM Spending;
DELETE FROM RecommendationRule;
DELETE FROM EmissionsFactor;
DELETE FROM Assumption;
DELETE FROM Challenge;
DELETE FROM Category;
DELETE FROM Customer;

-- ---------- Categories ----------
INSERT INTO Category (Name, Description) VALUES
    ('Travel',    'Fuel, public transport, taxis and other getting-around costs'),
    ('Food',      'Groceries, takeaways and eating out'),
    ('Utilities', 'Gas, electricity and water');

-- ---------- Customers (Appendix A personas; IDs match the appendix) ----------
-- Login is not enabled yet, so PasswordHash is NULL. When it is, store only
-- bcrypt hashes (60 chars, "$2b$..."), never plain-text passwords.
INSERT INTO Customer (CustomerId, CustomerRef, Username, PasswordHash, DisplayName, PersonaType, CreatedAt) VALUES
    (1001, 'CUST-1001', 'alex.morgan',     NULL, 'Alex Morgan',            'Single Professional', '2026-05-01 08:00:00'),
    (1002, 'CUST-1002', 'patel.family',    NULL, 'Priya & Sam Patel',      'Family Household',    '2026-05-01 08:00:00'),
    (1003, 'CUST-1003', 'jordan.lee',      NULL, 'Jordan Lee',             'Student',             '2026-05-01 08:00:00'),
    (1004, 'CUST-1004', 'hughes.family',   NULL, 'Margaret & John Hughes', 'Retired Couple',      '2026-05-01 08:00:00'),
    (1005, 'CUST-1005', 'chris.taylor',    NULL, 'Chris Taylor',           'High Commuter',       '2026-05-01 08:00:00');

-- ---------- Emissions factors ----------
-- Synthetic Travel values exercise the July 2026 factor version change.
INSERT INTO EmissionsFactor (CategoryId, KgCO2ePerGBP, Source, Version, EffectiveFrom, EffectiveTo)
SELECT c.CategoryId, v.Factor, 'Synthetic - derived from TDP 2026 Appendix B', v.Version, v.EffectiveFrom, v.EffectiveTo
FROM (
    SELECT 'Travel' AS CategoryName, 0.4200 AS Factor, 'v1.0' AS Version, '2026-01-01' AS EffectiveFrom, '2026-07-01' AS EffectiveTo
    UNION ALL SELECT 'Travel', 0.4000, 'v1.1', '2026-07-01', NULL
) v
JOIN Category c ON c.Name = v.CategoryName;

-- Defra 2023 COICOP GHG factors weighted by ONS Consumer Trends v53 spend.
-- Food covers food, non-alcoholic drinks and catering. Utilities covers
-- electricity, gas, water supply and sewerage. We round to DECIMAL(10,4).
-- The demo treats fixture amounts as 2023-price GBP including applicable VAT.
-- EffectiveFrom selects the factor for fixture dates, which are in 2026.
INSERT INTO EmissionsFactor (CategoryId, KgCO2ePerGBP, Source, Version, EffectiveFrom, EffectiveTo)
SELECT c.CategoryId, v.Factor,
       'Defra COICOP / ONS v53 (2023 GBP incl VAT): https://www.gov.uk/government/statistics/uks-carbon-footprint',
       'defra-2026-06-30', '2026-01-01', NULL
FROM (
    SELECT 'Food' AS CategoryName, 0.6927 AS Factor
    UNION ALL SELECT 'Utilities', 1.5430
) v
JOIN Category c ON c.Name = v.CategoryName;

-- ---------- Assumptions ----------
INSERT INTO Assumption (CategoryId, Name, Value, Unit, Source, Version)
SELECT c.CategoryId, v.Name, v.Value, v.Unit, 'Synthetic - TDP 2026 demo assumption', 'v1.0'
FROM (
    SELECT 'Travel' AS CategoryName, 'Share of travel spend on private car fuel' AS Name, 70.0000 AS Value, '%' AS Unit
    UNION ALL SELECT 'Food',      'Share of food spend on takeaways and eating out',      25.0000, '%'
    UNION ALL SELECT 'Utilities', 'Share of utility bill used for heating',               60.0000, '%'
    UNION ALL SELECT 'Utilities', 'Heating saving per 1 degree C thermostat reduction',   10.0000, '%'
    UNION ALL SELECT NULL,        'Emissions factors are reviewed every',                  6.0000, 'months'
    UNION ALL SELECT NULL,        'Projected savings assume the advice is fully adopted', 100.0000, '%'
    UNION ALL SELECT NULL,        'Months used for annual projections',                   12.0000, 'months'
) v
LEFT JOIN Category c ON c.Name = v.CategoryName;

-- ---------- Recommendation rules (Appendix B thresholds & advice) ----------
-- ReductionPct reproduces Appendix B: High Commuter £520 x 15% = £78 (~£80),
-- Single Professional food £320 x 14% = £44.80 (~£45), Retired utilities £180 x 17% = £30.60 (~£30).
INSERT INTO RecommendationRule (CategoryId, ThresholdGBP, AdviceText, ReductionPct, EstCarbonReductionKg)
SELECT c.CategoryId, v.Threshold, v.Advice, v.Pct, v.Kg
FROM (
    SELECT 'Travel' AS CategoryName, 300.00 AS Threshold, 'Reduce solo car journeys: car share twice a week and switch one commute day to rail.' AS Advice, 15.00 AS Pct, 35.00 AS Kg
    UNION ALL SELECT 'Food',      250.00, 'Cut takeaway meals: meal prep three times a week and batch cook lunches.', 14.00, 12.00
    UNION ALL SELECT 'Utilities', 150.00, 'Turn heating down by 1 degree C, switch off devices on standby and optimise appliance use.', 17.00, 10.00
) v
JOIN Category c ON c.Name = v.CategoryName;

-- ---------- Challenges ----------
INSERT INTO Challenge (Title, Description, TargetCarbonKg, DurationDays) VALUES
    ('Car-free commute week',     'Commute by rail, bus, bike or car share for 5 working days.',          15.00,  7),
    ('Meat-free Mondays',         'Go meat-free every Monday for four weeks.',                              8.00, 28),
    ('Batch-cook Sundays',        'Batch cook lunches every Sunday for four weeks instead of buying out.',  6.00, 28),
    ('No-takeaway fortnight',     'No takeaway or delivery meals for 14 days.',                             5.00, 14),
    ('Thermostat down 1 degree',  'Lower your thermostat by 1 degree C for a month.',                      10.00, 30),
    ('Standby slayer',            'Switch devices off at the wall instead of standby for two weeks.',       3.00, 14);

-- ---------- Spending (6 months per persona: May-Oct 2026) ----------
INSERT INTO Spending (CustomerId, CategoryId, PeriodMonth, AmountGBP, SubmittedAt)
SELECT v.CustomerId, c.CategoryId, v.PeriodMonth, v.Amount, v.SubmittedAt
FROM (
    -- 1001 Single Professional: Balanced demo. Travel crosses £300 only in Aug (summer trip).
    SELECT 1001 AS CustomerId, 'Travel' AS CategoryName, '2026-05-01' AS PeriodMonth, 265.00 AS Amount, '2026-06-02 09:15:00' AS SubmittedAt
    UNION ALL SELECT 1001, 'Travel', '2026-06-01', 270.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1001, 'Travel', '2026-07-01', 250.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1001, 'Travel', '2026-08-01', 310.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1001, 'Travel', '2026-09-01', 275.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1001, 'Travel', '2026-10-01', 280.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1001, 'Food', '2026-05-01', 300.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1001, 'Food', '2026-06-01', 310.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1001, 'Food', '2026-07-01', 335.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1001, 'Food', '2026-08-01', 330.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1001, 'Food', '2026-09-01', 315.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1001, 'Food', '2026-10-01', 320.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1001, 'Utilities', '2026-05-01', 120.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1001, 'Utilities', '2026-06-01', 105.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1001, 'Utilities', '2026-07-01', 100.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1001, 'Utilities', '2026-08-01', 105.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1001, 'Utilities', '2026-09-01', 125.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1001, 'Utilities', '2026-10-01', 140.00, '2026-11-02 09:15:00'
    -- 1002 Family Household: High-impact demo. Summer holiday spike in Jul/Aug, heating rises into autumn.
    UNION ALL SELECT 1002, 'Travel', '2026-05-01', 430.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1002, 'Travel', '2026-06-01', 445.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1002, 'Travel', '2026-07-01', 520.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1002, 'Travel', '2026-08-01', 560.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1002, 'Travel', '2026-09-01', 440.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1002, 'Travel', '2026-10-01', 450.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1002, 'Food', '2026-05-01', 620.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1002, 'Food', '2026-06-01', 640.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1002, 'Food', '2026-07-01', 700.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1002, 'Food', '2026-08-01', 720.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1002, 'Food', '2026-09-01', 630.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1002, 'Food', '2026-10-01', 650.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1002, 'Utilities', '2026-05-01', 210.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1002, 'Utilities', '2026-06-01', 180.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1002, 'Utilities', '2026-07-01', 170.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1002, 'Utilities', '2026-08-01', 175.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1002, 'Utilities', '2026-09-01', 220.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1002, 'Utilities', '2026-10-01', 260.00, '2026-11-02 09:15:00'
    -- 1003 Student: Low-impact demo. Never crosses a threshold, so no recommendations.
    UNION ALL SELECT 1003, 'Travel', '2026-05-01', 110.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1003, 'Travel', '2026-06-01', 115.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1003, 'Travel', '2026-07-01', 60.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1003, 'Travel', '2026-08-01', 55.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1003, 'Travel', '2026-09-01', 140.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1003, 'Travel', '2026-10-01', 120.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1003, 'Food', '2026-05-01', 170.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1003, 'Food', '2026-06-01', 175.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1003, 'Food', '2026-07-01', 140.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1003, 'Food', '2026-08-01', 135.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1003, 'Food', '2026-09-01', 190.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1003, 'Food', '2026-10-01', 180.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1003, 'Utilities', '2026-05-01', 65.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1003, 'Utilities', '2026-06-01', 60.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1003, 'Utilities', '2026-07-01', 55.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1003, 'Utilities', '2026-08-01', 55.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1003, 'Utilities', '2026-09-01', 65.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1003, 'Utilities', '2026-10-01', 70.00, '2026-11-02 09:15:00'
    -- 1004 Retired Couple: Utilities demo. Sep utilities = exactly £150 (boundary: must NOT trigger).
    UNION ALL SELECT 1004, 'Travel', '2026-05-01', 95.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1004, 'Travel', '2026-06-01', 100.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1004, 'Travel', '2026-07-01', 130.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1004, 'Travel', '2026-08-01', 120.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1004, 'Travel', '2026-09-01', 85.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1004, 'Travel', '2026-10-01', 90.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1004, 'Food', '2026-05-01', 275.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1004, 'Food', '2026-06-01', 280.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1004, 'Food', '2026-07-01', 285.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1004, 'Food', '2026-08-01', 280.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1004, 'Food', '2026-09-01', 275.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1004, 'Food', '2026-10-01', 280.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1004, 'Utilities', '2026-05-01', 140.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1004, 'Utilities', '2026-06-01', 125.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1004, 'Utilities', '2026-07-01', 115.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1004, 'Utilities', '2026-08-01', 120.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1004, 'Utilities', '2026-09-01', 150.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1004, 'Utilities', '2026-10-01', 180.00, '2026-11-02 09:15:00'
    -- 1005 High Commuter: Travel-heavy demo. Travel rises every month (trend-rule stretch goal).
    UNION ALL SELECT 1005, 'Travel', '2026-05-01', 430.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1005, 'Travel', '2026-06-01', 450.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1005, 'Travel', '2026-07-01', 470.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1005, 'Travel', '2026-08-01', 490.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1005, 'Travel', '2026-09-01', 505.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1005, 'Travel', '2026-10-01', 520.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1005, 'Food', '2026-05-01', 330.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1005, 'Food', '2026-06-01', 335.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1005, 'Food', '2026-07-01', 345.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1005, 'Food', '2026-08-01', 340.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1005, 'Food', '2026-09-01', 335.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1005, 'Food', '2026-10-01', 340.00, '2026-11-02 09:15:00'
    UNION ALL SELECT 1005, 'Utilities', '2026-05-01', 130.00, '2026-06-02 09:15:00'
    UNION ALL SELECT 1005, 'Utilities', '2026-06-01', 125.00, '2026-07-02 09:15:00'
    UNION ALL SELECT 1005, 'Utilities', '2026-07-01', 120.00, '2026-08-03 09:15:00'
    UNION ALL SELECT 1005, 'Utilities', '2026-08-01', 125.00, '2026-09-02 09:15:00'
    UNION ALL SELECT 1005, 'Utilities', '2026-09-01', 140.00, '2026-10-02 09:15:00'
    UNION ALL SELECT 1005, 'Utilities', '2026-10-01', 160.00, '2026-11-02 09:15:00'
) v
JOIN Category c ON c.Name = v.CategoryName;

-- ---------- Carbon calculations (Amount x factor valid for that month) ----------
INSERT INTO CarbonCalculation (SpendingId, FactorId, CarbonKg, CalculatedAt)
-- Multiply in integer millionths of a kg, then round half up to millikilos.
-- This keeps SQLite floating-point ties consistent with the Python calculation.
SELECT s.SpendingId, f.FactorId,
       ((CAST(ROUND(s.AmountGBP * 100, 0) AS BIGINT)
       * CAST(ROUND(f.KgCO2ePerGBP * 10000, 0) AS BIGINT) + 500) / 1000) / 1000.0,
       s.SubmittedAt
FROM Spending s
JOIN EmissionsFactor f
  ON f.CategoryId = s.CategoryId
 AND f.EffectiveFrom <= s.PeriodMonth
 AND (f.EffectiveTo IS NULL OR s.PeriodMonth < f.EffectiveTo);

-- ---------- Customer recommendations (rule fires when spend > threshold) ----------
-- Status: latest month is 'New'; older ones are a deterministic mix of
-- Accepted/Dismissed based on (CustomerId + month number) % 3.
-- SUBSTRING(CAST(date AS VARCHAR(10)), 6, 2) is a portable MONTH().
INSERT INTO CustomerRecommendation (CustomerId, RuleId, PeriodMonth, ProjectedSavingsGBP, ProjectedCarbonKg, Status, CreatedAt)
SELECT s.CustomerId, r.RuleId, s.PeriodMonth,
       ROUND(s.AmountGBP * r.ReductionPct / 100.0, 2),
       ROUND(ROUND(s.AmountGBP * r.ReductionPct / 100.0, 2) * f.KgCO2ePerGBP, 2),
       CASE
           WHEN s.PeriodMonth = '2026-10-01' THEN 'New'
           WHEN (s.CustomerId + CAST(SUBSTRING(CAST(s.PeriodMonth AS VARCHAR(10)), 6, 2) AS INT)) % 3 = 0 THEN 'Dismissed'
           ELSE 'Accepted'
       END,
       s.SubmittedAt
FROM Spending s
JOIN RecommendationRule r ON r.CategoryId = s.CategoryId AND r.IsActive = 1
JOIN EmissionsFactor f
  ON f.CategoryId = s.CategoryId
 AND f.EffectiveFrom <= s.PeriodMonth
 AND (f.EffectiveTo IS NULL OR s.PeriodMonth < f.EffectiveTo)
WHERE s.AmountGBP > r.ThresholdGBP;

-- ---------- Customer challenges (one of each status) ----------
INSERT INTO CustomerChallenge (CustomerId, ChallengeId, Status, StartedAt, CompletedAt)
SELECT v.CustomerId, ch.ChallengeId, v.Status, v.StartedAt, v.CompletedAt
FROM (
    SELECT 1001 AS CustomerId, 'No-takeaway fortnight' AS Title, 'Completed' AS Status, '2026-10-01 10:00:00' AS StartedAt, '2026-10-15 18:30:00' AS CompletedAt
    UNION ALL SELECT 1002, 'Meat-free Mondays',        'Completed', '2026-09-07 08:00:00', '2026-10-05 20:00:00'
    UNION ALL SELECT 1002, 'Thermostat down 1 degree', 'Active',    '2026-11-01 09:00:00', NULL
    UNION ALL SELECT 1003, 'Batch-cook Sundays',       'Abandoned', '2026-09-13 12:00:00', NULL
    UNION ALL SELECT 1004, 'Thermostat down 1 degree', 'Active',    '2026-10-20 09:00:00', NULL
    UNION ALL SELECT 1005, 'Car-free commute week',    'Active',    '2026-11-09 07:30:00', NULL
) v
JOIN Challenge ch ON ch.Title = v.Title;
