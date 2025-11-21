SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 2012-Oct-03  KHLim         Increase storage size & replace xtype     */  
/* 2014-Feb-10  TLTING        cater Nvarchar(4000) size                 */
  
CREATE PROCEDURE [RDT].[nspBuildAlterTableString]  
@c_copyto_db    NVARCHAR(50)       
,              @c_tablename    NVARCHAR(50)       
,              @b_Success      int        OUTPUT      
,              @n_err          int        OUTPUT      
,              @c_errmsg       NVARCHAR(250)  OUTPUT      
AS  
BEGIN   
 SET NOCOUNT ON  
 DECLARE        @n_continue int        ,    
  @n_starttcnt int        , -- Holds the current transaction count  
  @n_cnt int              , -- Holds @@ROWCOUNT after certain operations  
  @b_debug int              -- Debug On Or Off  
   
 DECLARE @n_rowcount          integer           
 DECLARE @n_nextrow           integer           
 DECLARE @c_msg               NVARCHAR(255)      
 DECLARE @c_field             NVARCHAR(50)       
 DECLARE @c_buildfieldstring  NVARCHAR(255)      
 DECLARE @c_firsttime         NVARCHAR(1)           
 DECLARE @n_messageno         int               
 DECLARE @c_comma             NVARCHAR(1)           
 DECLARE @c_parenset          NVARCHAR(1)           
 DECLARE @n_length            int          --KH01  
 DECLARE @c_typename          NVARCHAR(32)       
 DECLARE @c_exist             NVARCHAR(255)      
 DECLARE @c_exist1            NVARCHAR(255)  
 DECLARE @c_whereclause       NVARCHAR(25)       
 DECLARE        @c_inclen      NVARCHAR(25)  
 DECLARE        @n_status      tinyint                        
 DECLARE        @n_prec        int                          
 DECLARE        @n_scale       int                          
 DECLARE        @user_type     smallint         
 DECLARE        @n_inclen_flag int  
   
 SET NOCOUNT ON  
  
  
   CREATE TABLE [#spt_datatype_info] (  
    [TYPE_NAME] [sysname] NOT NULL ,  
    [DATA_TYPE] [smallint] NOT NULL ,  
    [PRECISION] [int] NULL ,  
    [LITERAL_PREFIX] [varchar] (32)  NULL ,  
    [LITERAL_SUFFIX] [varchar] (32)  NULL ,  
    [CREATE_PARAMS] [varchar] (32)   NULL ,  
    [NULLABLE] [smallint] NOT NULL ,  
    [CASE_SENSITIVE] [smallint] NOT NULL ,  
    [SEARCHABLE] [smallint] NOT NULL ,  
    [UNSIGNED_ATTRIBUTE] [smallint] NULL ,  
    [MONEY] [smallint] NOT NULL ,  
    [AUTO_INCREMENT] [smallint] NULL ,  
    [LOCAL_TYPE_NAME] [sysname] NULL ,  
    [MINIMUM_SCALE] [smallint] NULL ,  
    [MAXIMUM_SCALE] [smallint] NULL ,  
    [SQL_DATA_TYPE] [smallint] NOT NULL ,  
    [SQL_DATETIME_SUB] [smallint] NULL ,  
    [NUM_PREC_RADIX] [int] NULL ,  
    [INTERVAL_PRECISION] [smallint] NULL ,  
    [USERTYPE] [smallint] NULL  
   )  
   INSERT #spt_datatype_info EXEC sp_datatype_info  
     
   ALTER TABLE [#spt_datatype_info] ADD [ss_dtype] [tinyint]  
     
   UPDATE #spt_datatype_info   
         SET ss_dtype = xtype   
    FROM systypes WHERE [name] =   
      CASE  
          WHEN charindex('(', [TYPE_NAME]) > 0 THEN LEFT([TYPE_NAME], charindex('(', [TYPE_NAME])-1)  
          WHEN charindex(' ', [TYPE_NAME]) > 0 THEN LEFT([TYPE_NAME], charindex(' ', [TYPE_NAME])-1)  
          ELSE [TYPE_NAME]   
      END  
  
 SELECT @c_comma = ''  
 SELECT @c_parenset = '0'  
 SELECT @n_continue = 1  
 SELECT @b_debug = 0  
 SELECT @n_messageno = 1  
 SELECT @c_exist1 = RTRIM(@c_copyto_db) + '.RDT.' + RTRIM(@c_tablename)  
 IF (@b_debug = 1)  
 BEGIN  
  SELECT 'in buildalterstring', @c_exist1  
 END  
  
 IF OBJECT_ID( @c_exist1) is NULL  
 BEGIN   
  SELECT @n_continue = 3  -- No need to continue if table does not exist in to database  
  SELECT @n_continue = 3  
  SELECT @n_err = 73400  
  SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":Table does not exist in Target Database " +  
   @c_tablename + "(RDT.nspBuildAlterTableString)"  
 END     
   
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
  SELECT @n_rowcount = count(sys.syscolumns.name)  
  FROM    sys.sysobjects, sys.syscolumns  
  WHERE   sys.sysobjects.id = sys.syscolumns.id  
  AND     sys.sysobjects.name = RTRIM(@c_tablename)  
  IF (@n_rowcount <= 0)  
  BEGIN    
   SELECT @n_continue = 3  
   SELECT @n_err = 73401  
   SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":No rows or columns found for " +  
    @c_tablename + "(RDT.nspBuildAlterTableString)"  
  END      
 END  
   
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
  SELECT @n_nextrow = 1  
  SELECT @c_firsttime = 'Y'  
 END  


 IF @n_continue = 1 or @n_continue = 2  
 BEGIN    
  DECLARE @b_cursoropen int  
  SELECT @b_cursoropen = 0  
  DECLARE CUR_INSERT_BUILD CURSOR LOCAL FAST_FORWARD READ_ONLY for  
  SELECT sys.syscolumns.name, sys.syscolumns.length,  
   sys.syscolumns.status, sys.syscolumns.usertype,  
   systypes.name  
  FROM    sys.sysobjects  , sys.syscolumns, systypes  
  WHERE   sys.sysobjects.id = sys.syscolumns.id AND  
   systypes.xusertype = sys.syscolumns.xusertype AND     --KH01  
   sys.sysobjects.name =  RTRIM(@c_tablename)  
  OPEN CUR_INSERT_BUILD  
  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  IF @n_err <> 0  
  BEGIN    
   SELECT @n_continue = 3  
   SELECT @n_err = 73402  
   SELECT @c_errmsg = CONVERT(char(250),@n_err)  
    + ":  Open of cursor failed. (RDT.nspBuildAlterTableString) " + " ( " +  
    " SQLSvr MESSAGE = " + LTRIM(RTRIM(@c_errmsg)) + ")"  
  END     
  IF @n_continue = 1 or @n_continue = 2  
  BEGIN  
   SELECT @b_cursoropen = 1  
  END  
  WHILE (@@FETCH_STATUS <> -3 )  
  BEGIN      
   FETCH Next from CUR_INSERT_BUILD into @c_field, @n_length,  
    @n_status, @user_type, @c_typename  
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
   IF @n_err <> 0  
   BEGIN    
    SELECT @n_continue = 3  
    SELECT @n_err = 73403  
    SELECT @c_errmsg = CONVERT(char(250),@n_err)  
     + ":  fetch failed. (RDT.nspBuildAlterTableString) " + " ( " +  
     " SQLSvr MESSAGE = " + LTRIM(RTRIM(@c_errmsg)) + ")"  
   END     
   SELECT @n_nextrow = @n_nextrow + 1  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
    IF (@@FETCH_STATUS <> -1)                 
    BEGIN   
     IF (@@FETCH_STATUS <> -2)            
     BEGIN   
      SELECT @n_inclen_flag = 0  
      SELECT  @n_prec = 0       SELECT  @n_scale = 0  
      -- IF (@c_field = 'TimeStamp')  
      -- BEGIN     
      -- SELECT @n_nextrow = @n_nextrow + 1  
      -- CONTINUE  
      -- END       
      IF (@c_typename = 'bit')  
      BEGIN  
       SELECT @n_nextrow = @n_nextrow + 1  
       CONTINUE  
      END  
      IF @c_typename = 'decimal'  
         SELECT @n_inclen_flag = 1  
        
      -- force to use varchar instead of char  
      IF @c_typename = 'char' or @c_typename = 'varchar'  
      BEGIN  
       SELECT @c_typename = 'nvarchar'  
       SELECT @n_inclen_flag = 1  
      END 
      IF @c_typename = 'nchar' or @c_typename = 'nvarchar'  
      BEGIN  
       SELECT @c_typename = 'nvarchar'  
       SELECT @n_inclen_flag = 1  
      END        
--       IF @c_typename = 'varchar'  
--       BEGIN  
--        SELECT @n_inclen_flag = 1  
--       END  
      IF ((@c_typename = 'nchar') or (@c_typename = 'nvarchar'))  
      BEGIN  
       SELECT @c_inclen = ' (' + CONVERT(char(5),@n_length)  + ') DEFAULT " "'  
      END  
      IF (@c_typename = 'decimal')  
      BEGIN  
       SELECT @n_prec = (SELECT prec from sys.syscolumns  , sys.sysobjects where  
              sys.syscolumns.name = @c_field AND  
              sys.sysobjects.id = sys.syscolumns.id AND  
              sys.sysobjects.name =  @c_tablename )  
       SELECT @n_scale = (SELECT scale from sys.syscolumns  , sys.sysobjects where  
              sys.syscolumns.name = @c_field AND  
              sys.sysobjects.id = sys.syscolumns.id AND  
              sys.sysobjects.name =  @c_tablename )  
       SELECT @c_inclen = '('+ LTRIM(convert(char(2),@n_prec))+',' + LTRIM(convert(char(2),@n_scale))+') '+ 'DEFAULT 0.0 '  
       IF (@b_debug = 1)  
       BEGIN  
        select 'type name =', @c_typename  
        select 'field name =', @c_field  
        select 'field type =', @c_typename  
        select 'null status', convert(char(4), @n_status)  
        select  'user type ',@user_type  
        select 'c_inclen', @c_inclen  
       END  
      END  
      IF (@n_inclen_flag = 0)  
      BEGIN  
       SELECT @c_inclen = ''  
      END  
      IF (@c_typename = 'float') or (@c_typename = 'int') or  
       (@c_typename = 'smallint') or (@c_typename = 'smallmoney') or  
       (@c_typename = 'tinyint') or (@c_typename = 'money') or  
       (@c_typename = 'real') or (@c_typename = 'bit')  
      BEGIN  
       SELECT @c_inclen = ' DEFAULT 0 '  
      END  

      SELECT @c_exist = " if not exists (SELECT  B.name  FROM " +  
       RTRIM(@c_copyto_db) +  ".sys.sysobjects A ," +  RTRIM(@c_copyto_db) +  
       ".sys.syscolumns B  ," +  
       " #spt_datatype_info  C WHERE   A.id = B.id AND A.name = '"  +  
       RTRIM(@c_tablename) + "'"  
  
      SELECT @c_exist1 = "  AND b.name = '" +  RTRIM(@c_field)  + "' AND " +  
      " C.ss_dtype = B.xtype  AND C.type_name not like '%id%') " +  
      " EXEC RDT.NSPALTERTABLE   '" +  RTRIM(@c_field) + "'," +  
      convert(char(5),@n_length) + ",'" + RTRIM(@c_typename) +  
      "','" + RTRIM(@c_tablename) +"','" + RTRIM(@c_copyto_db)   + "','" + RTRIM(@c_inclen) +"',0,0,'' "  
      if (@user_type = 16 or @user_type = 80)  
      BEGIN  
       select @c_exist = ''  
       select @c_exist1 = ''  
      END  
      IF (@b_debug = 1)  
      BEGIN  
       select @c_exist  
       select @c_exist1  
                     select  @c_field '@c_field', convert(char(5),@n_length) '@n_length',   
                             @c_typename '@c_typename', @c_tablename '@c_tablename', @c_inclen '@c_inclen'  
      END  
      exec  (@c_exist + @c_exist1)  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN    
  
           SELECT @n_continue = 3  
       SELECT @n_err = 73404  
       SELECT @c_errmsg = CONVERT(char(250),@n_err)  
        + ":  Alter Table Failed. (RDT.nspBuildAlterTableString) " + " ( " +  
        " SQLSvr MESSAGE = " + LTRIM(RTRIM(@c_errmsg)) + ")"  
       BREAK  
      END     
     END   
    END   
    ELSE  
    BEGIN  
     BREAK  
    END  
   END   
  END   
  IF @b_cursoropen = 1  
  BEGIN  
   Close CUR_INSERT_BUILD  
   Deallocate CUR_INSERT_BUILD  
  END  
 END  
    
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
  EXECUTE nsp_logerror @n_err, @c_errmsg, "RDT.nspBuildAlterTableString"  
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
END  


GO