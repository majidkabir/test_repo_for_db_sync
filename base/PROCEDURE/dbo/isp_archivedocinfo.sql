SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/        
/* Store Procedure:  isp_archiveDocInfo                                                */        
/* Creation Date: 29-March-2016                                                        */        
/* Copyright: IDS                                                                      */        
/* Written by: JayLim                                                                  */        
/*                                                                                     */        
/* Purpose:  Archive records with ArchiveCop column for records that                   */      
/*           doesnt exist anymore in the stated table name                             */        
/*                                                                                     */        
/* Input Parameters:  @cSourceDB     - Exceed DB                                       */        
/*                    @cArchiveDB    - Archive DB                                      */          
/*                                                                                     */        
/* Usage:  Archive older records which does not exist in the TableName                 */       
/*         stated                                                                      */       
/*                                                                                     */        
/* Called By:  Set under Scheduler Jobs.                                               */        
/*                                                                                     */        
/* PVCS Version: 1.0                                                                   */        
/*                                                                                     */        
/* Version: 5.4                                                                        */        
/*                                                                                     */        
/* Data Modifications:                                                                 */        
/*                                                                                     */        
/* Updates:                                                                            */        
/* Date         Author        Purposes                                                 */        
/* 02 May 2017  TLTING        Bug fix - if new tabename added                          */     
/* 2023-02-28   kelvinongcy   JSM-114109 Bug of DoxInfo still archive even             */    
/*                            Orders & OrderDetail exist in WMS. Try prevent           */     
/*                            with add date not more than 1 hrs (kocy01)               */    
/*2023-05-30    kelvinongcy   archive DocInfo.Tablename = RECEIPT for CN NKE (kocy02)  */ 
/*2023-05-30    kelvinongcy   enchance fix break that stop all next process (kocy03)   */
/***************************************************************************************/     
    
