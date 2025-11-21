SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store Procedure:  isp_archiveTable2                                  */    
/* Creation Date: 15-Jun-2012                                           */    
/* Copyright: IDS                                                       */    
/* Written by: KHLim                                                    */    
/*                                                                      */    
/* Purpose:  Archive records with ArchiveCop column for more than       */  
/*           by specific condition                                      */    
/*                                                                      */    
/* Input Parameters:  @cSourceDB     - Exceed DB                        */    
/*                    @cArchiveDB    - Archive DB                       */    
/*                    @cTableName    - Main Table                       */    
/*                    @cCondition    - Filter Criteria, etc             */    
/*                    @cPK1          - 1st Primary Key                  */    
/*                    @cPK2          - 2nd Primary Key                  */    
/*                    @cPK3          - 3rd Primary Key                  */  
/*                    @cPK4          - 4th Primary Key                  */  
/*                    @cPK5          - 5th Primary Key                  */  
/*                    @cPKdate       - Primary Key with datetime format */  
/*                                                                      */    
/* Usage: Derive from isp_archiveTable to allow multiple Primary Keys   */    
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
/* 30-Aug-2012  KHLim     add archive_tbl_records & nspLogAlert (KH01)  */  
/* 14-Apr-2017  TLTING    Cater Unicode data filtering                  */
/* 24-Jul-2017  JayLim    Performance tune -reduce cache log (jay01)    */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_archiveTable2]      
    @cSourceDB  nvarchar(128) ,  
    @cArchiveDB nvarchar(128) ,  
    @cTableName nvarchar(128) ,  
    @cCondition nvarchar(4000) ,  
    @cPK1       nvarchar(128) ,  
    @cPK2       nvarchar(128) = '' ,  
    @cPK3       nvarchar(128) = '' ,  
    @cPK4       nvarchar(128) = '' ,  
    @cPK5       nvarchar(128) = '' ,  
    @cPKdate    nvarchar(128) = ''  
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @b_success INT,     
            @n_archive_tbl_records    int, -- # of @cTableName records to be archived     KH01  
            @n_err INT,   
            @c_errmsg CHAR(250),  
            @local_n_err INT,  
            @local_c_errmsg CHAR(250),  
        @c_temp         nvarchar(254), -- KH01  
            @n_cnt INT                
    
   DECLARE  @b_debug INT     
   SELECT   @b_debug = 0  
     
   DECLARE  @n_starttcnt INT , -- Holds the current transaction count  
            @n_continue INT ,     
            @cExecStatements Nvarchar(max), --(jay01)
            @cExecSttmtArg   Nvarchar(max)  --(jay01)
               
   SELECT   @n_starttcnt = @@TRANCOUNT ,     
            @n_continue = 1 ,     
            @b_success = 0 ,     
            @n_err = 0 ,     
            @c_errmsg = '' ,     
            @cExecStatements = ''      
   
   DECLARE @cPKvalue1 nvarchar(30),  
           @cPKvalue2 nvarchar(30),  
           @cPKvalue3 nvarchar(30),  
           @cPKvalue4 nvarchar(30),  
           @cPKvalue5 nvarchar(30),  
           @dPKvalue  datetime     
     
     
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
         print 'building alter table string for ' + @cTableName  
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
  
   select @n_archive_tbl_records = 0   --KH01  
  
     
   SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '    
                           + 'SELECT DISTINCT ' + LTRIM(RTRIM(@cPK1))      
                           + CASE LTRIM(RTRIM(ISNULL(@cPK2   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK2 END                            -- KH01  
                           + CASE LTRIM(RTRIM(ISNULL(@cPK3   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK3 END                            -- KH01  
                           + CASE LTRIM(RTRIM(ISNULL(@cPK4   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK4 END                            -- KH01  
                           + CASE LTRIM(RTRIM(ISNULL(@cPK5   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK5 END                            -- KH01  
                           + CASE LTRIM(RTRIM(ISNULL(@cPKdate,''))) WHEN '' THEN ',''1900-01-01T00:00:00.000'' ' ELSE ', ' + @cPKdate END  -- KH01  
                           + ' FROM ' + LTRIM(RTRIM(@cTableName)) + ' WITH (NOLOCK) '     
                           + ' WHERE ' + @cCondition  
     
   if (@b_debug =1 )  
   begin  
      Print @cExecStatements  
   end  
   EXEC sp_ExecuteSql @cExecStatements      
    
   OPEN C_ITEM    
   FETCH NEXT FROM C_ITEM INTO @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue  
    
   WHILE @@FETCH_STATUS <> -1     
   BEGIN    
       
    IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''  
    BEGIN  
       if (@b_debug =1 )  
       begin  
          print 'building Update ArchiveCop for ' + @cTableName  
       end  
       select @b_success = 1  
         
         SET @cPKvalue1 = ISNULL(RTRIM(@cPKvalue1),'') --(jay01)

         SET @cExecStatements = N'UPDATE ' + LTRIM(RTRIM(@cTableName)) + ' with (ROWLOCK) '      
                              + ' SET ArchiveCop = ''9'' '   
                              + ' WHERE '  + LTRIM(RTRIM(@cPK1)) + ' = @cPKvalue1  '    --(jay01)
         IF @cPKvalue2 <> ''
         BEGIN
         
            SET @cPKvalue2 = ISNULL(RTRIM(@cPKvalue2),'') --(jay01)

            SET @cExecStatements = @cExecStatements     
                                 + ' AND ' + LTRIM(RTRIM(@cPK2)) + ' = @cPKvalue2  '    --(jay01)  
         END     
         IF @cPKvalue3 <> ''
         BEGIN
         
            SET @cPKvalue3 = ISNULL(RTRIM(@cPKvalue3),'') --(jay01)
             
            SET @cExecStatements = @cExecStatements     
                                 + ' AND ' + LTRIM(RTRIM(@cPK3)) + ' = @cPKvalue3 '  --(jay01)     
         END

         IF @cPKvalue4 <> ''
         BEGIN
         
            SET @cPKvalue4 = ISNULL(RTRIM(@cPKvalue4),'') --(jay01)

            SET @cExecStatements = @cExecStatements     
                                 + ' AND ' + LTRIM(RTRIM(@cPK4)) + ' = @cPKvalue4  '    --(jay01)   
         END

         IF @cPKvalue5 <> ''
         BEGIN
         
            SET @cPKvalue5 = ISNULL(RTRIM(@cPKvalue5),'') --(jay01)

            SET @cExecStatements = @cExecStatements     
                                 + ' AND ' + LTRIM(RTRIM(@cPK5)) + ' = @cPKvalue5  '   --(jay01)  
         END

         IF @dPKvalue <> '1900-01-01T00:00:00.000'  
            SET @cExecStatements = @cExecStatements   
        + ' AND ' + LTRIM(RTRIM(@cPKdate)) + ' =  CONVERT(char(23),@dPKvalue,126)  '       
  
       if (@b_debug =1 )  
       begin  
          print @cExecStatements  
       end  
         BEGIN TRAN  

         --(jay01)
         SET @cExecSttmtArg = N'@cPKvalue1 nvarchar(30),  '
                              +'@cPKvalue2 nvarchar(30),  '
                              +'@cPKvalue3 nvarchar(30),  '
                              +'@cPKvalue4 nvarchar(30),  '
                              +'@cPKvalue5 nvarchar(30),  '
                              +'@dPKvalue  datetime       '

         EXEC sp_ExecuteSql @cExecStatements, @cExecSttmtArg, @cPKvalue1 , @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue --(jay01)
                 
         SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
  
         SELECT @n_archive_tbl_records = @n_archive_tbl_records + 1   -- KH01  
  
         IF @local_n_err <> 0    
         BEGIN     
            SELECT @n_continue = 3    
            SELECT @local_n_err = 73702    
            SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)    
            SELECT @local_c_errmsg =    
             ': Update of Archivecop failed - ' + @cTableName + '. (isp_archiveTable2) ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
          ROLLBACK TRAN     
         END   
         ELSE  
         BEGIN  
            COMMIT TRAN   
         END     
      END            
        
        
      FETCH NEXT FROM C_ITEM INTO @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue  
   END -- WHILE @@FETCH_STATUS <> -1     
   CLOSE C_ITEM    
   DEALLOCATE C_ITEM     
  
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''    -- KH01  
 BEGIN  
  select @c_temp = 'attempting to archive ' + convert(varchar(9), @n_archive_tbl_records) +  
                       ' ' + @cTableName + ' records'  
  execute nsplogalert  
   @c_modulename   = 'isp_archiveTable2',  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_archiveTable2'      
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