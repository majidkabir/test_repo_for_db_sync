SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Proc : ispArchiveRDTEventLog                                  */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: THIS ARCHIVE SCRIPT WILL PURGE THE FOLLOWING TABLES:        */  
/*          RDTEventLog & RDTEventLogDetail                             */  
/*                                                                      */  
/* Input Parameters: NONE                                               */  
/*                                                                      */  
/* Output Parameters: NONE                                              */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 29-Jan-2009  James         Created                                   */  
/* 24-Sep-2009  James         Change ARCHIVEPARAMETERS schema from dbo  */  
/*                            to RDT (james01)                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[ispArchiveRDTEventLog]             
      @c_archivekey   NVARCHAR(10)  
   ,  @b_success      int        output      
   ,  @n_err          int        output      
   ,  @c_errmsg       NVARCHAR(250)  output      
AS  
BEGIN -- main  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue INT        ,    
      @n_starttcnt INT        , -- holds the current transaction count  
      @n_cnt INT              , -- holds @@rowcount after certain operations  
      @b_debug INT             -- debug on or off  
          
   /* #include <sparpo1.sql> */       
   DECLARE          
      @n_retain_days INT      , -- days to hold data  
      @nRowRef INT,  
      @nEventLogID INT,  
      @d_result  DATETIME,   
      @c_datetype NVARCHAR(10),   
      @local_n_err INT,  
      @local_c_errmsg  NVARCHAR(254),  
      @c_copyfrom_db NVARCHAR(55),  
      @c_copyto_db   NVARCHAR(55),  
      @c_WhereClause NVARCHAR(2048),  
      @c_temp NVARCHAR(2048),  
      @c_temp1 NVARCHAR(2048),  
      @CopyRowsToArchiveDatabase NVARCHAR(1)  
        
     
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',  
      @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '  
     
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN --1  
      SELECT    
         @c_copyfrom_db = LiveDataBaseName,  
         @c_copyto_db = ArchiveDataBaseName,  
         @n_retain_days = RDT_TABLE_NoDaysToRetain,  
         @c_datetype = RDT_ARCHIVE_DateType,  
         @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase  
      FROM RDT.ARCHIVEPARAMETERS WITH (NOLOCK)  --(james01)  
      WHERE Archivekey = @c_archivekey  
           
      IF db_id(@c_copyto_db) IS NULL  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @local_n_err = 77301  
         SELECT @local_c_errmsg = convert(char(5),@local_n_err)  
         SELECT @local_c_errmsg =  
            ': target database ' + @c_copyto_db + ' does not exist ' + ' ( ' +  
            ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')' + ' (ispArchiveRDTEventLog)'  
      END  
  
      SET @d_result = DATEADD( DAY, -@n_retain_days, CONVERT( NVARCHAR( 10), GETDATE(), 120))  
  
      SELECT @b_success = 1  
      SELECT @c_temp = 'archive of RDTEventLog started with parms; datetype = ' + RTRIM(@c_datetype) +  
         ' ; copy from db = ' + RTRIM(@c_copyfrom_db) +  
         ' ; copy to db = ' + RTRIM(@c_copyto_db) +  
         ' ; copy rows to archive = ' + RTRIM(@CopyRowsToArchiveDatabase) +  
         ' ; retain days = ' + CONVERT(CHAR(6),@n_retain_days)  
     
      EXECUTE dbo.nspLogAlert  
         @c_modulename   = 'ispArchiveRDTEventLog',  
         @c_alertmessage = @c_temp ,  
         @n_severity     = 0,  
         @b_success      = @b_success OUTPUT,  
         @n_err          = @n_err OUTPUT,  
         @c_errmsg       = @c_errmsg OUTPUT  
  
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END   --1  
  
   IF (@n_continue = 1 or @n_continue = 2)  
   BEGIN -- 4  
   
      SELECT @c_WhereClause = ' '  
      SELECT @c_temp = ' '  
      SELECT @c_temp1 = ' '  
  
      -- Create if table exist in archive DB. If not, create it  
      IF ((@n_continue = 1 or @n_continue = 2) and UPPER(@CopyRowsToArchiveDatabase) = 'Y')  
      BEGIN   
         IF (@b_debug =1 )  
         BEGIN  
            PRINT 'starting table existence check for RDTEventLog...'  
         END  
  
         SELECT @b_success = 1  
         EXEC RDT.nsp_build_archive_table--_RDT  
            @c_copyfrom_db,   
            @c_copyto_db,  
            'RDTEventLog',  
            @b_success OUTPUT ,   
            @n_err OUTPUT ,   
            @c_errmsg OUTPUT  
  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END     
        
      IF ((@n_continue = 1 or @n_continue = 2) and UPPER(@CopyRowsToArchiveDatabase) = 'Y')  
      BEGIN    
         IF (@b_debug =1 )  
         BEGIN  
            PRINT 'starting table existence check for RDTEventLogDetail...'  
         END  
  
         SELECT @b_success = 1  
         EXEC RDT.nsp_build_archive_table--_RDT  
            @c_copyfrom_db,   
            @c_copyto_db,   
            'RDTEventLogDetail',  
            @b_success OUTPUT ,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
  
         IF not @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
       
      -- Synchronize both table structure  
      IF ((@n_continue = 1 or @n_continue = 2) and UPPER(@CopyRowsToArchiveDatabase) = 'Y')  
      BEGIN  
         IF (@b_debug =1 )  
         BEGIN  
            PRINT 'building alter table string for RDTEventLog...'  
         END  
  
         SELECT @b_success = 1  
         EXECUTE RDT.nspBuildAlterTableString--_RDT  
            @c_copyto_db,  
            'RDTEventLog',  
            @b_success OUTPUT,  
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
     
      IF ((@n_continue = 1 or @n_continue = 2) and UPPER(@CopyRowsToArchiveDatabase) = 'Y')  
      BEGIN  
         IF (@b_debug =1 )  
         BEGIN  
            PRINT 'building alter table string for RDTEventLogDetail...'  
         END  
  
         EXECUTE RDT.nspBuildAlterTableString--_RDT  
            @c_copyto_db,  
            'RDTEventLogDetail',  
            @b_success OUTPUT,  
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
  
      DECLARE @nStartTranCount int   
      SET @nStartTranCount = @@TRANCOUNT  
  
      WHILE @@TRANCOUNT > 0   
         COMMIT TRAN   
  
      EXEC (  
      ' Declare C_RDTEventLog CURSOR FAST_FORWARD READ_ONLY FOR ' +   
      ' SELECT RowRef FROM RDT.RDTEventLog WITH(NOLOCK) where StartDate  <= ' + ''''+ @d_result +'''' +   
      ' ORDER BY RowRef ' )   
        
     
      OPEN C_RDTEventLog   
        
      FETCH NEXT FROM C_RDTEventLog INTO @nRowRef  
     
      WHILE @@fetch_status <> -1   
      BEGIN  
         BEGIN TRAN   
     
         UPDATE RDT.RDTEventLog WITH (ROWLOCK)  
            SET ArchiveCop = '9'   
         WHERE RowRef = @nRowRef    
           
         SELECT @local_n_err = @@error, @n_cnt = @@rowcount  
         IF @local_n_err <> 0  
         BEGIN   
            SELECT @n_continue = 3  
            SELECT @local_n_err = 77303  
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)  
            SELECT @local_c_errmsg =  
            ': update of archivecop failed - RDTEventLog. (ispArchiveRDTEventLog) ' + ' ( ' +  
            ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'  
            ROLLBACK TRAN   
         END    
         ELSE  
         BEGIN  
            COMMIT TRAN   
         END   
     
         DECLARE C_RDTEventLogDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT RowRef, EventLogID  
         FROM   RDT.RDTEventLogDetail WITH (NOLOCK)   
         WHERE  RowRef = @nRowRef   
         ORDER By RowRef, EventLogID  
           
         OPEN C_RDTEventLogDetail   
           
         FETCH NEXT FROM C_RDTEventLogDetail INTO @nRowRef, @nEventLogID  
           
         WHILE @@FETCH_STATUS <> -1    
         BEGIN   
            BEGIN TRAN   
     
            UPDATE RDT.RDTEventLogDetail WITH (ROWLOCK)   
               SET Archivecop = '9'  
            WHERE RowRef = @nRowRef AND EventLogID = @nEventLogID   
     
            SELECT @local_n_err = @@error   
            IF @local_n_err <> 0  
            BEGIN   
               SELECT @n_continue = 3  
               SELECT @local_n_err = 77303  
               SELECT @local_c_errmsg = convert(char(5),@local_n_err)  
               SELECT @local_c_errmsg =  
               ': update of archivecop failed - RDTEventLogDetail. (ispArchiveRDTEventLog) ' + ' ( ' +  
               ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'  
               ROLLBACK TRAN   
            END    
            ELSE  
            BEGIN  
               COMMIT TRAN   
            END     
     
            FETCH NEXT FROM C_RDTEventLogDetail INTO @nRowRef, @nEventLogID  
         END -- While C_RDTEventLogDetail   
         CLOSE C_RDTEventLogDetail  
         DEALLOCATE C_RDTEventLogDetail   
           
         IF @n_continue = 3   
         BEGIN  
            IF @@TRANCOUNT > 0  
               ROLLBACK TRAN  
         END   
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0  
            BEGIN   
               COMMIT TRAN   
            END   
         END   
         FETCH NEXT FROM C_RDTEventLog INTO @nRowRef  
      END -- while C_RDTEventLog   
      CLOSE C_RDTEventLog  
      DEALLOCATE C_RDTEventLog   
  
      IF ((@n_continue = 1 or @n_continue = 2) and UPPER(@CopyRowsToArchiveDatabase) = 'Y')  
      BEGIN   
       IF (@b_debug =1 )  
         BEGIN  
            PRINT 'building insert for RDTEventLogDetail...'  
         END  
  
         SELECT @b_success = 1  
         EXEC RDT.nsp_Build_Insert--_RDT    
            @c_copyto_db,   
            'RDTEventLogDetail',  
            1 ,  
            @b_success OUTPUT,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END     
  
      if ((@n_continue = 1 or @n_continue = 2) and UPPER(@CopyRowsToArchiveDatabase) = 'Y')  
      BEGIN     
         IF (@b_debug =1 )  
         BEGIN  
            PRINT 'building insert for RDTEventLog...'  
         END  
  
         SELECT @b_success = 1  
         EXEC RDT.nsp_Build_Insert--_RDT   
            @c_copyto_db,   
            'RDTEventLog',  
            1,  
            @b_success OUTPUT ,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END     
   END -- 4  
     
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @b_success = 1  
      EXECUTE dbo.nspLogAlert  
         @c_modulename   = 'ispArchiveRDTEventLog',  
         @c_alertmessage = 'archive of RDTEventLogDetail ended normally.',  
         @n_severity     = 0,  
         @b_success      = @b_success OUTPUT,  
         @n_err          = @n_err OUTPUT,  
         @c_errmsg       = @c_errmsg OUTPUT  
  
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END  
   ELSE  
   BEGIN  
      IF @n_continue = 3  
      BEGIN  
         SELECT @b_success = 1  
         EXECUTE dbo.nspLogAlert  
            @c_modulename   = 'ispArchiveRDTEventLog',  
            @c_alertmessage = 'archive of RDTEventLog ended abnormally - check this log for additional messages.',  
            @n_severity     = 0,  
            @b_success      = @b_success OUTPUT ,  
            @n_err          = @n_err OUTPUT,  
            @c_errmsg       = @c_errmsg OUTPUT  
  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
   END  
  
          
   /* #include <sparpo2.sql> */       
   IF @n_continue=3  -- error occured - process and return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > 0  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            commit tran  
         END  
      END  
     
      SELECT @n_err = @local_n_err  
      SELECT @c_errmsg = @local_c_errmsg  
      IF (@b_debug = 1)  
      BEGIN  
         SELECT @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'  
      END  
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ispArchiveRDTEventLog'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      while @@trancount > 0  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
  
END -- main  


GO