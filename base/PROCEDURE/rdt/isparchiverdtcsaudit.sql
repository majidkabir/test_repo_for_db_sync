SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stor Proc: RDT.ispArchiveRDTCSAudit                                      */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose: Archive rdtCSAudit table                                    */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Ver.   Author     Purposes                               */  
/* 2006-03-12  1.0    UngDH      Created                                */  
/* 2009-09-24  1.1    Vicky      Should point to RDT.ArchiveParameters  */  
/************************************************************************/  
  
CREATE PROC [RDT].[ispArchiveRDTCSAudit]  
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
      @cDateType = RDT_PPP_PPA_DateType,  
      @nRetainDays = RDT_PPP_PPA_NoDaysToRetain,  
      @cCopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase  
   FROM RDT.ArchiveParameters (NOLOCK)  
   WHERE Archivekey = @cArchiveKey  
   IF @@ROWCOUNT = 0  
   BEGIN  
      SET @n_Err = 60751  
      SET @c_ErrMsg = 'ArchiveKey does not exist (ispArchiveRDTCSAudit)'  
      GOTO Fail  
   END  
  
   -- Calculate archive date  
   SET @dArchiveDate = DATEADD( DAY, -@nRetainDays, CONVERT( NVARCHAR( 10), GETDATE(), 120))  
  
   -- Validate target db exists  
   IF DB_ID( @cCopyToDB) IS NULL  
   BEGIN  
      SET @n_Err = 60752  
      SET @c_ErrMsg = 'Target database does not exist (ispArchiveRDTCSAudit)'  
      GOTO Fail  
   END  
  
   -- Log archive starts  
   SET @cAlertMessage = 'Archiving rdtCSAudit started with parameters' +   
      ': LiveDatabaseName = ' + RTRIM(@cCopyFromDB) +   
      '; ArchiveDatabaseName = ' + RTRIM(@cCopyToDB) +   
      '; CopyRowsToArchive = ' + RTRIM( @cCopyRowsToArchiveDatabase) +   
      '; DateType = ' + RTRIM( @cDateType) +  
      '; NoDaysToRetain = ' +  CAST( @nRetainDays AS NVARCHAR( 10))  
   SET @b_success = 1  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTCSAudit',  
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
      'rdtCSAudit',  
      @b_success OUTPUT,   
      @n_Err OUTPUT,   
      @c_ErrMsg OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
   SET @b_success = 1  
   EXECUTE RDT.nsp_Build_Archive_Table  
      @cCopyFromDB,   
      @cCopyToDB,   
      'rdtCSAudit_Load',  
      @b_success OUTPUT,   
      @n_Err OUTPUT,   
      @c_ErrMsg OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
   -- Synchronize both table structure  
   SET @b_success = 1  
   EXECUTE RDT.nspBuildAlterTableString   
      @cCopyToDB,  
      'rdtCSAudit',  
      @b_success OUTPUT,  
      @n_Err     OUTPUT,   
      @c_ErrMsg  OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
   SET @b_success = 1  
   EXECUTE RDT.nspBuildAlterTableString   
      @cCopyToDB,  
      'rdtCSAudit_Load',  
      @b_success OUTPUT,  
      @n_Err     OUTPUT,   
      @c_ErrMsg  OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
   -- Candidate rdtCSAudit.GroupID for archive  
   DECLARE @tGroupID TABLE  
   (  
      GroupID INT NOT NULL  
    PRIMARY KEY CLUSTERED   
    (  
     [GroupID]  
    )  
   )  
  
   -- Get archiveble records base on rdtCSAudit.GroupID  
   INSERT INTO @tGroupID  
   SELECT DISTINCT GroupID  
   FROM RDT.RDTCSAudit (NOLOCK)   
   WHERE @dArchiveDate >   
         CASE @cDateType   
            WHEN '1' THEN EditDate   
            WHEN '2' THEN AddDate   
         END  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_Err = 60753  
      SET @c_ErrMsg = 'Insert @tGroupID fail (ispArchiveRDTCSAudit)'  
      GOTO Fail  
   END  
  
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
      SET @c_ErrMsg = 'Delete GroupID that span across 2 days fail (ispArchiveRDTCSAudit)'  
      GOTO Fail  
   END  
  
   -- Archivable record in rdtCSAudit, base on group ID  
   DECLARE @tCSAudit TABLE  
   (  
      RowRef INT NOT NULL  
    PRIMARY KEY CLUSTERED   
    (  
     [RowRef]  
    )  
   )  
  
   -- Stamp ArchiveCop for rdtCSAudit  
   INSERT INTO @tCSAudit (RowRef)  
   SELECT CA.RowRef  
   FROM RDT.RDTCSAudit CA (NOLOCK)  
      INNER JOIN @tGroupID T ON (CA.GroupID = T.GroupID)  
  
   DECLARE @curCSAudit CURSOR  
   SET @curCSAudit = CURSOR SCROLL FOR   
      SELECT RowRef FROM @tCSAudit  
   OPEN @curCSAudit  
  
   FETCH FIRST FROM @curCSAudit INTO @nRowRef  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      BEGIN TRAN  
      UPDATE RDT.rdtCSAudit WITH (ROWLOCK) SET  
         ArchiveCop = '9'  
      FROM RDT.rdtCSAudit CA  
      WHERE RowRef = @nRowRef  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Err = 60755  
         SET @c_ErrMsg = 'Stamp ArchiveCop fail (ispArchiveRDTCSAudit)'  
         GOTO RollBackTran  
      END  
      COMMIT TRAN  
  
      FETCH NEXT FROM @curCSAudit INTO @nRowRef  
   END  
  
   -- Stamp ArchiveCop for rdtCSAudit_Load  
   DECLARE @curCSAudit_Load CURSOR  
   SET @curCSAudit_Load = CURSOR SCROLL FOR   
      SELECT GroupID FROM @tGroupID  
   OPEN @curCSAudit_Load  
  
   FETCH FIRST FROM @curCSAudit_Load INTO @nGroupID  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      BEGIN TRAN  
      UPDATE RDT.rdtCSAudit_Load WITH (ROWLOCK) SET  
         ArchiveCop = '9'  
      WHERE GroupID = @nGroupID  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Err = 60755  
         SET @c_ErrMsg = 'Stamp ArchiveCop fail (ispArchiveRDTCSAudit)'  
         GOTO RollBackTran  
      END  
      COMMIT TRAN  
  
      FETCH NEXT FROM @curCSAudit_Load INTO @nGroupID  
   END  
  
   -- Move or delete archiable records  
   IF @cCopyRowsToArchiveDatabase = 'Y'  
   BEGIN  
      -- Move rdtCSAudit  
      SET @b_success = 1  
      EXECUTE RDT.nsp_Build_Insert  
         @cCopyToDB,   
         'rdtCSAudit',   
         1,  
         @b_success OUTPUT,   
         @n_Err     OUTPUT,   
         @c_ErrMsg  OUTPUT  
      IF @b_success <> 1 GOTO Fail  
        
      -- Move rdtCSAudit_Load  
      SET @b_success = 1  
      EXECUTE RDT.nsp_Build_Insert  
         @cCopyToDB,   
         'rdtCSAudit_Load',   
         1,  
         @b_success OUTPUT,   
         @n_Err     OUTPUT,   
         @c_ErrMsg  OUTPUT  
      IF @b_success <> 1 GOTO Fail  
   END  
   ELSE  
   BEGIN  
      -- Purge rdtCSAudit  
      FETCH FIRST FROM @curCSAudit INTO @nRowRef  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         BEGIN TRAN  
         DELETE RDT.RDTCSAudit WITH (ROWLOCK)  
         WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
    BEGIN  
            SET @n_Err = 60756  
            SET @c_ErrMsg = 'Delete RDTCSAudit fail (ispArchiveRDTCSAudit)'  
            GOTO RollBackTran  
         END  
         COMMIT TRAN  
  
         FETCH NEXT FROM @curCSAudit INTO @nRowRef  
      END  
  
      -- Purge rdtCSAudit_Load  
      FETCH FIRST FROM @curCSAudit_Load INTO @nGroupID  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         BEGIN TRAN  
         DELETE RDT.rdtCSAudit_Load WITH (ROWLOCK)  
         WHERE GroupID = @nGroupID  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Err = 60756  
            SET @c_ErrMsg = 'Delete RDTCSAudit fail (ispArchiveRDTCSAudit)'  
            GOTO RollBackTran  
         END  
         COMMIT TRAN  
  
         FETCH NEXT FROM @curCSAudit_Load INTO @nGroupID  
      END  
  
   END  
  
   CLOSE @curCSAudit  
   CLOSE @curCSAudit_Load  
   DEALLOCATE @curCSAudit  
   DEALLOCATE @curCSAudit_Load  
  
   -- Log end of archive  
   SET @b_success = 1  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTCSAudit',  
      @c_AlertMessage = 'Archiving rdtCSAudit ended successfully',  
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
   SET @cAlertMessage = 'Archiving rdtCSAudit failed. ErrNo=' + CAST( @n_Err AS NVARCHAR( 10)) + ' ErrMsg=' + @c_ErrMsg  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTCSAudit',  
      @c_AlertMessage = @cAlertMessage,   
      @n_Severity     = 0,  
      @b_success      = 0,  
      @n_Err          = 0,  
      @c_ErrMsg       = ''  
  
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  

GO