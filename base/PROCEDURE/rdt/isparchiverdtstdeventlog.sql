SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stor Proc: ispArchiveRDTStdEventLog                                  */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose: Archive RDT Standard EventLog table                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author  Ver     Purposes                                 */  
/* 2009-09-01  Vicky   1.0     Created                                  */  
/* 2010-10-24  TLTING  1.2     Performance Tune                         */ 
/* 2019-04-12  TLTING01 1.3    default date filter - event date         */
/************************************************************************/  
  
CREATE PROC [RDT].[ispArchiveRDTStdEventLog]  
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
      @nEventNum       INT,   
      @nGroupID        INT  
    
   -- ArchiveParameters  
   DECLARE  
      @cCopyFromDB   NVARCHAR( 30),  
      @cCopyToDB     NVARCHAR( 30),  
      @cDateType     NVARCHAR( 10), -- 1=EditDate, 2=AddDate, 3=EventDateTime  
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
      SET @c_ErrMsg = 'ArchiveKey does not exist (ispArchiveRDTStdEventLog)'  
      GOTO Fail  
   END  
   SET @cDateType = 3 -- this only event date

   -- Calculate archive date  
   SET @dArchiveDate = DATEADD( DAY, -@nRetainDays, CONVERT( NVARCHAR( 10), GETDATE(), 120))  
  
   -- Validate target db exists  
   IF DB_ID(@cCopyToDB) IS NULL  
   BEGIN  
      SET @n_Err = 60752  
      SET @c_ErrMsg = 'Target database does not exist (ispArchiveRDTStdEventLog)'  
      GOTO Fail  
   END  
  
   -- Log archive starts  
   SET @cAlertMessage = 'Archiving RDTScanToTruck started with parameters' +   
      ': LiveDatabaseName = ' + RTRIM(@cCopyFromDB) +   
      '; ArchiveDatabaseName = ' + RTRIM(@cCopyToDB) +   
      '; CopyRowsToArchive = ' + RTRIM( @cCopyRowsToArchiveDatabase) +   
      '; DateType = ' + RTRIM( @cDateType) +  
      '; NoDaysToRetain = ' +  CAST( @nRetainDays AS NVARCHAR( 10))  
   SET @b_success = 1  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTStdEventLog',  
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
      'rdtSTDEventLog',  
      @b_success OUTPUT,   
      @n_Err OUTPUT,   
      @c_ErrMsg OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
   -- Synchronize both table structure  
   SET @b_success = 1  
   EXECUTE RDT.nspBuildAlterTableString   
      @cCopyToDB,  
      'rdtSTDEventLog',  
      @b_success OUTPUT,  
      @n_Err     OUTPUT,   
      @c_ErrMsg  OUTPUT  
   IF @b_success <> 1 GOTO Fail  
  
  
   -- Candidate RDTScanToTruck.RowRef for archive  
   CREATE TABLE #tRowRef   
   (  
      RowRef INT IDENTITY(1,1) NOT NULL  PRIMARY KEY,   
      EventNum    INT  NOT NULL
   )  
  
   -- Get archiveble records base on rdtSTDEventLog.EventNum  
   INSERT INTO #tRowRef  (EventNum)
   SELECT DISTINCT EventNum  
   FROM RDT.rdtSTDEventLog WITH (NOLOCK)   
   WHERE @dArchiveDate >   
         CASE @cDateType   
             WHEN '3' THEN EventDateTime   
         END  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_Err = 60753  
      SET @c_ErrMsg = 'Insert @tRowRef fail (ispArchiveRDTStdEventLog)'  
      GOTO Fail  
   END  
  
   -- Archivable record in rdtSTDEventLog, base on RowRef  
   CREATE TABLE #tRDTEvent 
   (  
      RowRef INT IDENTITY(1,1) NOT NULL PRIMARY KEY ,
      EventNum INT NOT NULL
   )  
  
   -- Stamp ArchiveCop for rdtSTDEventLog  
   INSERT INTO #tRDTEvent (EventNum)  
   SELECT EL.EventNum  
   FROM RDT.rdtSTDEventLog EL (NOLOCK)  
      INNER JOIN #tRowRef R ON (EL.EventNum = R.EventNum)  
  
   DECLARE @curRDTEvent CURSOR  
   SET @curRDTEvent = CURSOR SCROLL FOR   
      SELECT EventNum FROM #tRDTEvent  
   OPEN @curRDTEvent  
  
   FETCH FIRST FROM @curRDTEvent INTO @nEventNum  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      BEGIN TRAN  
      UPDATE RDT.rdtSTDEventLog WITH (ROWLOCK) SET  
         ArchiveCop = '9'  
      WHERE EventNum = @nEventNum  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Err = 60755  
         SET @c_ErrMsg = 'Stamp ArchiveCop fail (ispArchiveRDTStdEventLog)'  
         GOTO RollBackTran  
      END  
      COMMIT TRAN  
  
      FETCH NEXT FROM @curRDTEvent INTO @nEventNum  
   END  
  
   -- Move and delete archivable records  
   IF @cCopyRowsToArchiveDatabase = 'Y'  
      BEGIN  
         -- Move RDTScanToTruck  
         SET @b_success = 1  
         EXECUTE RDT.nsp_Build_Insert  
            @cCopyToDB,   
            'rdtSTDEventLog', -- @c_tablename  
            1,  
            @b_success OUTPUT,   
            @n_Err     OUTPUT,   
            @c_ErrMsg  OUTPUT  
         IF @b_success <> 1 GOTO Fail  
      END  
   ELSE  
   BEGIN  
      -- Purge RDTScanToTruck  
      FETCH FIRST FROM @curRDTEvent INTO @nEventNum  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         BEGIN TRAN  
         DELETE RDT.rdtSTDEventLog WITH (ROWLOCK)  
         WHERE EventNum = @nEventNum  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Err = 60756  
            SET @c_ErrMsg = 'Delete RDTScanToTruck fail (ispArchiveRDTStdEventLog)'  
            GOTO RollBackTran  
         END  
         COMMIT TRAN  
  
         FETCH NEXT FROM @curRDTEvent INTO @nEventNum  
      END  
   END  
  
   CLOSE @curRDTEvent  
   DEALLOCATE @curRDTEvent  
  
   -- Log end of archive  
   SET @b_success = 1  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTStdEventLog',  
      @c_AlertMessage = 'Archiving RDTEventLog ended successfully',  
      @n_Severity     = 0,  
      @b_success      = @b_success OUTPUT,  
      @n_Err          = @n_Err     OUTPUT,  
      @c_ErrMsg       = @c_ErrMsg  OUTPUT  
      IF @b_success <> 1 GOTO Fail  
  
   RETURN  
  
DROP TABLE  #tRowRef
DROP TABLE #tRDTEvent

RollBackTran:  
   ROLLBACK TRAN  
Fail:  
   -- Get error message  
   IF @c_ErrMsg = '' AND @n_Err <> 0  
      SELECT @c_ErrMsg = description  
      FROM master.dbo.sysmessages  
      WHERE [error] = @n_Err  
     
   -- Log the error  
   SET @cAlertMessage = 'Archiving RDTEventLog failed. ErrNo=' + CAST( @n_Err AS NVARCHAR( 10)) + ' ErrMsg=' + @c_ErrMsg  
   EXECUTE nspLogAlert  
      @c_ModuleName   = 'ispArchiveRDTStdEventLog',  
      @c_AlertMessage = @cAlertMessage,   
      @n_Severity     = 0,  
      @b_success      = 0,  
      @n_Err          = 0,  
      @c_ErrMsg       = ''  
  
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  


GO