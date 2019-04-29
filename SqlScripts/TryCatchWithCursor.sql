/*******************************************************************
	UPDATE YOUR_TABLE_HERE:
	Synopsis:
	This is a generic template that has been adapted from Microsoft
	Docs "Try...Catch" resource.
	https://docs.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql?view=sql-server-2017
	It uses the XACT_STATE to pick up errors and the CATCH block
	to handle them.
	Additionally this script employs a cursor fetch to handle 
	multiple updates, inserts, or deletes.
	Adapt this as needed, where a script doesn't already exist for
	the data-fix.
*******************************************************************/
USE [SomeDatabase];
GO

PRINT N'/******************************************************************/';
PRINT N'/                                                                  /';
PRINT N'/                    UPDATE YOUR_TABLE_HERE                        /';
PRINT N'/                                                                  /';
PRINT N'/******************************************************************/';

SET XACT_ABORT ON;

DECLARE @SHOW_DEBUG								bit;
DECLARE @COMMIT_CHANGES							bit;

DECLARE @RowCount								int;

DECLARE @ActionRequests TABLE 
(
		ActionRequestId							int IDENTITY(1, 1)
	,	ServiceNowIdCde							nvarchar(10)
	,	PrimaryKeyId							int
	,	NewValueTxt								nvarchar(MAX)
);

SET @SHOW_DEBUG = 1;
SET @COMMIT_CHANGES = 0;
SET	@RowCount = 0;

PRINT N'/******************************************************************/';
PRINT N'/                                                                  /';
PRINT N'/             INSERT INTO ACTION REQUEST TABLE                     /';
PRINT N'/                                                                  /';
PRINT N'/******************************************************************/';


INSERT INTO @ActionRequests VALUES ('DefectGEN', 'SNOW_Id', 1, 'New data goes here...');


/*******************************************************************
INIT PROCESS VARIABLES:
********************************************************************/
DECLARE @ServiceNowIdCde						nvarchar(10);
DECLARE @PrimaryKeyId							int;
DECLARE @SecondaryKeyId							int;
DECLARE @NewValueTxt							nvarchar(MAX);
DECLARE @NewHistoryId							int;

DECLARE ActionRequestCursor CURSOR
FOR
	SELECT		ServiceNowIdCde,
				PrimaryKeyId,
				NewValueTxt
	FROM		@ActionRequests
	ORDER BY	ActionRequestId ASC;

PRINT N'/******************************************************************/';
PRINT N'/                                                                  /';
PRINT N'/                       OPEN CURSOR                                /';
PRINT N'/                                                                  /';
PRINT N'/******************************************************************/';
OPEN ActionRequestCursor;

FETCH NEXT FROM ActionRequestCursor
INTO @ServiceNowIdCde, @PrimaryKeyId, @NewValueTxt;

