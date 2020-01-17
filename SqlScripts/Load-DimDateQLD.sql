--==================================================================
--  LOAD-DIMDATEQLD
--
--  Synopsis: Loads into the table created by "Load-DimDate.sql".
--
--  Source:
--  https://www.codeproject.com/Articles/647950/Create-and-Populate-Date-Dimension-for-Data-Wareho
--
--  Note: The calculation for Easter is only good for 1900s to an upper
--  limit, so don't set the start and end date range too wide...
--
--==================================================================
USE [YourDB];
GO

-- Datetime variables temp table.
IF OBJECT_ID(N'tempdb..#DateVariables') IS NOT NULL
	DROP TABLE #DateVariables;

CREATE TABLE #DateVariables
(
	[Key]					nvarchar(128) PRIMARY KEY,
	[Value]					datetime
);
GO

-- Integers variables temp table.
IF OBJECT_ID(N'tempdb..#IntegerVariables') IS NOT NULL
	DROP TABLE #IntegerVariables;

CREATE TABLE #IntegerVariables
(
	[Key]					nvarchar(128) PRIMARY KEY,
	[Value]					int
);
GO

--==================================================================
-- SET DATEFIRST to value of 1 (Monday):
-- SELECT @@DATEFIRST
--==================================================================
SET DATEFIRST 1;
GO


--==================================================================
-- Specify Start Date and End date here.
-- Value of Start Date Must be Less than Your End Date.

DECLARE @StartDate					datetime = '1995-01-01 00:00:00.000';	-- Starting value of Date Range.
DECLARE @EndDate					datetime = '2031-01-01 00:00:00.000';	-- End Value of Date Range.
DECLARE	@FirstLeapYearInPeriod		int = 1996;								-- Manually set.

-- Store start date in a temp table so that the fiscal year calculation
-- can also use this value.
INSERT INTO #DateVariables		([Key], [Value]) VALUES ('StartDate', @StartDate);
INSERT INTO #DateVariables		([Key], [Value]) VALUES ('EndDate', @EndDate);
INSERT INTO #IntegerVariables	([Key], [Value]) VALUES ('FirstLeapYearInPeriod', @FirstLeapYearInPeriod);


--==================================================================
-- SECTION 1: CALENDAR DAYS:
--==================================================================
-- Temporary Variables To Hold the Values During Processing of Each Date of Year.
DECLARE @WeekInMonth					int;
DECLARE @WeekInYear						int;
DECLARE @DayOfQuarter					int;
DECLARE @WeekOfMonth					int;
DECLARE @CurrentYear					int;
DECLARE @CurrentMonth					int;
DECLARE @CurrentQuarter					int;

--==================================================================
-- Table Data type to store the day of week count for the month and year.
DECLARE @DayOfWeek TABLE
(
		DOW								int,
		MonthCount						int,
		QuarterCount					int,
		YearCount						int
);

INSERT INTO @DayOfWeek VALUES (1, 0, 0, 0);
INSERT INTO @DayOfWeek VALUES (2, 0, 0, 0);
INSERT INTO @DayOfWeek VALUES (3, 0, 0, 0);
INSERT INTO @DayOfWeek VALUES (4, 0, 0, 0);
INSERT INTO @DayOfWeek VALUES (5, 0, 0, 0);
INSERT INTO @DayOfWeek VALUES (6, 0, 0, 0);
INSERT INTO @DayOfWeek VALUES (7, 0, 0, 0);

--==================================================================
-- Extract and assign various parts of Values from Current Date to Variable.
DECLARE @CurrentDate datetime;
SET @CurrentDate = @StartDate;

SET @CurrentMonth = DATEPART(MM, @CurrentDate);
SET @CurrentQuarter = DATEPART(QQ, @CurrentDate);
SET @CurrentYear = DATEPART(YY, @CurrentDate);

