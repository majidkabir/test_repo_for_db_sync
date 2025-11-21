SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stor Proc: ispArchiveRDTToteInfoLog                                  */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose: Archive rdtToteInfoLog table                                */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver     Purposes                                 */
/* 2009-10-29  Vicky   1.0     Created                                  */
/* 2010-11-02  KHLim   1.1     Performance Tuning                       */
/************************************************************************/

CREATE PROC [RDT].[ispArchiveRDTToteInfoLog]
     @cArchiveKey  NVARCHAR(10)             
   , @b_Success    INT        OUTPUT
   , @n_Err        INT        OUTPUT    
   , @c_ErrMsg     NVARCHAR( 250) OUTPUT    
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 

   -- Misc var
   DECLARE 
      @dArchiveDate    DATETIME, 
      @cAlertMessage   NVARCHAR( 255),
      @cStore          NVARCHAR(4),
      @nPIKNo          INT, 
      @nToteNo         INT
    
  
   -- ArchiveParameters
   DECLARE
      @cCopyFromDB   NVARCHAR( 30),
      @cCopyToDB     NVARCHAR( 30),
      @cDateType     NVARCHAR( 10), -- 1=EditDate, 2=AddDate
      @nRetainDays   INT,       -- No of days data is retained
      @cCopyRowsToArchiveDatabase NVARCHAR( 1)

   -- Get ArchiveParameters settings
   SELECT 
      @cCopyFromDB = LiveDatabaseName,
      @cCopyToDB = ArchiveDatabaseName,
      @cDateType = RDT_ARCHIVE_DateType, -- common field
      @nRetainDays = RDT_TABLE_NoDaysToRetain, -- common field
      @cCopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
   FROM RDT.ArchiveParameters WITH (NOLOCK)
   WHERE Archivekey = @cArchiveKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_Err = 60751
      SET @c_ErrMsg = 'ArchiveKey does not exist (ispArchiveRDTToteInfoLog)'
      GOTO Fail
   END

   -- Calculate archive date
   SET @dArchiveDate = DATEADD( DAY, -@nRetainDays, CONVERT( NVARCHAR( 10), GETDATE(), 120))

   -- Validate target db exists
   IF DB_ID(@cCopyToDB) IS NULL
   BEGIN
      SET @n_Err = 60752
      SET @c_ErrMsg = 'Target database does not exist (ispArchiveRDTToteInfoLog)'
      GOTO Fail
   END

   -- Log archive starts
   SET @cAlertMessage = 'Archiving rdtToteInfoLog started with parameters' + 
      ': LiveDatabaseName = ' + RTRIM(@cCopyFromDB) + 
      '; ArchiveDatabaseName = ' + RTRIM(@cCopyToDB) + 
      '; CopyRowsToArchive = ' + RTRIM( @cCopyRowsToArchiveDatabase) + 
      '; DateType = ' + RTRIM( @cDateType) +
      '; NoDaysToRetain = ' +  CAST( @nRetainDays AS NVARCHAR( 10))
   SET @b_success = 1
   EXECUTE nspLogAlert
      @c_ModuleName   = 'ispArchiveRDTToteInfoLog',
      @c_AlertMessage = @cAlertMessage,
      @n_Severity     = 0,
      @b_success      = @b_success OUTPUT,
      @n_Err          = @n_Err     OUTPUT,
      @c_ErrMsg       = @c_ErrMsg  OUTPUT
   IF @b_success <> 1 GOTO Fail

   -- Create if table exist in archive DB. If not, create it
   SET @b_success = 1
   EXECUTE RDT.nsp_Build_Archive_Table
      @cCopyFromDB, 
      @cCopyToDB, 
      'rdtToteInfoLog',
      @b_success OUTPUT, 
      @n_Err OUTPUT, 
      @c_ErrMsg OUTPUT
   IF @b_success <> 1 GOTO Fail

   -- Synchronize both table structure
   SET @b_success = 1
   EXECUTE RDT.nspBuildAlterTableString 
      @cCopyToDB,
      'rdtToteInfoLog',
      @b_success OUTPUT,
      @n_Err     OUTPUT, 
      @c_ErrMsg  OUTPUT
   IF @b_success <> 1 GOTO Fail


   DECLARE RowRef_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT PIKNo, Store, ToteNo    
   FROM RDT.rdtToteInfoLog WITH (NOLOCK) 
   WHERE @dArchiveDate > 
         CASE @cDateType 
            WHEN '1' THEN EditDate 
            WHEN '2' THEN AddDate 
         END
   ORDER BY PIKNo, Store, ToteNo

