--==================================================================
--  OHO Data Warehouse: DIMDATE
--
--  Synopsis: Development script for Facts and Dimensions.
--
--==================================================================
USE [YourDB];
GO

--==================================================================
IF OBJECT_ID('dbo.DimDate', 'U') IS NOT NULL
	DROP TABLE dbo.DimDate;


CREATE TABLE dbo.DimDate
(
		DateKey								int PRIMARY KEY,
		Date								date,				-- Date in dd-MM-yyyy format.
		DaySuffix							varchar(4),			-- Apply suffix as 1st, 2nd ,3rd etc.
		DayName								varchar(9),			-- Contains name of the day, Sunday, Monday.
		DayOfWeek							char(1),			-- First Day Monday=1 and Sunday=7.
		DayOfMonth							varchar(2),			-- Field will hold day number of Month.
		WeekInMonth							varchar(2),			-- 1st Monday or 2nd Monday in Month.
		WeekInYear							varchar(2),
		DayOfQuarter						varchar(3),
		DayOfYear							varchar(3),
		WeekOfMonth							varchar(1),			-- Week Number of Month.
		WeekOfQuarter						varchar(2),			-- Week Number of the Quarter.
		WeekOfYear							varchar(2),			-- Week Number of the Year.
		Month								varchar(2),			-- Number of the Month 1 to 12.
		MonthName							varchar(9),			-- January, February etc.
		MonthOfQuarter						varchar(2),			-- Month Number belongs to Quarter.
		Quarter								char(1),
		QuarterName							varchar(9),			-- First,Second...
		Year								char(4),			-- Year value of Date stored in Row.
		YearName							char(7),			-- CY 2012,CY 2013.
		MonthYear							char(10),			-- Jan-2013,Feb-2013.
		MMYYYY								char(6),
		FirstDayOfMonth						date,
		LastDayOfMonth						date,
		FirstDayOfQuarter					date,
		LastDayOfQuarter					date,
		FirstDayOfYear						date,
		LastDayOfYear						date,
		IsWeekday							bit,				-- 0=Week End ,1=Week Day.
		IsHoliday							bit NULL,			-- Flag 1=National Holiday, 0-No National Holiday.
		Holiday								varchar(50) NULL	-- Name of Holiday.
)
GO

-- Add Fiscal Calendar columns into table DimDate.
ALTER TABLE dbo.DimDate
ADD
		FiscalWeekOfYear					varchar(3),
		FiscalMonth							varchar(2), 
		FiscalQuarter						char(1),
		FiscalQuarterName					varchar(9),
		FiscalYear							char(4),
		FiscalYearName						char(7),
		FiscalMonthYear						char(10),
		FiscalMMYYYY						char(6)
GO