--==================================================================
-- Proceed only if Start Date(Current date) is less than End date you specified above
WHILE @CurrentDate < @EndDate
BEGIN;
 
	-- Begin day of week logic.

	-- Check for Change in Month of the Current date if Month changed then 
	-- Change variable value.
	IF @CurrentMonth != DATEPART(MM, @CurrentDate)
	BEGIN;
		UPDATE	@DayOfWeek
		SET		MonthCount = 0;

		SET @CurrentMonth = DATEPART(MM, @CurrentDate);
	END;

	-- Check for Change in Quarter of the Current date if Quarter changed then change 
	-- variable value.

	IF @CurrentQuarter != DATEPART(QQ, @CurrentDate)
	BEGIN;
		UPDATE	@DayOfWeek
		SET		QuarterCount = 0;

		SET @CurrentQuarter = DATEPART(QQ, @CurrentDate);
	END;

	-- Check for Change in Year of the Current date if Year changed then change 
	-- variable value.
	
	IF @CurrentYear != DATEPART(YY, @CurrentDate)
	BEGIN;
		UPDATE	@DayOfWeek
		SET		YearCount = 0;

		SET @CurrentYear = DATEPART(YY, @CurrentDate);
	END;
	
	--==================================================================
	-- Set values in table data type created above from variables.

	UPDATE	@DayOfWeek
	SET		MonthCount = MonthCount + 1,
			QuarterCount = QuarterCount + 1,
			YearCount = YearCount + 1
	WHERE	DOW = DATEPART(DW, @CurrentDate);

	SELECT
			@WeekInMonth = MonthCount,
			@DayOfQuarter = QuarterCount,
			@WeekInYear = YearCount
	FROM	@DayOfWeek
	WHERE	DOW = DATEPART(DW, @CurrentDate);
	
	-- End day of week logic.

	--==================================================================
	-- Populate Your Dimension Table with values.
	INSERT INTO dbo.DimDate
	(
			DateKey,
			Date,
			DaySuffix,
			DayName,
			DayOfWeek,
			DayOfMonth,
			WeekInMonth,
			WeekInYear,
			DayOfQuarter,
			DayOfYear,
			WeekOfMonth,
			WeekOfQuarter,
			WeekOfYear,
			Month,
			MonthName,
			MonthOfQuarter,
			Quarter,
			QuarterName,
			Year,
			YearName,
			MonthYear,
			MMYYYY,
			FirstDayOfMonth,
			LastDayOfMonth,
			FirstDayOfQuarter,
			LastDayOfQuarter,
			FirstDayOfYear,
			LastDayOfYear,
			IsWeekday,
			IsHoliday,
			Holiday
	)
	SELECT
			CONVERT (char(8), @CurrentDate, 112)	AS [DateKey],
			CONVERT (date, @CurrentDate)			AS [Date],
			--Apply Suffix values like 1st, 2nd 3rd etc..
			CASE 
				WHEN DATEPART(DD, @CurrentDate) IN (11,12,13) THEN CAST(DATEPART(DD,@CurrentDate)	AS varchar) + 'th'
				WHEN RIGHT(DATEPART(DD, @CurrentDate),1) = 1 THEN CAST(DATEPART(DD,@CurrentDate)	AS varchar) + 'st'
				WHEN RIGHT(DATEPART(DD, @CurrentDate),1) = 2 THEN CAST(DATEPART(DD,@CurrentDate)	AS varchar) + 'nd'
				WHEN RIGHT(DATEPART(DD, @CurrentDate),1) = 3 THEN CAST(DATEPART(DD,@CurrentDate)	AS varchar) + 'rd'
				ELSE CAST(DATEPART(DD, @CurrentDate)												AS varchar) + 'th'
			END										AS [DaySuffix],
			DATENAME(DW, @CurrentDate)				AS [DayName],
			DATEPART(DW, @CurrentDate)				AS [DayOfWeek],
			DATEPART(DD, @CurrentDate)				AS [DayOfMonth],
			@WeekInMonth							AS [WeekInMonth],
			@WeekInYear								AS [WeekInYear],
			@DayOfQuarter							AS [DayOfQuarter],
			DATEPART(DY, @CurrentDate)				AS [DayOfYear],
			DATEPART(WW, @CurrentDate) + 1 - DATEPART(WW, CONVERT(varchar, DATEPART(MM, @CurrentDate)) + '/1/' + CONVERT(varchar, DATEPART(YY, @CurrentDate))) AS [WeekOfMonth],
			(DATEDIFF(DD, DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0), @CurrentDate) / 7) + 1 AS [WeekOfQuarter],
			DATEPART(WW, @CurrentDate)				AS [WeekOfYear],
			DATEPART(MM, @CurrentDate)				AS [Month],
			DATENAME(MM, @CurrentDate)				AS [MonthName],
			CASE
				WHEN DATEPART(MM, @CurrentDate) IN (1, 4, 7, 10) THEN 1
				WHEN DATEPART(MM, @CurrentDate) IN (2, 5, 8, 11) THEN 2
				WHEN DATEPART(MM, @CurrentDate) IN (3, 6, 9, 12) THEN 3
			END										AS [MonthOfQuarter],
			DATEPART(QQ, @CurrentDate)				AS [Quarter],
			CASE DATEPART(QQ, @CurrentDate)
				WHEN 1 THEN 'First'
				WHEN 2 THEN 'Second'
				WHEN 3 THEN 'Third'
				WHEN 4 THEN 'Fourth'
			END										AS [QuarterName],
			DATEPART(YEAR, @CurrentDate)			AS [Year],
			'CY ' + CONVERT(varchar, DATEPART(YEAR, @CurrentDate))														AS [YearName],
			LEFT(DATENAME(MM, @CurrentDate), 3) + '-' + CONVERT(varchar, DATEPART(YY, @CurrentDate))					AS [MonthYear],
			RIGHT('0' + CONVERT(varchar, DATEPART(MM, @CurrentDate)),2) + CONVERT(varchar, DATEPART(YY, @CurrentDate))	AS [MMYYYY],
					CONVERT(datetime, CONVERT(date, DATEADD(DD, - (DATEPART(DD, @CurrentDate) - 1), @CurrentDate)))		AS [FirstDayOfMonth],
			CONVERT(datetime, CONVERT(date, DATEADD(DD, - (DATEPART(DD, (DATEADD(MM, 1, @CurrentDate)))),
					DATEADD(MM, 1, @CurrentDate))))																		AS [LastDayOfMonth],
			DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0)																AS [FirstDayOfQuarter],
			DATEADD(QQ, DATEDIFF(QQ, -1, @CurrentDate), -1)																AS [LastDayOfQuarter],
			CONVERT(datetime, '01/01/' + CONVERT(varchar, DATEPART(YY, @CurrentDate)))									AS [FirstDayOfYear],
			CONVERT(datetime, '12/31/' + CONVERT(varchar, DATEPART(YY, @CurrentDate)))									AS [LastDayOfYear],
			CASE DATEPART(DW, @CurrentDate)
				WHEN 1 THEN 1	-- Monday.
				WHEN 2 THEN 1	-- Tuesday.
				WHEN 3 THEN 1	-- Wednesday.
				WHEN 4 THEN 1	-- Thursday.
				WHEN 5 THEN 1	-- Friday.
				WHEN 6 THEN 0	-- Saturday.
				WHEN 7 THEN 0	-- Sunday.
			END										AS [IsWeekday],
			NULL									AS [IsHoliday],
			NULL									AS [Holiday];

	SET @CurrentDate = DATEADD(DD, 1, @CurrentDate);
