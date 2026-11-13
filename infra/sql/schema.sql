-- Database schema

CREATE TABLE Challenge (
    ChallengeId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    Title NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500) NOT NULL,
    TargetCarbonKg DECIMAL(10, 2) NOT NULL,
    DurationDays INT NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Challenge_IsActive DEFAULT 1
);

CREATE TABLE Customer (
    CustomerId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CustomerRef NVARCHAR(20) NOT NULL CONSTRAINT UQ_Customer_CustomerRef UNIQUE,
    Username NVARCHAR(50) NOT NULL CONSTRAINT UQ_Customer_Username UNIQUE,
    PasswordHash NVARCHAR(60) NULL, -- bcrypt hash; NULL until login is enabled
    DisplayName NVARCHAR(100) NOT NULL,
    PersonaType NVARCHAR(50) NULL,
    CreatedAt DATETIME2 NOT NULL
);

CREATE TABLE Category (
    CategoryId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL CONSTRAINT UQ_Category_Name UNIQUE,
    Description NVARCHAR(255) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Category_IsActive DEFAULT 1
);

CREATE TABLE Assumption (
    AssumptionId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CategoryId INT NULL,
    Name NVARCHAR(100) NOT NULL,
    Value DECIMAL(10, 4) NOT NULL,
    Unit NVARCHAR(30) NOT NULL,
    Source NVARCHAR(200) NOT NULL,
    Version NVARCHAR(20) NOT NULL,
    CONSTRAINT FK_Assumption_Category
        FOREIGN KEY (CategoryId) REFERENCES Category (CategoryId)
);

CREATE TABLE CustomerChallenge (
    CustomerChallengeId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CustomerId INT NOT NULL,
    ChallengeId INT NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    StartedAt DATETIME2 NOT NULL,
    CompletedAt DATETIME2 NULL,
    CONSTRAINT FK_CustomerChallenge_Customer
        FOREIGN KEY (CustomerId) REFERENCES Customer (CustomerId),
    CONSTRAINT FK_CustomerChallenge_Challenge
        FOREIGN KEY (ChallengeId) REFERENCES Challenge (ChallengeId)
);

CREATE TABLE Spending (
    SpendingId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CustomerId INT NOT NULL,
    CategoryId INT NOT NULL,
    PeriodMonth DATE NOT NULL,
    AmountGBP DECIMAL(10, 2) NOT NULL,
    SubmittedAt DATETIME2 NOT NULL,
    CONSTRAINT FK_Spending_Customer
        FOREIGN KEY (CustomerId) REFERENCES Customer (CustomerId),
    CONSTRAINT FK_Spending_Category
        FOREIGN KEY (CategoryId) REFERENCES Category (CategoryId)
);

CREATE TABLE EmissionsFactor (
    FactorId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CategoryId INT NOT NULL,
    KgCO2ePerGBP DECIMAL(10, 4) NOT NULL,
    Source NVARCHAR(200) NOT NULL,
    Version NVARCHAR(20) NOT NULL,
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE NULL,
    CONSTRAINT FK_EmissionsFactor_Category
        FOREIGN KEY (CategoryId) REFERENCES Category (CategoryId)
);

CREATE TABLE CarbonCalculation (
    CalculationId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    SpendingId INT NOT NULL,
    FactorId INT NOT NULL,
    CarbonKg DECIMAL(12, 3) NOT NULL,
    CalculatedAt DATETIME2 NOT NULL,
    CONSTRAINT FK_CarbonCalculation_Spending
        FOREIGN KEY (SpendingId) REFERENCES Spending (SpendingId),
    CONSTRAINT FK_CarbonCalculation_Factor
        FOREIGN KEY (FactorId) REFERENCES EmissionsFactor (FactorId)
);

CREATE TABLE RecommendationRule (
    RuleId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CategoryId INT NOT NULL,
    ThresholdGBP DECIMAL(10, 2) NOT NULL,
    AdviceText NVARCHAR(500) NOT NULL,
    ReductionPct DECIMAL(5, 2) NOT NULL,
    EstCarbonReductionKg DECIMAL(10, 2) NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_RecommendationRule_IsActive DEFAULT 1,
    CONSTRAINT FK_RecommendationRule_Category
        FOREIGN KEY (CategoryId) REFERENCES Category (CategoryId)
);

CREATE TABLE CustomerRecommendation (
    CustomerRecId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    CustomerId INT NOT NULL,
    RuleId INT NOT NULL,
    PeriodMonth DATE NOT NULL,
    ProjectedSavingsGBP DECIMAL(10, 2) NOT NULL,
    ProjectedCarbonKg DECIMAL(10, 2) NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    CreatedAt DATETIME2 NOT NULL,
    CONSTRAINT FK_CustomerRecommendation_Customer
        FOREIGN KEY (CustomerId) REFERENCES Customer (CustomerId),
    CONSTRAINT FK_CustomerRecommendation_Rule
        FOREIGN KEY (RuleId) REFERENCES RecommendationRule (RuleId)
);
