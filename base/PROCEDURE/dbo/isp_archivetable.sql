SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store Procedure:  isp_archiveTable                                   */    
/* Creation Date: 18-Aug-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: TLTING                                                   */    
/*                                                                      */    
/* Purpose:  Archive records with ArchiveCop column for more than       */  
/*           by specific condition                                      */    
/*                                                                      */    
/* Input Parameters:  @cSourceDB     - Exceed DB                        */    
/*                    @cArchiveDB    - Archive DB                       */    
/*                    @cTableName    - Main Table                       */    
/*                    @cTableName1   - 1st Table to process             */    
/*                    @cTableName2   - 2nd Table to process             */    
/*                    @cKeyName      - Main Table Key (eg.Pickheaderkey)*/    
/*                    @cKey1         - 1st Table Key (eg.PickSlipNo)    */    
/*                    @cKey2         - 2nd Table Key (eg.PickSlipNo)    */    
/*                    @cCondition    - Filter Criteria/etc              */    
/*                                                                      */    
/* Usage:  Archive older records with the same batch of tables into the */    
/*         Archive DB at one time. Maximum two (2) tables at one time.  */    
/*                                                                      */    
/* Called By:  Set under Scheduler Jobs.                                */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */    
/* 09-Nov-2010  TLTING  1.1   Commit at line level                      */  
/* 02-Sep-2011  KHLim01 1.2   Increase storage size of Table Name,      */  
/*                            Key Name & DB name                        */  
/* 15-Jun-2012  KHLim02 1.3   Increase @c_KeyValue length from 15 to 30 */  
/* 24-Jul-2012  KHLim03 1.4   add archive_tbl_records & nspLogAlert     */  
/* 24-Jul-2017  JayLim  1.5   Performance Tune - reduce cache log(jay01)*/      
/* 23-JUL-2019  TLTING  1.6   cater inMemory table - remove rowlock     */    
/*                            Sync version WMS and dtsitf               */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_archiveTable]      
    @cSourceDB NVARCHAR(128) ,    -- KHLim01  
    @cArchiveDB NVARCHAR(128) ,   -- KHLim01  
    @cTableName NVARCHAR(128) ,   -- KHLim01  
    @cTableName1 NVARCHAR(128) ,  -- KHLim01  
    @cTableName2 NVARCHAR(128) ,  -- KHLim01  
    @cTableName3 NVARCHAR(128) ,  -- KHLim01  
    @cKeyName NVARCHAR(128) ,     -- KHLim01  
    @cKeyName1 NVARCHAR(128) ,    -- KHLim01  
    @cKeyName2 NVARCHAR(128) ,    -- KHLim01  
    @cKeyName3 NVARCHAR(128) ,    -- KHLim01  
    @cCondition NVARCHAR(4000)   
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @b_success INT,     
            @n_archive_tbl_records    int, -- # of @cTableName records to be archived     KHLim03  
            @n_archive_tbl1_records   int, -- # of @cTableName1 records to be archived     KHLim03  
            @n_archive_tbl2_records   int, -- # of @cTableName2 records to be archived     KHLim03  
            @n_archive_tbl3_records   int, -- # of @cTableName3 records to be archived     KHLim03  
            @n_err INT,   
            @c_errmsg NVARCHAR(250),  
            @local_n_err INT,  
            @local_c_errmsg NVARCHAR(250),  
        @c_temp         NVARCHAR(254), -- KHLim03  
            @n_archive_table_records INT,              
            @n_archive_table1_records INT,  
            @n_archive_table2_records INT,    
            @n_archive_table3_records INT,  
            @n_cnt INT                
    
   DECLARE  @b_debug INT     
   SELECT   @b_debug = 0     
   DECLARE  @n_starttcnt INT , -- Holds the current transaction count      
            @n_continue INT ,     
            @cExecStatements NVARCHAR(max), --(Jay01)  
            @cExecStmtArg    NVARCHAR(max)  --(Jay01)  
                  
   SELECT   @n_starttcnt = @@TRANCOUNT ,     
            @n_continue = 1 ,     
            @b_success = 0 ,     
            @n_err = 0 ,     
            @c_errmsg = '' ,     
            @cExecStatements = ''      
   
   DECLARE @c_KeyValue NVARCHAR(30), -- KHLim02  
           @c_SQLWhere NVARCHAR(2000),  
           @c_KeyColumn NVARCHAR(50)  
     
     
     
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''  
   BEGIN      
      select @b_success = 1    
      EXEC nsp_BUILD_ARCHIVE_TABLE     
      @cSourceDB,     
      @cArchiveDB,     
      @cTableName,    
      @b_success OUTPUT,     
      @n_err OUTPUT,     
      @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END    
      IF (@b_debug = 1)    
      BEGIN    
         print 'building alter table string for @cTableName...'    
      END    
      EXECUTE nspBuildAlterTableString     
         @cArchiveDB,    
         @cTableName,    
         @b_success OUTPUT,    
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END          
   END  
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName1, '') <> ''  
   BEGIN   
      SET @cTableName1 = LTRIM(RTRIM(@cTableName1))     
      select @b_success = 1    
      EXEC nsp_BUILD_ARCHIVE_TABLE     
      @cSourceDB,     
      @cArchiveDB,     
      @cTableName1,    
      @b_success OUTPUT,     
      @n_err OUTPUT,     
      @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END    
      EXECUTE nspBuildAlterTableString     
         @cArchiveDB,    
         @cTableName1,    
         @b_success OUTPUT,    
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END         
   END     
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName2, '') <> ''  
   BEGIN     
      SET @cTableName2 = LTRIM(RTRIM(@cTableName2))   
      select @b_success = 1    
      EXEC nsp_BUILD_ARCHIVE_TABLE     
      @cSourceDB,     
      @cArchiveDB,     
      @cTableName2,    
      @b_success OUTPUT,     
      @n_err OUTPUT,     
      @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END    
      EXECUTE nspBuildAlterTableString     
         @cArchiveDB,    
         @cTableName2,    
         @b_success OUTPUT,    
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END         
   END   
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName3, '') <> ''  
   BEGIN      
      SET @cTableName3 = LTRIM(RTRIM(@cTableName3))  
      select @b_success = 1    
      EXEC nsp_BUILD_ARCHIVE_TABLE     
      @cSourceDB,     
      @cArchiveDB,     
      @cTableName3,    
      @b_success OUTPUT,     
      @n_err OUTPUT,     
      @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END    
      EXECUTE nspBuildAlterTableString     
         @cArchiveDB,    
         @cTableName3,    
         @b_success OUTPUT,    
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END         
   END          
    
   select @n_archive_tbl_records = 0   
   select @n_archive_tbl1_records = 0   
   select @n_archive_tbl2_records = 0   
   select @n_archive_tbl3_records = 0   
  
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName1, '') <> ''  
   BEGIN  
   
      SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '    
                              + 'SELECT DISTINCT ' + LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName))      
                              + ' FROM ' + LTRIM(RTRIM(@cTableName))     
                              + ' WITH (NOLOCK) '     
                              + ' JOIN ' + LTRIM(RTRIM(@cTableName1)) + ' WITH (NOLOCK) on '   
                              + LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName)) + ' = '  
                              + LTRIM(RTRIM(@cTableName1)) + '.' + LTRIM(RTRIM(@cKeyName1))  
                              + ' WHERE ' + @cCondition  
   END  
   ELSE  
   BEGIN  
      SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '    
                              + 'SELECT DISTINCT ' + LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName))      
                              + ' FROM ' + LTRIM(RTRIM(@cTableName)) + ' WITH (NOLOCK) '     
                              + ' WHERE ' + @cCondition        
        
   END   
      if (@b_debug =1 )  
      begin  
         Print @cExecStatements  
      end  
   EXEC sp_ExecuteSql @cExecStatements      
    
   OPEN C_ITEM    
   FETCH NEXT FROM C_ITEM INTO @c_KeyValue     
    
   WHILE @@FETCH_STATUS <> -1     
   BEGIN    
       
    IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName1, '') <> ''  
    BEGIN  
       if (@b_debug =1 )  
       begin  
            print @c_SQLWhere  
          print 'building Update ArchiveCop for ' + @cTableName1  
       end  
       select @b_success = 1  
     
         SET @cExecStatements = N'UPDATE ' + LTRIM(RTRIM(@cTableName1)) + '  '      
                              + ' SET ArchiveCop = ''9'' '   
                              + ' WHERE ' +  LTRIM(RTRIM(@cTableName1)) + '.' + LTRIM(RTRIM(@cKeyName1))   
                              + ' = RTRIM(@c_KeyValue) '    --(jay01)  
         BEGIN TRAN  
           
         SET @cExecStmtArg = N'@c_KeyValue NVARCHAR(30) ' --(jay01)  
                                 
         EXEC sp_ExecuteSql @cExecStatements, @cExecStmtArg, @c_KeyValue --(jay01)    
         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
  
         SELECT @n_archive_tbl1_records = @n_archive_tbl1_records + 1   -- KHLim03  
  
         IF @local_n_err <> 0    
         BEGIN     
          SELECT @n_continue = 3    
          SELECT @local_n_err = 73702    
          SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    
          SELECT @local_c_errmsg =    
             ': Update of Archivecop failed - ' + @cTableName1 + '. (isp_archiveTable) ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
          ROLLBACK TRAN     
         END    
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END    
      END  
  
    IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName2, '') <> ''  
    BEGIN  
       if (@b_debug =1 )  
       begin  
            print @c_SQLWhere  
          print 'building Update ArchiveCop for ' + @cTableName2  
       end  
       select @b_success = 1  
     
         SET @cExecStatements = N'UPDATE ' + LTRIM(RTRIM(@cTableName2)) + '   '      
                              + ' SET ArchiveCop = ''9'' '   
                              + ' WHERE ' +  LTRIM(RTRIM(@cTableName2)) + '.' + LTRIM(RTRIM(@cKeyName2))   
                              + ' =  RTRIM(@c_KeyValue)  '   --(jay01)  
       BEGIN TRAN  
           
         SET @cExecStmtArg = N'@c_KeyValue NVARCHAR(30) ' --(jay01)  
                                 
         EXEC sp_ExecuteSql @cExecStatements, @cExecStmtArg, @c_KeyValue --(jay01)   
                  
         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
  
         SELECT @n_archive_tbl2_records = @n_archive_tbl2_records + 1   -- KHLim03  
  
         IF @local_n_err <> 0    
         BEGIN     
          SELECT @n_continue = 3    
          SELECT @local_n_err = 73702    
          SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    
          SELECT @local_c_errmsg =    
             ': Update of Archivecop failed - ' + @cTableName2 + '. (isp_archiveTable) ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
          ROLLBACK TRAN     
         END     
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END   
      END        
  
    IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName3, '') <> ''  
    BEGIN  
       if (@b_debug =1 )  
       begin  
            print @c_SQLWhere  
          print 'building Update ArchiveCop for ' + @cTableName3  
       end  
       select @b_success = 1  
     
         SET @cExecStatements = N'UPDATE ' + LTRIM(RTRIM(@cTableName3)) + '   '      
                              + ' SET ArchiveCop = ''9'' '   
                              + ' WHERE ' +  LTRIM(RTRIM(@cTableName3)) + '.' + LTRIM(RTRIM(@cKeyName3))   
                              + ' =  RTRIM(@c_KeyValue)  ' --(jay01)  
         BEGIN TRAN   
                                   
         SET @cExecStmtArg = N'@c_KeyValue NVARCHAR(30) ' --(jay01)  
                                 
         EXEC sp_ExecuteSql @cExecStatements, @cExecStmtArg, @c_KeyValue --(jay01)   
                  
         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
  
         SELECT @n_archive_tbl3_records = @n_archive_tbl3_records + 1   -- KHLim03  
  
         IF @local_n_err <> 0    
         BEGIN     
          SELECT @n_continue = 3    
          SELECT @local_n_err = 73702    
          SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    
          SELECT @local_c_errmsg =    
             ': Update of Archivecop failed - ' + @cTableName3 + '. (isp_archiveTable) ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
          ROLLBACK TRAN     
         END      
         ELSE  
         BEGIN  
            COMMIT TRAN   
         END  
      END    
    IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''  
    BEGIN  
       if (@b_debug =1 )  
       begin  
            print @c_SQLWhere  
          print 'building Update ArchiveCop for ' + @cTableName  
       end  
       select @b_success = 1  
     
         SET @cExecStatements = N'UPDATE ' + LTRIM(RTRIM(@cTableName)) + '   '      
                              + ' SET ArchiveCop = ''9'' '   
                              + ' WHERE ' +  LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName))   
                              + ' =  RTRIM(@c_KeyValue)  '  --(jay01)     
         BEGIN TRAN  
  
         SET @cExecStmtArg = N'@c_KeyValue NVARCHAR(30) ' --(jay01)  
                                 
         EXEC sp_ExecuteSql @cExecStatements, @cExecStmtArg, @c_KeyValue --(jay01)  
                   
         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
  
         SELECT @n_archive_tbl_records = @n_archive_tbl_records + 1   -- KHLim03  
  
         IF @local_n_err <> 0    
         BEGIN     
          SELECT @n_continue = 3    
          SELECT @local_n_err = 73702    
          SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    
          SELECT @local_c_errmsg =    
             ': Update of Archivecop failed - ' + @cTableName + '. (isp_archiveTable) ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
          ROLLBACK TRAN     
         END   
         ELSE  
         BEGIN              COMMIT TRAN   
         END     
      END            
        
        
      FETCH NEXT FROM C_ITEM INTO @c_KeyValue     
   END -- WHILE @@FETCH_STATUS <> -1     
   CLOSE C_ITEM    
   DEALLOCATE C_ITEM     
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName1, '') <> ''    -- KHLim03  
 BEGIN  
  select @c_temp = 'attempting to archive ' + convert(varchar(9), @n_archive_tbl1_records) +  
                       ' ' + @cTableName1 + ' records'  
  execute nsplogalert  
   @c_modulename   = 'isp_archiveTable',  
   @c_alertmessage = @c_temp ,  
   @n_severity     = 0,  
   @b_success       = @b_success output,  
   @n_err          = @n_err output,  
   @c_errmsg       = @c_errmsg output  
  if not @b_success = 1  
  begin  
   select @n_continue = 3  
  end  
   END  
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName1, '') <> ''  
 BEGIN  
      if (@b_debug =1 )  
      begin  
         print @c_SQLWhere  
         print 'building insert for ' + @cTableName1  
      end  
      select @b_success = 1  
      EXEC nsp_BUILD_INSERT      
         @cArchiveDB,     
         @cTableName1,    
         1,    
         @b_success OUTPUT,     
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      if not @b_success = 1  
      begin  
         select @n_continue = 3  
      end  
   END  
     
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName2, '') <> ''    -- KHLim03  
 BEGIN  
  select @c_temp = 'attempting to archive ' + convert(varchar(9), @n_archive_tbl2_records) +  
                       ' ' + @cTableName2 + ' records'  
  execute nsplogalert  
   @c_modulename   = 'isp_archiveTable',  
   @c_alertmessage = @c_temp ,  
   @n_severity     = 0,  
   @b_success       = @b_success output,  
   @n_err          = @n_err output,  
   @c_errmsg       = @c_errmsg output  
  if not @b_success = 1  
  begin  
   select @n_continue = 3  
  end  
   END  
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName2, '') <> ''  
 BEGIN  
      if (@b_debug =1 )  
      begin  
         print @c_SQLWhere  
         print 'building insert for ' + @cTableName2  
      end  
      select @b_success = 1  
      EXEC nsp_BUILD_INSERT      
         @cArchiveDB,     
         @cTableName2,    
         1,    
         @b_success OUTPUT,     
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      if not @b_success = 1  
      begin  
         select @n_continue = 3  
      end  
   END  
  
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName3, '') <> ''    -- KHLim03  
 BEGIN  
  select @c_temp = 'attempting to archive ' + convert(varchar(9), @n_archive_tbl3_records) +  
                       ' ' + @cTableName3 + ' records'  
  execute nsplogalert  
   @c_modulename   = 'isp_archiveTable',  
   @c_alertmessage = @c_temp ,  
   @n_severity     = 0,  
   @b_success       = @b_success output,  
   @n_err          = @n_err output,  
   @c_errmsg       = @c_errmsg output  
  if not @b_success = 1  
  begin  
   select @n_continue = 3  
  end  
   END  
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName3, '') <> ''  
 BEGIN  
      if (@b_debug =1 )  
      begin  
         print @c_SQLWhere  
         print 'building insert for ' + @cTableName3  
      end  
      select @b_success = 1  
      EXEC nsp_BUILD_INSERT      
         @cArchiveDB,     
         @cTableName3,    
         1,    
         @b_success OUTPUT,     
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      if not @b_success = 1  
      begin  
         select @n_continue = 3  
      end  
   END  
  
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''    -- KHLim03  
 BEGIN  
  select @c_temp = 'attempting to archive ' + convert(varchar(9), @n_archive_tbl_records) +  
                       ' ' + @cTableName + ' records'  
  execute nsplogalert  
   @c_modulename   = 'isp_archiveTable',  
   @c_alertmessage = @c_temp ,  
   @n_severity     = 0,  
   @b_success       = @b_success output,  
   @n_err          = @n_err output,  
   @c_errmsg       = @c_errmsg output  
  if not @b_success = 1  
  begin  
   select @n_continue = 3  
  end  
   END  
  
 IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''  
 BEGIN  
      if (@b_debug =1 )  
      begin  
         print @c_SQLWhere  
         print 'building insert for ' + @cTableName  
      end  
      select @b_success = 1  
      EXEC nsp_BUILD_INSERT      
         @cArchiveDB,     
         @cTableName,    
         1,    
         @b_success OUTPUT,     
         @n_err OUTPUT,     
         @c_errmsg OUTPUT    
      if not @b_success = 1  
      begin  
         select @n_continue = 3  
      end  
   END   
  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
  select @b_success = 1  
  execute nsplogalert  
   @c_modulename   = 'isp_archiveTable',  
   @c_alertmessage = 'archive of table(s) ended successfully.',  
   @n_severity     = 0,  
   @b_success       = @b_success output,  
   @n_err          = @n_err output,  
   @c_errmsg       = @c_errmsg output  
  if not @b_success = 1  
  begin  
   select @n_continue = 3  
  end  
   END   
 ELSE  
 BEGIN  
  if @n_continue = 3  
  begin  
   select @b_success = 1  
   execute nsplogalert  
    @c_modulename   = 'isp_archiveTable',  
    @c_alertmessage = 'archive of table(s) failed - check this log for additional messages.',  
    @n_severity     = 0,  
    @b_success       = @b_success output ,  
    @n_err          = @n_err output,  
    @c_errmsg       = @c_errmsg output  
   if not @b_success = 1  
   begin  
    select @n_continue = 3  
   end  
  end  
   END   
  
  
   /* #INCLUDE <SPTPA01_2.SQL> */      
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_starttcnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_archiveTable'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      WHILE @@TRANCOUNT > @n_starttcnt      
      BEGIN            COMMIT TRAN      
      END      
      RETURN      
   END      
END -- procedure    
  

GO