END;


--==================================================================
-- END - SECTION 1: CALENDAR DAYS:
GO
--==================================================================

--==================================================================
-- SECTION 2: QUEENSLAND HOLIDAYS:
--==================================================================
-- Source:
-- https://www.qld.gov.au/recreation/travel/holidays/public
--
--
-- Australia Day - Synopsis:
-- If 26 January is a Saturday or Sunday, the public holiday is to 
-- be observed on the following Monday.
--
--
-- Easter Holiday - Source & Synopsis:
-- https://stackoverflow.com/questions/2192533/function-to-return-date-of-easter-for-the-given-year
-- This logic will only work from the lower limit of the 1900s and 
-- also has an upper limit when dates start to become invalid.
--
--
-- Labour Day (Qld) - Source & Synopsis:
-- https://www.timeanddate.com/holidays/australia/labour-day
-- Labour Day is held on the first Monday of October in Queensland,...
-- Queensland observed Labour Day on the first Monday in May until 
-- 2012 and switched back to this in 2016.
--
--
-- Royal National Agricultural Show - Source & Synopsis:
-- https://www.ekka.com.au/about-us/ekka-dates-public-holiday/
-- The Ekka starts on the first Friday of August - providing this 
-- is not prior to the 5th - in which case it begins on the second
-- Friday.
--
--
-- Queen's Birthday - Source & Synopsis:
-- https://www.officeholidays.com/holidays/australia/queensland/australia-queens-birthday
-- In Queensland, the Queen's Birthday holiday is observed on the first Monday in October.
-- Before 2016, the holiday was observed on the second Monday in June.
--
--
-- Christmas - Synopsis:
-- From Christmas Day 2011, the Holidays Act 1983 provides for an 
-- extra public holiday to be added when Christmas Day, Boxing Day 
-- or New Year’s Day falls on a weekend.
--
--
--==================================================================
DECLARE @YearCounter				int;
DECLARE @YearStartNum				int;
DECLARE @YearEndNum					int;

