SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stor Proc: ispArchiveRDTBatchPO                                      */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose: Archive RDTCSAudit_BatchPO table                            */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author  Ver     Purposes                                 */  
/* 2009-09-24  Vicky   1.0     Created                                  */  
/************************************************************************/  
  
CREATE PROC [RDT].[ispArchiveRDTBatchPO]  
     @cArchiveKey  NVARCHAR(10)               
   , @b_Success    INT        OUTPUT  
   , @n_Err        INT        OUTPUT      
   , @c_ErrMsg     NVARCHAR( 250) OUTPUT      
AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
   -- Misc var  
   DECLARE   
      @dArchiveDate    DATETIME,   
      @cAlertMessage   NVARCHAR( 255),  
      @nRowRef         INT,   
      @nGroupID        INT  
    
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
      SET @c_ErrMsg = 'ArchiveKey does not exist (ispArchiveRDTBatchPO)'  
      GOTO Fail  
   END  
  
   -- Calculate archive date  
   SET @dArchiveDate = DATEADD( DAY, -@nRetainDays, CONVERT( NVARCHAR( 10), GETDATE(), 120))  
  
   -- Validate target db exists  
   IF DB_ID(@cCopyToDB) IS NULL  
   BEGIN  
      SET @n_Err = 60752  
      SET @c_ErrMsg = 'Target database does not exist (ispArchiveRDTBatchPO)'  
      GOTO Fail  
   END  
  
   -- Log archive starts  
   SET @cAlertMessage = 'Archiving RDTCSAudit_BatchPO started with parameters' +   
      ': LiveDatabaseName = ' + RTRIM(@cCopyFromDB) +   
      '; ArchiveDatabaseName = ' + RTRIM(@cCopyToDB) +   
      '; CopyRowsToArchive = ' + RTRIM( @cCopyRowsToArchiveDatabase) +   
      '; DateType = ' + RTRIM( @cDateType) +  
      '; NoDaysToRetain = ' +  CAST( @nRetainDays AS NVARCHAR( 10))  
   SET @b_success = 1  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTBatchPO',  
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
      'RDTCSAudit_BatchPO',  
      @b_success OUTPUT,   
      @n_Err OUTPUT,   
      @c_ErrMsg OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
   -- Synchronize both table structure  
   SET @b_success = 1  
   EXECUTE RDT.nspBuildAlterTableString   
      @cCopyToDB,  
      'RDTCSAudit_BatchPO',  
      @b_success OUTPUT,  
      @n_Err     OUTPUT,   
      @c_ErrMsg  OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
  
   -- Candidate RDTCSAudit_BatchPO.RowRef for archive  
   DECLARE @tRowRef TABLE  
   (  
      RowRef INT NOT NULL  
    PRIMARY KEY CLUSTERED   
    (  
     [RowRef]  
    )  
   )  
  
   -- Get archiveble records base on RDTCSAudit_BatchPO.RowRef  
   INSERT INTO @tRowRef  
   SELECT DISTINCT RowRef  
   FROM RDT.RDTCSAudit_BatchPO WITH (NOLOCK)   
   WHERE @dArchiveDate >   
         CASE @cDateType   
            --WHEN '1' THEN EditDate   
            WHEN '2' THEN AddDate   
         END  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_Err = 60753  
      SET @c_ErrMsg = 'Insert @tRowRef fail (ispArchiveRDTBatchPO)'  
      GOTO Fail  
   END  
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
  
   -- Archivable record in RDTCSAudit_BatchPO, base on RowRef  
   DECLARE @tRDTBatchPO TABLE  
   (  
      RowRef INT NOT NULL  
    PRIMARY KEY CLUSTERED   
    (  
     [RowRef]  
    )  
   )  
  
   -- Stamp ArchiveCop for RDTCSAudit_BatchPO  
   INSERT INTO @tRDTBatchPO (RowRef)  
   SELECT STT.RowRef  
   FROM RDT.RDTCSAudit_BatchPO STT (NOLOCK)  
      INNER JOIN @tRowRef R ON (STT.RowRef = R.RowRef)  
  
   DECLARE @curRDTBatchPO CURSOR  
   SET @curRDTBatchPO = CURSOR SCROLL FOR   
      SELECT RowRef FROM @tRDTBatchPO  
   OPEN @curRDTBatchPO  
  
   FETCH FIRST FROM @curRDTBatchPO INTO @nRowRef  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      BEGIN TRAN  
      UPDATE RDT.RDTCSAudit_BatchPO WITH (ROWLOCK) SET  
         ArchiveCop = '9'  
      FROM RDT.RDTCSAudit_BatchPO  
      WHERE RowRef = @nRowRef  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Err = 60755  
         SET @c_ErrMsg = 'Stamp ArchiveCop fail (ispArchiveRDTBatchPO)'  
         GOTO RollBackTran  
      END  
      COMMIT TRAN  
  
      FETCH NEXT FROM @curRDTBatchPO INTO @nRowRef  
   END  
  
   -- Move and delete archivable records  
   IF @cCopyRowsToArchiveDatabase = 'Y'  
      BEGIN  
         -- Move RDTCSAudit_BatchPO  
         SET @b_success = 1  
         EXECUTE RDT.nsp_Build_Insert  
            @cCopyToDB,   
            'RDTCSAudit_BatchPO', -- @c_tablename  
            1,  
            @b_success OUTPUT,   
            @n_Err     OUTPUT,   
            @c_ErrMsg  OUTPUT  
         IF @b_success <> 1 GOTO Fail  
      END  
   ELSE  
   BEGIN  
      -- Purge RDTCSAudit_BatchPO  
      FETCH FIRST FROM @curRDTBatchPO INTO @nRowRef  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         BEGIN TRAN  
         DELETE RDT.RDTCSAudit_BatchPO WITH (ROWLOCK)  
         WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Err = 60756  
            SET @c_ErrMsg = 'Delete RDTCSAudit_BatchPO fail (ispArchiveRDTBatchPO)'  
            GOTO RollBackTran  
         END  
         COMMIT TRAN  
  
         FETCH NEXT FROM @curRDTBatchPO INTO @nRowRef  
      END  
   END  
  
   CLOSE @curRDTBatchPO  
   DEALLOCATE @curRDTBatchPO  
  
   -- Log end of archive  
   SET @b_success = 1  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTBatchPO',  
      @c_AlertMessage = 'Archiving RDTCSAudit_BatchPO ended successfully',  
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
   SET @cAlertMessage = 'Archiving RDTCSAudit_BatchPO failed. ErrNo=' + CAST( @n_Err AS NVARCHAR( 10)) + ' ErrMsg=' + @c_ErrMsg  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTBatchPO',  
      @c_AlertMessage = @cAlertMessage,   
      @n_Severity     = 0,  
      @b_success     = 0,  
      @n_Err          = 0,  
      @c_ErrMsg       = ''  
  
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  

GO