BEGIN TRY
	BEGIN TRANSACTION
		
		WHILE @@FETCH_STATUS = 0
		BEGIN;

			SET @SecondaryKeyId  = 
			(
				SELECT	ForeignKeyId 
				FROM	RelatedTable 
				WHERE	PrimaryKeyId = @PrimaryKeyId
			);
			


			IF @SHOW_DEBUG = 1 
			BEGIN;
				PRINT N'-----------------------------------------------------------------';
				PRINT N' Cursor Fetch ' +  CAST((@RowCount + 1) AS nvarchar(8)) + N' Values: ';
				PRINT N'-----------------------------------------------------------------';
				PRINT N'@ServiceNowIdCde : ' + ISNULL(CAST(@ServiceNowIdCde	AS nvarchar(255)), N'NULL');
				PRINT N'@PrimaryKeyId    : ' + ISNULL(CAST(@PrimaryKeyId	AS nvarchar(255)), N'NULL');
				PRINT N'@SecondaryKeyId  : ' + ISNULL(CAST(@SecondaryKeyId	AS nvarchar(255)), N'NULL');	
				PRINT N'@NewValueTxt     : ' + ISNULL(CAST(@NewValueTxt		AS nvarchar(255)), N'NULL');	
				PRINT N'';
			END;

			/*******************************************************************
			VALIDATION:
			*******************************************************************/
			PRINT N'Verifying @SecondaryKeyId...';

			IF (@SecondaryKeyId IS NULL)
			BEGIN;
				THROW 51000, N'The foreign key related record does not exist!', 1;
			END;

			PRINT N'';

			/*******************************************************************
			MAIN PROCESS:
			*******************************************************************/
			PRINT N'UPDATE YOUR_TABLE_HERE...';

			IF @SHOW_DEBUG = 1
			BEGIN;
				SELECT	'YOUR_TABLE_HERE', *
				FROM	YOUR_TABLE_HERE
				WHERE	PrimaryKeyId = @PrimaryKeyId
				AND		ForeignKeyId = @SecondaryKeyId;
			END;

			UPDATE	YOUR_TABLE_HERE
			SET		SomeColumn = @NewValueTxt
				,	VersionNum += 1
			WHERE	PrimaryKeyId = @PrimaryKeyId
			AND		ForeignKeyId = @SecondaryKeyId;

			/******************************************************************/
			PRINT N'INSERT YOUR_TABLE_HERE_HIST...';

			INSERT INTO YOUR_TABLE_HERE_HIST
			(
					UserId,
					StateId,
					EventNme,
					EventDtm,
					UpdateDtm,
					VersionNum
			)
			VALUES
			( 
					1,
					1,
					CONCAT('Refer to incident ', @ServiceNowIdCde),
					CURRENT_TIMESTAMP,
					CURRENT_TIMESTAMP,
					1
			);

			--==================================================================
			-- Get the primary key for the new row.
			--==================================================================
			SET @NewHistoryId = SCOPE_IDENTITY();

			IF @SHOW_DEBUG = 1
			BEGIN
				PRINT N'Verifying history row after insert...';
				PRINT N'New YOUR_TABLE_HERE_HIST_ID: ' + CAST(@NewHistoryId AS nvarchar(32);

				SELECT	'after insert: YOUR_TABLE_HERE_HIST', *
				FROM	YOUR_TABLE_HERE_HIST
				WHERE	HistoryId = @NewHistoryId;
			END;

			--==================================================================
			-- Cursor iterations++
			--==================================================================
			SET @RowCount += 1;

			/******************************************************************/
			
			FETCH NEXT FROM ActionRequestCursor
			INTO @ServiceNowIdCde, @PrimaryKeyId, @NewValueTxt;

		END	
	

	IF @COMMIT_CHANGES = 1
	BEGIN;
		PRINT N'/******************************************************************/';
		PRINT N'/                                                                  /';
		PRINT N'/                    DEALLOCATING CURSOR                           /';
		PRINT N'/                                                                  /';
		PRINT N'/******************************************************************/';
		CLOSE ActionRequestCursor;
		DEALLOCATE ActionRequestCursor;

		PRINT N'';
		PRINT N'Committing transaction...';
		COMMIT TRANSACTION;
		PRINT N'Successfully updated ' + CAST(@RowCount AS nvarchar(32)) +  ' YOUR_TABLE_HERE record(s)';
	END;

	ELSE
	BEGIN;
		PRINT N'/******************************************************************/';
		PRINT N'/                                                                  /';
		PRINT N'/                    DEALLOCATING CURSOR                           /';
		PRINT N'/                                                                  /';
		PRINT N'/******************************************************************/';
		CLOSE ActionRequestCursor
		DEALLOCATE ActionRequestCursor

		PRINT N'';
		PRINT N'Rolling back transaction...';
		ROLLBACK TRANSACTION;
	END;

END TRY

BEGIN CATCH
	
	PRINT N'/******************************************************************/';
	PRINT N'/                                                                  /';
	PRINT N'/                    DEALLOCATING CURSOR                           /';
	PRINT N'/                                                                  /';
	PRINT N'/******************************************************************/';
	CLOSE ActionRequestCursor;
	DEALLOCATE ActionRequestCursor;


	SELECT	N'' AS [<<ERROR>>]
		,	ERROR_NUMBER()			AS [error_number]
		,	ERROR_SEVERITY()		AS [error_severity]
		,	ERROR_STATE()			AS [error_state]
		,	ERROR_LINE()			AS [error_line]
		,	ERROR_PROCEDURE()		AS [error_procedure]
		,	ERROR_MESSAGE()			AS [error_message];

	PRINT N'Error num  : ' + ISNULL(CAST(ERROR_NUMBER()		AS nvarchar(64)),	N'NULL');
	PRINT N'Error Line : ' + ISNULL(CAST(ERROR_LINE()		AS nvarchar(64)),	N'NULL');
	PRINT N'Message    : ' + ISNULL(CAST(ERROR_MESSAGE()	AS nvarchar(4000)),	N'NULL');

	/*****************************************************************/
	/*		TEST XACT_STATE:                                         */
	/*		----------------                                         */
	/*		If 1, the transaction is committable.                    */
	/*		If -1, the transaction is uncommittable and should       */   
	/*		be rolled back.                                          */  
	/*		XACT_STATE = 0 means that there is no transaction and    */  
	/*		a commit or rollback operation would generate an error.  */
	/*****************************************************************/

	IF (XACT_STATE()) = -1
	BEGIN;
		PRINT N'';
		PRINT N'The transaction is in an uncommittable state...';
		PRINT N'Rolling back transaction...';
		ROLLBACK TRANSACTION;
	END;

	IF (XACT_STATE()) = 1
	BEGIN;
		IF @COMMIT_CHANGES = 1
		BEGIN;
			PRINT N'';
			PRINT N'The transaction is committable - Committing transaction...';
			COMMIT TRANSACTION;
			PRINT N'Successfully updated ' + CAST(@RowCount AS nvarchar(32)) +  ' YOUR_TABLE_HERE record(s)';
		END;

		ELSE
		BEGIN;
			PRINT N'';
			PRINT N'The transaction is committable , however @COMMIT_CHANGES is set to 0...';
			PRINT N'Rolling back transaction...';
			ROLLBACK TRANSACTION;
		END;
	END;

END CATCH;
GO