DECLARE @NewYearsDayDtm				datetime;
DECLARE @NewYearsDayKey				int;
DECLARE @AustraliaDayDtm			datetime;
DECLARE @AustraliaDayKey			int;
DECLARE @EasterDtm					datetime;
DECLARE @ChristmasDayDtm			datetime;
DECLARE @BoxingDayDtm				datetime;

--==================================================================
-- Holiday Variables:
--==================================================================
-- Easter calculation.
DECLARE @EpactCalc					int;
DECLARE @PaschalDaysCalc			int;
DECLARE @NumOfDaysToSunday			int;
DECLARE @EasterMonth				int;
DECLARE @EasterDay					int;

-- Create table to hold the date keys that correspond to Easter.
-- New Years Day.
DECLARE @NewYearsDayTbl TABLE (DateKey int);

-- Australia Day.
DECLARE @AustraliaDayTbl TABLE (DateKey int);

-- Good Friday.
DECLARE @GoodFridayTbl TABLE (DateKey int);

-- The Day after Good Friday.
DECLARE @DayAfterGFTlbl TABLE (DateKey int);

-- Easter Sunday.
DECLARE @EasterSundayTbl TABLE (DateKey int);

-- Easter Monday.
DECLARE @EasterMondayTbl TABLE (DateKey int);

-- Labour Day.
DECLARE @LabourDayTbl TABLE (DateKey int);

-- Ekka Day.
DECLARE @EkkaTbl TABLE (DateKey int);

-- Queens Birthday Day.
DECLARE @QueensBirthdayTbl TABLE (DateKey int);

-- Christmas Day.
DECLARE @ChristmasDayTbl TABLE (DateKey int);

-- Boxing Day.
DECLARE @BoxingDayTbl TABLE (DateKey int);

--==================================================================
-- Convert start date and end date to int representation of the years.
--==================================================================
DECLARE @StartDate	datetime;		--Starting value of Date Range.
SET @StartDate =
(
	SELECT TOP 1 [Value] FROM #DateVariables WHERE [Key] = 'StartDate'
)

DECLARE @EndDate	datetime;		--End Value of Date Range.
SET @EndDate =
(
	SELECT TOP 1 [Value] FROM #DateVariables WHERE [Key] = 'EndDate'
)


SET @YearStartNum =
(
	SELECT YEAR(@StartDate)
);

SET @YearEndNum =
(
	SELECT YEAR(@EndDate)
);


SET @YearCounter = @YearStartNum;