CREATE    PROC [dbo].[isp_archiveDocInfo]      
(          
    @cSourceDB       NVARCHAR(128),      
    @cArchiveDB      NVARCHAR(128)              
)      
AS        
BEGIN        
   SET NOCOUNT ON         
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF         
   SET CONCAT_NULL_YIELDS_NULL OFF        
      
      
   DECLARE  @cTableName                NVARCHAR(128) ,      
            @cDocInfoTableName         NVARCHAR(128) ,            
            @cKeyName                  NVARCHAR(128)      
         
   DECLARE  @tDocInfoTable TABLE (      
            ID INT IDENTITY,      
            Tablename   NVARCHAR(128)      
            )            
      
   DECLARE  @b_success                 INT,         
            @n_archive_tbl_records     INT,      
            @n_err                     INT,       
            @c_errmsg                  NVARCHAR(250),      
            @local_n_err               INT,      
            @local_c_errmsg            NVARCHAR(250),      
            @c_temp       NVARCHAR(254),      
            @n_archive_table_records   INT,                  
            @n_cnt                     INT                    
        
   DECLARE  @b_debug                   INT         
   SELECT   @b_debug = 0      
           
   DECLARE  @n_starttcnt               INT , -- Holds the current transaction count          
            @n_continue                INT ,         
            @cExecStatements           NVARCHAR(2000)          
   SELECT   @n_starttcnt = @@TRANCOUNT ,         
            @n_continue = 1 ,         
            @b_success = 0 ,         
            @n_err = 0 ,         
            @c_errmsg = '' ,         
            @cExecStatements = ''          
       
   DECLARE @c_KeyValue                 NVARCHAR(30),       
           @c_SQLWhere                 NVARCHAR(2000),      
           @c_KeyColumn                NVARCHAR(50)      
         
   SET @cTableName   = 'DocInfo'      
   SET @cKeyName     = 'RecordID'      
   SET @n_archive_tbl_records = 0       
         
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
         print 'building alter table string for '+@cTableName        
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
  
         
   IF (@n_continue=1 OR @n_continue=2)      
   BEGIN   
       
   DECLARE TableName_Item CURSOR FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT DocInfo.TableName FROM DocInfo with (NOLOCK)      
      
   OPEN TableName_Item      
      
   FETCH NEXT FROM TableName_Item INTO @cDocInfoTableName      
      
   WHILE @@FETCH_STATUS <> -1             
   BEGIN     
         
      if (@b_debug =1 )      
      begin      
         Print @cDocInfoTableName      
      end      
                  
      IF (@n_continue = 1 OR @n_continue = 2) AND (LTRIM(RTRIM(@cDocInfoTableName)) = 'Orders')      
      BEGIN      
         SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '        
                                 + 'SELECT  ' + LTRIM(RTRIM(@cTableName)) + '.'+ LTRIM(RTRIM(@cKeyName))        
                                 + ' FROM ' + LTRIM(RTRIM(@cTableName)) +' WITH (NOLOCK) '      
                                 + ' WHERE ' + LTRIM(RTRIM(@cTableName))+'.TableName ='''+LTRIM(RTRIM(@cDocInfoTableName))+''''     
                                 + ' AND ' + LTRIM(RTRIM(@cTableName))+'.AddDate < dateadd(hour, -1, getdate() ) '         --kocy01    
                                 + ' AND NOT EXISTS'      
                                 + '( SELECT 1'      
                                 + ' FROM ORDERS WITH (NOLOCK)'      
                                 + ' WHERE '+ LTRIM(RTRIM(@cTableName))+'.key1 = '+LTRIM(RTRIM(@cDocInfoTableName))+'.orderkey)'      
      END      
      ELSE IF (@n_continue = 1 OR @n_continue = 2) AND (LTRIM(RTRIM(@cDocInfoTableName)) = 'ORDERDETAIL')      
      BEGIN      
         SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '        
                                 + 'SELECT ' + LTRIM(RTRIM(@cTableName)) + '.'+ LTRIM(RTRIM(@cKeyName))          
                                 + ' FROM ' + LTRIM(RTRIM(@cTableName)) +' WITH (NOLOCK)'      
                                 + ' WHERE ' + LTRIM(RTRIM(@cTableName))+'.TableName ='''+LTRIM(RTRIM(@cDocInfoTableName))+''''    
                                 + ' AND ' + LTRIM(RTRIM(@cTableName))+'.AddDate < dateadd(hour, -1, getdate() ) '         --kocy01    
                                 + ' AND NOT EXISTS'      
                                 + ' (SELECT 1'      
                                 + ' FROM ORDERDETAIL WITH (NOLOCK)'      
                                 + ' WHERE '+ LTRIM(RTRIM(@cTableName))+'.key1 = '+LTRIM(RTRIM(@cDocInfoTableName))+'.orderkey'      
                                 + ' AND '+ LTRIM(RTRIM(@cTableName))+'.key2 = '+LTRIM(RTRIM(@cDocInfoTableName))+'.orderlinenumber)'      
            
      END   
      ELSE IF (@n_continue = 1 OR @n_continue = 2) AND (LTRIM(RTRIM(@cDocInfoTableName)) = 'RECEIPT')                         -- kocy02 (s)
      BEGIN   
         SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '        
                                 + 'SELECT  ' + LTRIM(RTRIM(@cTableName)) + '.'+ LTRIM(RTRIM(@cKeyName))        
                                 + ' FROM ' + LTRIM(RTRIM(@cTableName)) +' WITH (NOLOCK) '      
                                 + ' WHERE ' + LTRIM(RTRIM(@cTableName))+'.TableName ='''+LTRIM(RTRIM(@cDocInfoTableName))+''''   
                                 + ' AND ' + LTRIM(RTRIM(@cTableName))+'.Key2 = ''TRACKINGNO'' '  
                                 + ' AND ' + LTRIM(RTRIM(@cTableName))+'.AddDate < dateadd(dd, -365, getdate() ) '            -- kocy02 (e)
              
      END  
      ELSE      
      BEGIN      
         SET @cExecStatements = 'SELECT ''ExecStatement not exists for DocInfo.TableName = '+LTRIM(RTRIM(@cDocInfoTableName))+''''      
         --BREAK   --kocy03 (S)
         GOTO NEXT_STEP
      END      
      EXEC sp_ExecuteSql @cExecStatements       
  
      if (@b_debug =1 )      
      begin      
         Print @cExecStatements      
      end         
        
      OPEN C_ITEM        
      FETCH NEXT FROM C_ITEM INTO @c_KeyValue         
        
      WHILE @@FETCH_STATUS <> -1         
      BEGIN        
         IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''      
         BEGIN      
            if (@b_debug =1 )      
            begin      
                 print @c_SQLWhere      
               print 'building Update ArchiveCop for ' + @cTableName      
            end      
            select @b_success = 1      
           
              SET @cExecStatements = N'UPDATE ' + LTRIM(RTRIM(@cTableName)) + ' with (ROWLOCK) '          
                                   + ' SET ArchiveCop = ''9'' '       
                                   + ' WHERE ' +  LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName))       
                                   + ' = N''' + RTRIM(@c_KeyValue) + ''' '           
              BEGIN TRAN      
              EXEC sp_ExecuteSql @cExecStatements               
              SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
      
              SELECT @n_archive_tbl_records = @n_archive_tbl_records + 1   -- KHLim03      
      
              IF @local_n_err <> 0        
              BEGIN         
               SELECT @n_continue = 3        
               SELECT @local_n_err = 73702        
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)        
               SELECT @local_c_errmsg =        
                  ': Update of Archivecop failed - ' + @cTableName + '. (isp_archiveDocInfo) ( ' +        
                  ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'        
               ROLLBACK TRAN         
              END       
              ELSE      
              BEGIN      
                 COMMIT TRAN       
              END         
           END                
                           
           FETCH NEXT FROM C_ITEM INTO @c_KeyValue          
         END -- WHILE @@FETCH_STATUS <> -1         
         CLOSE C_ITEM        
         DEALLOCATE C_ITEM       
      
    NEXT_STEP:  --kocy03 (S)

   FETCH NEXT FROM TableName_Item INTO @cDocInfoTableName       
   END -- WHILE @@FETCH_STATUS <> -1         
                  
   CLOSE TableName_Item      
   DEALLOCATE TableName_Item      
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
              @c_modulename   = 'isp_archiveDocInfo',      
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
                 @c_modulename   = 'isp_archiveDocInfo',      
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_archiveDocInfo'          
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN          
   END          
   ELSE          
   BEGIN          
      SELECT @b_success = 1          
      WHILE @@TRANCOUNT > @n_starttcnt          
      BEGIN            
         COMMIT TRAN          
      END          
      RETURN          
   END      
      
END -- procedure        

GO