/*
   -- Remove those GroupID that span across 2 days (scan across mid night)
   -- where half archivable, the other half is not
   DELETE @tGroupID 
   FROM RDT.RDTCSAudit CA (NOLOCK)
      INNER JOIN @tGroupID T ON (CA.GroupID = T.GroupID)
   WHERE @dArchiveDate = 
         CASE @cDateType 
            WHEN '1' THEN CONVERT( NVARCHAR( 10), EditDate, 120)
            WHEN '2' THEN CONVERT( NVARCHAR( 10), AddDate , 120)
         END
   IF @@ERROR <> 0
   BEGIN
      SET @n_Err = 60754
      SET @c_ErrMsg = 'Delete GroupID that span across 2 days fail (ispArchiveRDTPPA)'
      GOTO Fail
   END
*/

   OPEN RowRef_CUR    
    
   FETCH NEXT FROM RowRef_CUR INTO @nPIKNo, @cStore, @nToteNo    
   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRAN
      UPDATE RDT.rdtToteInfoLog WITH (ROWLOCK) SET
         ArchiveCop = '9'
      FROM RDT.rdtToteInfoLog
      WHERE PIKNo = @nPIKNo
      AND   Store = @cStore
      AND   ToteNo = @nToteNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_Err = 60755
         SET @c_ErrMsg = 'Stamp ArchiveCop fail (ispArchiveRDTToteInfoLog)'
         GOTO RollBackTran
      END
      COMMIT TRAN

      FETCH NEXT FROM RowRef_CUR INTO @nPIKNo, @cStore, @nToteNo
   END

   -- Move and delete archivable records
   IF @cCopyRowsToArchiveDatabase = 'Y'
      BEGIN
         -- Move rdtToteInfoLog
         SET @b_success = 1
         EXECUTE RDT.nsp_Build_Insert
            @cCopyToDB, 
            'rdtToteInfoLog', -- @c_tablename
            1,
            @b_success OUTPUT, 
            @n_Err     OUTPUT, 
            @c_ErrMsg  OUTPUT
         IF @b_success <> 1 GOTO Fail
      END
   ELSE
   BEGIN
      SET ROWCOUNT 10000
      WHILE EXISTS ( SELECT 1    
                     FROM RDT.rdtToteInfoLog WITH (NOLOCK)     
                     WHERE ArchiveCop= '9' )
      BEGIN
         DELETE RDT.rdtToteInfoLog 
         WHERE ArchiveCop= '9'   
      END
      SET ROWCOUNT 0
   END

   -- Log end of archive
   SET @b_success = 1
   EXECUTE nspLogAlert
      @c_ModuleName   = 'ispArchiveRDTToteInfoLog',
      @c_AlertMessage = 'Archiving rdtToteInfoLog ended successfully',
      @n_Severity     = 0,
      @b_success      = @b_success OUTPUT,
      @n_Err          = @n_Err     OUTPUT,
      @c_ErrMsg       = @c_ErrMsg  OUTPUT
      IF @b_success <> 1 GOTO Fail

   RETURN

RollBackTran:
   ROLLBACK TRAN
Fail:
   -- Get error message
   IF @c_ErrMsg = '' AND @n_Err <> 0
      SELECT @c_ErrMsg = description
      FROM master.dbo.sysmessages
      WHERE [error] = @n_Err
   
   -- Log the error
   SET @cAlertMessage = 'Archiving rdtToteInfoLog failed. ErrNo=' + CAST( @n_Err AS NVARCHAR( 10)) + ' ErrMsg=' + @c_ErrMsg
   EXECUTE nspLogAlert
      @c_ModuleName   = 'ispArchiveRDTToteInfoLog',
      @c_AlertMessage = @cAlertMessage, 
      @n_Severity     = 0,
      @b_success      = 0,
      @n_Err          = 0,
      @c_ErrMsg       = ''

   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012


GO