WHILE @YearCounter <= @YearEndNum
BEGIN;
	
	--================================================================--
	--                                                                --
	--                        Main Process:                           --
	--                                                                --
	--================================================================--

	--==================================================================
	-- Calculate and Set Easter Dates:
	--================================================================
	SET @EpactCalc = (24 + 19 * (@YearCounter % 19)) % 30;
	SET @PaschalDaysCalc = @EpactCalc - (@EpactCalc / 28);
	
	SET @NumOfDaysToSunday = @PaschalDaysCalc - ( 
	    (@YearCounter + @YearCounter / 4 + @PaschalDaysCalc - 13) % 7 
	);
	
	SET @EasterMonth = 3 + (@NumOfDaysToSunday + 40) / 44;
	
	SET @EasterDay = @NumOfDaysToSunday + 28 - (
	    31 * (@EasterMonth / 4)
	);

	-- Set Easter dates.
	SET @EasterDtm =
	(
		SELECT CONVERT (smalldatetime, RTRIM(@YearCounter)
		    + RIGHT('0'+RTRIM(@EasterMonth), 2)
		    + RIGHT('0'+RTRIM(@EasterDay), 2)
		)
	);

	--==================================================================
	-- Insert to table variables:
	--==================================================================
	-- Insert New Years Day.
	INSERT INTO @NewYearsDayTbl
	SELECT
		CASE
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 1, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '01', '02'))
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 1, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '01', '03'))
			ELSE CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '01', '01'))
		END AS [DateKey];

	-- Insert Australia Day.
	INSERT INTO @AustraliaDayTbl
	SELECT
		CASE
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 1, 26)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '01', '27'))
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 1, 26)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '01', '28'))
			ELSE CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '01', '26'))
		END AS [DateKey];

	-- Insert Good Friday.
	INSERT INTO @GoodFridayTbl
	SELECT (CONVERT (char(8), @EasterDtm, 112) - 2); -- Easter Sunday - 2 day(s).

	-- Insert The Day After Good Friday.
	INSERT INTO @DayAfterGFTlbl
	SELECT (CONVERT (char(8), @EasterDtm, 112) - 1); -- Easter Sunday - 1 day(s).

	-- Insert Easter Sunday.
	INSERT INTO @EasterSundayTbl
	SELECT CONVERT (char(8), @EasterDtm, 112);

	-- Insert Easter Monday.
	INSERT INTO @EasterMondayTbl
	SELECT (CONVERT (char(8), @EasterDtm, 112) + 1); -- Easter Sunday + 1 day(s).

	-- Insert Labour Day (before 2012).
	IF (@YearCounter < 2012)
	BEGIN;
		INSERT INTO @LabourDayTbl
		SELECT
			CASE
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 1 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '01'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 2 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '07'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 3 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '06'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 4 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '05'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 5 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '04'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '03'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '02'))
			END AS [DateKey];
	END;
	
	-- Insert Labour Day (between 2012 and 2015).
	ELSE IF (@YearCounter >= 2012 AND @YearCounter < 2016)
	BEGIN;
		INSERT INTO @LabourDayTbl
		SELECT
			CASE
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 1 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '01'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 2 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '07'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 3 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '06'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 4 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '05'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 5 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '04'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '03'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '02'))
			END AS [DateKey];
	END;

	-- Insert Labour Day (from 2016 onwards).
	ELSE
	BEGIN
		INSERT INTO @LabourDayTbl
		SELECT
			CASE
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 1 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '01'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 2 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '07'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 3 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '06'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 4 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '05'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 5 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '04'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '03'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 05, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '05', '02'))
			END AS [DateKey];

	END;

	-- Insert Ekka.
	INSERT INTO @EkkaTbl
	SELECT
			CASE
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 1 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '10'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 2 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '16'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 3 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '15'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 4 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '14'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 5 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '13'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '12'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 8, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '08', '11'))
			END AS [DateKey];
	
	-- Insert Queen's Birthday.
	IF (@YearCounter < 2016)
	BEGIN;
		INSERT INTO @QueensBirthdayTbl
		SELECT
			CASE
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 1 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '08'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 2 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '14'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 3 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '13'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 4 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '12'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 5 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '11'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '10'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 6, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '06', '09'))
			END AS [DateKey];
	END;
	
	ELSE
	BEGIN
		INSERT INTO @QueensBirthdayTbl
		SELECT
			CASE
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 1 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '01'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 2 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '07'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 3 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '06'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 4 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '05'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 5 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '04'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '03'))
				WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 10, 1)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '10', '02'))
			END AS [DateKey];
	END;

	-- Christmas Day.
	INSERT INTO @ChristmasDayTbl
	SELECT
		CASE
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 12, 25)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '12', '27'))
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 12, 25)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '12', '26'))
			ELSE CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '12', '25'))
		END AS [DateKey];
	
	-- Boxing Day.
	INSERT INTO @BoxingDayTbl
	SELECT
		CASE
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 12, 26)) = 6 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '12', '28'))
			WHEN DATEPART(DW, DATEFROMPARTS(@YearCounter, 12, 26)) = 7 THEN CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '12', '28'))
			ELSE CONVERT(int, CONCAT(CONVERT(nvarchar, @YearCounter), '12', '26'))
		END AS [DateKey];


	-- Increment counter.
	SET @YearCounter += 1;

END;

--==================================================================
-- Update Holdiays in DimDate:
--==================================================================
-- New Years Day.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'New Year''s Day'
WHERE	DateKey IN
(
	SELECT	nyd.DateKey
	FROM	@NewYearsDayTbl nyd
);

-- Australia Day.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Australia Day'
WHERE	DateKey IN
(
	SELECT	aus.DateKey
	FROM	@AustraliaDayTbl aus
);

-- Good Friday.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Good Friday'
WHERE	DateKey IN
(
	SELECT	gf.DateKey
	FROM	@GoodFridayTbl gf
);

-- The Day After Good Friday.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'The Day After Good Friday'
WHERE	DateKey IN
(
	SELECT	dagf.DateKey
	FROM	@DayAfterGFTlbl dagf
);

-- Easter Sunday.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Easter Sunday'
WHERE	DateKey IN
(
	SELECT	es.DateKey
	FROM	@EasterSundayTbl es
);

-- Easter Monday.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Easter Monday'
WHERE	DateKey IN
(
	SELECT	em.DateKey
	FROM	@EasterMondayTbl em
);

-- Labour Day (Qld).
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Labour Day'
WHERE	DateKey IN
(
	SELECT	labour.DateKey
	FROM	@LabourDayTbl labour
);

-- Ekka (Qld).
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'RNA Show Day'
WHERE	DateKey IN
(
	SELECT	ekka.DateKey
	FROM	@EkkaTbl ekka
);

-- Queen's Birhtday (Qld).
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Queen''s Birthday Day'
WHERE	DateKey IN
(
	SELECT	queen.DateKey
	FROM	@QueensBirthdayTbl queen
);

-- Christmas Day.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Christmas Day'
WHERE	DateKey IN
(
	SELECT	xmas.DateKey
	FROM	@ChristmasDayTbl xmas
);

-- Boxing Day.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'Boxing Day'
WHERE	DateKey IN
(
	SELECT	box.DateKey
	FROM	@BoxingDayTbl box
);


--==================================================================
-- Add additional holidays to dbo.DimDate:
--==================================================================

-- ANZAC Day.
UPDATE	dbo.DimDate
SET		IsHoliday = 1,
		Holiday = 'ANZAC Day'
WHERE	[Month] = 4
AND		[DayOfMonth] = 25;


--==================================================================
-- END - SECTION 2: QUEENSLAND HOLIDAYS:
GO
--==================================================================

--==================================================================
--
-- SECTION 3: FISCAL CALENDAR:
--
--==================================================================

DECLARE @DateStart						datetime;
SET @DateStart = (SELECT TOP 1 [Value] FROM #DateVariables WHERE [Key] = 'StartDate');

DECLARE @DateEnd						datetime;
SET @DateEnd = (SELECT TOP 1 [Value] FROM #DateVariables WHERE [Key] = 'EndDate');

DECLARE @FiscalYearStartDtm				smalldatetime;
SET @FiscalYearStartDtm = (DATEFROMPARTS(YEAR(DATEADD(YEAR, -1, @DateStart)), 7, 1));

DECLARE	@FiscalYear						int;
SET @FiscalYear = YEAR(@FiscalYearStartDtm);

DECLARE	@LastYear						int;
SET @LastYear = YEAR(@DateEnd);

DECLARE	@FirstLeapYearInPeriod			int;
SET @FirstLeapYearInPeriod = (SELECT TOP 1 [Value] FROM #IntegerVariables WHERE [Key] = 'FirstLeapYearInPeriod');


--==================================================================
DECLARE @iTemp							int;
DECLARE @LeapWeek						int;
DECLARE @CurrentDate					datetime;
DECLARE @FiscalDayOfYear				int;
DECLARE @FiscalWeekOfYear				int;
DECLARE @FiscalMonth					int;
DECLARE @FiscalQuarter					int;
DECLARE @FiscalQuarterName				varchar(10);
DECLARE @FiscalYearName					varchar(7);
DECLARE @LeapYear						int;


-- Holds the years that have 455 in last quarter.
DECLARE @LeapTable TABLE (leapyear int);

-- Table to contain the fiscal year calendar.
DECLARE @FiscalTbl TABLE
(
		PeriodDate					datetime,
		FiscalDayOfYear				varchar(3),
		FiscalWeekOfYear			varchar(3),
		FiscalMonth					varchar(2), 
		FiscalQuarter				varchar(1),
		FiscalQuarterName			varchar(9),
		FiscalYear					varchar(4),
		FiscalYearName				varchar(7),
		FiscalMonthYear				varchar(10),
		FiscalMMYYYY				varchar(6)
);

--Populate the table with all leap years.
SET @LeapYear = @FirstLeapYearInPeriod;

WHILE (@LeapYear < @LastYear)
BEGIN;
	INSERT INTO @leapTable VALUES (@LeapYear);
	SET @LeapYear = @LeapYear + 5;
END;

--Initiate parameters before loop.
SET @CurrentDate = @FiscalYearStartDtm;
SET @FiscalDayOfYear = 1;
SET @FiscalWeekOfYear = 1;
SET @FiscalMonth = MONTH(@FiscalYearStartDtm);
SET @FiscalQuarter = 3;							-- Set manually.

IF (EXISTS (SELECT * FROM @LeapTable WHERE @FiscalYear = leapyear))
BEGIN;
	SET @LeapWeek = 1;
END;

ELSE
BEGIN;
	SET @LeapWeek = 0;
END;

--==================================================================
-- Loop on days in interval.
WHILE (DATEPART(YY, @CurrentDate) <= @LastYear)
BEGIN;
	
	-- SET fiscal Month.
	SELECT @FiscalMonth =
		CASE 
			WHEN MONTH(@CurrentDate) = 1 THEN 7
			WHEN MONTH(@CurrentDate) = 2 THEN 8
			WHEN MONTH(@CurrentDate) = 3 THEN 9
			WHEN MONTH(@CurrentDate) = 4 THEN 10
			WHEN MONTH(@CurrentDate) = 5 THEN 11
			WHEN MONTH(@CurrentDate) = 6 THEN 12
			WHEN MONTH(@CurrentDate) = 7 THEN 1
			WHEN MONTH(@CurrentDate) = 8 THEN 2
			WHEN MONTH(@CurrentDate) = 9 THEN 3
			WHEN MONTH(@CurrentDate) = 10 THEN 4
			WHEN MONTH(@CurrentDate) = 11 THEN 5
			WHEN MONTH(@CurrentDate) = 12 THEN 6
	END;

	-- SET Fiscal Quarter.
	SELECT @FiscalQuarter =
		CASE 
			WHEN @FiscalMonth BETWEEN 1 AND 3 THEN 1
			WHEN @FiscalMonth BETWEEN 4 AND 6 THEN 2
			WHEN @FiscalMonth BETWEEN 7 AND 9 THEN 3
			WHEN @FiscalMonth BETWEEN 10 AND 12 THEN 4
		END;
		
	SELECT @FiscalQuarterName =
		CASE 
			WHEN @FiscalQuarter = 1 THEN 'First'
			WHEN @FiscalQuarter = 2 THEN 'Second'
			WHEN @FiscalQuarter = 3 THEN 'Third'
			WHEN @FiscalQuarter = 4 THEN 'Fourth'
		END;
		
	-- Set Fiscal Year Name.
	SELECT @FiscalYearName = 'FY ' + CONVERT(varchar, @FiscalYear)

	INSERT INTO @FiscalTbl
	(
		PeriodDate,
		FiscalDayOfYear,
		FiscalWeekOfYear,
		FiscalMonth,
		FiscalQuarter,
		FiscalQuarterName,
		FiscalYear,
		FiscalYearName
	)
	VALUES
	(
		@CurrentDate,
		@FiscalDayOfYear,
		@FiscalWeekOfYear,
		@FiscalMonth,
		@FiscalQuarter,
		@FiscalQuarterName,
		@FiscalYear,
		@FiscalYearName
	);
	
	-- SET next day.
	SET @CurrentDate = DATEADD(DD, 1, @CurrentDate);
	SET @FiscalDayOfYear = @FiscalDayOfYear + 1;
	SET @FiscalWeekOfYear = ((@FiscalDayOfYear - 1) / 7) + 1;
	
	
	--------------------- Reset a new year ---------------------
	IF (@CurrentDate = DATEFROMPARTS(YEAR(@CurrentDate), 7, 1)) 
	BEGIN;
		
		SET @FiscalDayOfYear = 1;
		SET @FiscalWeekOfYear = 1;
		SET @FiscalYear = @FiscalYear + 1;
		IF (EXISTS (SELECT * FROM @leapTable WHERE @FiscalYear = leapyear))
		BEGIN;
			SET @LeapWeek = 1;
		END;

		ELSE
		BEGIN;
			SET @LeapWeek = 0;
		END;
	END;
END;

--==================================================================
-- Set FiscalMonthYear.
UPDATE	@FiscalTbl
SET
		FiscalMonthYear = 
			CASE MONTH(PeriodDate)
				WHEN 1		THEN 'Jan'
				WHEN 2		THEN 'Feb'
				WHEN 3		THEN 'Mar'
				WHEN 4		THEN 'Apr'
				WHEN 5		THEN 'May'
				WHEN 6		THEN 'Jun'
				WHEN 7		THEN 'Jul'
				WHEN 8		THEN 'Aug'
				WHEN 9		THEN 'Sep'
				WHEN 10		THEN 'Oct'
				WHEN 11		THEN 'Nov'
				WHEN 12		THEN 'Dec'
			END + '-' + CONVERT(varchar, FiscalYear);

-- Set FiscalMMYYYY.
UPDATE	@FiscalTbl
SET
		FiscalMMYYYY = RIGHT('0' + CONVERT(varchar, MONTH(PeriodDate)), 2) + CONVERT(varchar, FiscalYear);

--==================================================================
UPDATE
		dbo.DimDate
SET
		FiscalWeekOfYear = a.FiscalWeekOfYear,
		FiscalMonth = a.FiscalMonth,
		FiscalQuarter = a.FiscalQuarter,
		FiscalQuarterName = a.FiscalQuarterName,
		FiscalYear = a.FiscalYear,
		FiscalYearName = a.FiscalYearName,
		FiscalMonthYear = a.FiscalMonthYear,
		FiscalMMYYYY = a.FiscalMMYYYY
FROM	
		@FiscalTbl a
INNER JOIN 
		dbo.DimDate b
			ON a.PeriodDate = b.Date;

--==================================================================
-- END - SECTION 3: FISCAL CALENDAR:
GO
--==================================================================



--==================================================================
-- See the results.
SELECT * FROM dbo.DimDate;
GO

