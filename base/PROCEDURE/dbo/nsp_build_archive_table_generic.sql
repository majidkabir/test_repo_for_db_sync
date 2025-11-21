SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: dbo.nsp_BUILD_ARCHIVE_TABLE_GENERIC                 */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: JayLim                                                   */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  Exceed                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author     Purposes                                     */ 
/* DD-MM-YYYY                                                           */ 
/* 09-12-2016   JayLim     add in nullable columns&PK constraint (Jay01)*/
/* 06-01-2017   JayLim     Bug Fix - Column sorting              (Jay02)*/  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[nsp_BUILD_ARCHIVE_TABLE_GENERIC]
       @c_schema       NVARCHAR(10),  
       @c_copyfrom_db  NVARCHAR(50),  
       @c_copyto_db    NVARCHAR(50),  
       @c_tablename    NVARCHAR(50)  ,  
       @b_Success      int         OUTPUT ,  
       @n_err          int         OUTPUT,   
       @c_errmsg       NVARCHAR(250)   OUTPUT  
AS  
BEGIN   
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE        @c_field       NVARCHAR(50)                 
   DECLARE        @n_rowcount    int                         
   DECLARE        @n_nextrow     int                         
   DECLARE        @c_msg         NVARCHAR(255)                
   DECLARE        @c_testmsg     NVARCHAR(255)                
   DECLARE        @c_typename    NVARCHAR(32)
   DECLARE        @c_nullable    NVARCHAR(10)   --(Jay01)              
   DECLARE        @n_length      int          
   DECLARE        @c_comma       NVARCHAR(1)                     
   DECLARE        @n_strlen      int                         
   DECLARE        @c_inclen      NVARCHAR(255)                 
   DECLARE        @c_paran       NVARCHAR(1)                     
   DECLARE        @c_buildstring NVARCHAR(80)                 
   DECLARE        @c_buildmsg    NVARCHAR(125)                
   DECLARE        @n_continue    int                         
   DECLARE        @n_status      tinyint                        
   DECLARE        @n_prec        int                          
   DECLARE        @n_scale       int                          
   DECLARE        @user_type     smallint  
   DECLARE        @is_the_table_small int  
   DECLARE        @n_starttcnt    int  
   DECLARE        @b_debug       int  
   DECLARE        @n_inclen_flag int,
                  @c_FulltableName     NVARCHAR(70)
      
   SET @c_FulltableName = RTRIM(@c_schema) + '.' + RTRIM(@c_tablename) 
  
   SELECT @c_comma = ','  
   SELECT @c_paran = ')'  
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''  
--   
   SELECT @b_debug=0 
  
   SELECT @c_buildstring = RTRIM(@c_copyfrom_db) + '.' + rtrim(@c_schema) + '.' + RTRIM(@c_tablename)  
  
   IF OBJECT_ID( @c_buildstring) IS NULL OR OBJECT_ID( @c_buildstring) = ''  
   BEGIN   
      SELECT @n_continue = 3  
      SELECT @n_err =   73301  
      SELECT @c_errmsg =  'NSQL' + CONVERT(CHAR(5),@n_err) + ':' + @c_buildstring +   
            ' does  not exist (dbo.nsp_BUILD_ARCHIVE_TABLE_GENERIC)'  
   END     
  
   SELECT @c_buildstring = RTRIM(@c_copyto_db) + '.' + RTRIM(@c_schema) + '.' + RTRIM(@c_tablename)  
  
   IF NOT OBJECT_ID(@c_buildstring) IS NULL AND OBJECT_ID(@c_buildstring) <> '' 
   BEGIN   
      SELECT @n_continue = 4  -- No need to continue if table exists in target database  
   END     
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @n_rowcount = COUNT(sys.syscolumns.name)  
        FROM sys.sysobjects  , sys.syscolumns  
       WHERE sys.sysobjects.id   = sys.syscolumns.id   
         AND sys.sysobjects.name = RTRIM(@c_tablename)
         AND sys.sysobjects.id = OBJECT_ID(@c_FulltableName)  
  
      SELECT @n_nextrow = 1  
      SELECT @is_the_table_small = -1  
      SELECT @c_msg = 'Create Table ' + RTRIM(@c_copyto_db) + '.' + RTRIM(@c_schema) + '.' + RTRIM(@c_tablename) + '('  
   END  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN   
      SELECT @n_inclen_flag = 0  
  
      DECLARE CUR_TABLE_BUILD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT sys.syscolumns.name,   sys.syscolumns.length,  
             sys.syscolumns.status, sys.syscolumns.usertype,  
             systypes.name, sys.syscolumns.isNullable
        FROM sys.sysobjects, sys.syscolumns, systypes  
       WHERE sys.sysobjects.id = sys.syscolumns.id   
         AND sys.syscolumns.xtype = systypes.xtype   
         AND sys.sysobjects.name = RTRIM(@c_tablename)
         AND sys.sysobjects.id = OBJECT_ID(@c_FulltableName)
         AND systypes.name <> 'sysname'  -- (Jay02)
         ORDER BY sys.syscolumns.colid   -- (Jay02)
           
      OPEN CUR_TABLE_BUILD  
      WHILE @n_nextrow <= @n_rowcount  
      BEGIN      
         FETCH NEXT FROM CUR_TABLE_BUILD INTO @c_field, @n_length,  @n_status,  
                  @user_type, @c_typename, @c_nullable  
  
         IF (@@FETCH_STATUS <> -1)            
         BEGIN   
            IF (@@FETCH_STATUS <> -2)               
            BEGIN    
       -- force to use varchar instead of char  
               IF @c_typename = 'char' OR @c_typename = 'varchar'  
               BEGIN  
                  SELECT @c_typename = 'varchar'  
                  SELECT @n_inclen_flag = 1  
               END  
  
--             IF @c_typename = 'varchar'  
--                SELECT @n_inclen_flag = 1  
  
               IF ((@c_typename = 'char') OR (@c_typename = 'varchar'))  
               BEGIN  
                  SELECT @n_inclen_flag = 1  -- Jay01                                                              

--                SELECT @c_inclen = ' (' + CONVERT(CHAR(3),@n_length)  + ' DEFAULT '' '''  
--						SELECT @c_inclen = ' (' + CONVERT(CHAR( 3),@n_length/2)  +  ' DEFAULT ' + '(''' + ''')'  -- tlting01, Jay01 
                  SELECT @c_inclen = ' (' + CONVERT(CHAR(10),@n_length)  + ') DEFAULT ' + '(''' + ''')'  -- KHLim01, Jay01
                  
               END  

               IF ((@c_typename = 'nchar') OR (@c_typename = 'nvarchar')) --KH01
               BEGIN
                  SELECT @n_inclen_flag = 1                                                                -- Jay01 
--                SELECT @c_inclen = ' (' + CONVERT(CHAR(3),@n_length)  + ' DEFAULT '' '''  
--						SELECT @c_inclen = ' (' + CONVERT(CHAR( 3),@n_length/2)  +  ' DEFAULT ' + '(''' + ''')'  -- tlting01, Jay01 
                  SELECT @c_inclen = ' (' + CONVERT(CHAR(10),@n_length/2)  + ') DEFAULT ' + '(''' + ''')'  -- KHLim01, Jay01
                  				
               END 
        
               IF (@c_typename = 'decimal')  
               BEGIN  
                  
                  SELECT @n_inclen_flag = 1  -- Jay01
                  SELECT @n_prec = (SELECT prec FROM sys.syscolumns, sys.sysobjects   
          WHERE sys.syscolumns.name = RTRIM(@c_field)   
                                       AND sys.sysobjects.id = sys.syscolumns.id   
                                       AND sys.sysobjects.name =  RTRIM(@c_tablename)
                                       AND sys.sysobjects.id = OBJECT_ID(@c_FulltableName) )  
                  SELECT @n_scale = (SELECT scale from sys.syscolumns  , sys.sysobjects   
                                      WHERE sys.syscolumns.name = RTRIM(@c_field)   
                                        AND sys.sysobjects.id = sys.syscolumns.id   
                                        AND sys.sysobjects.name =  RTRIM(@c_tablename)
                                        AND sys.sysobjects.id = OBJECT_ID(@c_FulltableName) )  
                  SELECT @c_inclen = '('+LTRIM(CONVERT(CHAR(2),@n_prec))+',' + LTRIM(CONVERT(CHAR(2),@n_scale))+') '+ 'DEFAULT 0.0 '  
           
                  IF (@b_debug = 1)  
                  BEGIN  
                     SELECT 'field name =', @c_field 
                     SELECT 'field type =', @c_typename  
                     SELECT 'null status', CONVERT(CHAR(4), @n_status) 
                     SELECT 'user type ',@user_type  
                     SELECT 'c_inclen', @c_inclen  
                  END  
               END  
     
               IF (@n_inclen_flag = 0)  
               BEGIN  
                  SELECT @c_inclen = ''  
               END  
  
   IF (@c_typename = 'float') OR (@c_typename = 'int') OR  
                  (@c_typename = 'smallint') OR (@c_typename = 'smallmoney') OR  
                  (@c_typename = 'tinyint') OR (@c_typename = 'money') OR  
                  (@c_typename = 'real') OR (@c_typename = 'bit')  
               BEGIN  
                  SELECT @c_inclen = ' DEFAULT 0 '  
               END  
  
               IF (RTRIM(@c_field) <> 'TimeStamp')  
                  BEGIN  
                  IF (RTRIM(@c_typename) <> 'bit' )  
                  BEGIN  
                     IF (@c_nullable = 0) --Jay01
                     BEGIN
                     SELECT @c_testmsg  = RTRIM(@c_msg) +' ' + RTRIM(@c_field) + ' ' + RTRIM(@c_typename)  
                     + ' NOT NULL ' + RTRIM(@c_inclen) + RTRIM(@c_paran)  
                     END
                     ELSE
                     BEGIN
                     SELECT @c_testmsg  = RTRIM(@c_msg) +' ' + RTRIM(@c_field) + ' ' + RTRIM(@c_typename)  
                     + ' NULL ' + RTRIM(@c_inclen) + RTRIM(@c_paran)
                     END
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @c_testmsg  = RTRIM(@c_msg) +' ' + RTRIM(@c_field) + ' ' + RTRIM(@c_typename) +  
                     RTRIM(@c_inclen) + RTRIM(@c_paran)  
                  END  
               END   
  
               IF (LEN(@c_testmsg) > 200)  
               BEGIN    
                  SELECT @is_the_table_small = 0  
                  SELECT @n_strlen =  LEN(RTRIM(@c_msg))  
  
                  SELECT @c_msg = SUBSTRING(RTRIM(@c_msg),1,(@n_strlen - 1)) + RTRIM(@c_paran)  
  
                  IF (@b_debug = 1)  
                  BEGIN  
                     SELECT @c_paran  
                     SELECT 'len > 200', @n_strlen, @c_msg  
                  END  
  
                  EXEC  (@c_msg)  
                  SELECT @c_paran = ''  
                  SELECT @c_msg = ''  
  
                  SELECT @c_testmsg = '' 
  
                  IF (RTRIM(@c_field) <> 'TimeStamp')  
                  BEGIN  
                     SELECT @c_msg = 'Alter Table ' + RTRIM(@c_copyto_db) + '.' + RTRIM(@c_schema) + '.' + RTRIM(@c_tablename) + ' ADD '  
                  END  
               END    
  
               IF (@n_nextrow <= @n_rowcount AND @user_type <> 80 AND RTRIM(@c_field) <> 'TimeStamp'  
                  AND (@is_the_table_small = 0 OR @is_the_table_small = -1))  
               BEGIN  
                  IF (RTRIM(@c_typename) <> 'bit')  
                  BEGIN  
                                          IF (@c_nullable = 0) -- Jay01
                     BEGIN
                        SELECT @c_msg = RTRIM(@c_msg) +' ' + RTRIM(@c_field) + ' ' + RTRIM(@c_typename) +  
                        RTRIM(@c_inclen) + ' NOT NULL ' + RTRIM(@c_comma)
                     END
                     ELSE
                     BEGIN  
                        SELECT @c_msg = RTRIM(@c_msg) +' ' + RTRIM(@c_field) + ' ' + RTRIM(@c_typename) +  
                        RTRIM(@c_inclen) + ' NULL ' + RTRIM(@c_comma)
                     END
                  END  
                  ELSE  
                  BEGIN  
        SELECT @c_msg = RTRIM(@c_msg) +' ' + RTRIM(@c_field) + ' ' + RTRIM(@c_typename) +  
                     RTRIM(@c_inclen) + RTRIM(@c_comma)  
                  END  
               END  
  
               IF (@b_debug = 1)  
               BEGIN  
                  SELECT 'n_nextrow', @n_nextrow, @c_typename, @user_type  
                  SELECT 'n_rowcount', @n_rowcount  
               END  
  
               IF (@n_nextrow = @n_rowcount AND @is_the_table_small = -1)  
               BEGIN  
                  IF (@b_debug = 1)  
                  BEGIN  
                     SELECT 'IF n_rowcount = n_nextrow', @n_nextrow, @c_typename, @user_type  
                     SELECT 'n_rowcount', @n_rowcount  
                  END  
  
                  SELECT @n_strlen =  LEN(@c_msg)  
                  SELECT @c_msg = SUBSTRING(RTRIM(@c_msg),1,(@n_strlen - 1)) + RTRIM(@c_paran)  
  
                  IF (@b_debug = 1)  
                  BEGIN  
                     SELECT 'len < 200 AND table is small', @n_strlen, @c_msg  
                  END  
  
                  IF (@n_rowcount = 1 AND (RTRIM(@c_field) = 'TimeStamp'))  
                  BEGIN  
                     SELECT @c_msg = ''  
                  END  
  
                  EXEC  (@c_msg)  
                  SELECT @c_msg = ''  
               END    
            END
            
            /*----------------------------------------------------------*/
            /*---- Uncomment statement below this for value checking ---*/
            /*----------------------------------------------------------*/
              --select CONVERT(CHAR(10),@n_length) 
              --select @c_inclen
              --select @n_inclen_flag 
              --select @c_typename
              --select @user_type  
              --select CONVERT(CHAR(4), @n_status)
            /*----------------------------------------------------------*/
            /*----------------------------------------------------------*/

            IF (@b_debug = 1)  
            BEGIN  
            SELECT 'len =',LEN(@c_msg),'str =',@c_msg  
            END  
            SELECT  @n_nextrow = @n_nextrow + 1  
            SELECT @n_inclen_flag = 0  
END     
END     
  
      IF (@b_debug = 1)  
      BEGIN  
         SELECT 'before final @c_msg', @c_msg       
      END  
  
      SELECT @n_strlen = LEN(RTRIM(@c_msg))  
      IF (@n_strlen > 0 )  
      BEGIN   
         IF (@b_debug = 1)  
         BEGIN  
            SELECT 'before removal of final commaa', RTRIM(@c_msg)  
         END  
  
         SELECT @c_msg = substring(@c_msg,1,(@n_strlen - 1))  
         IF (@b_debug = 1)  
         BEGIN  
            SELECT 'after removal of final commaa', RTRIM(@c_msg)  
         END  
  
         IF (CHARINDEX('Alter', @c_msg) = 0 )  
         BEGIN  
            SELECT @c_msg = 'Alter Table ' + @c_copyto_db + '.' + @c_schema + '.' +  @c_tablename + ' ADD ' + @c_msg  
  
            IF (@b_debug = 1)  
            BEGIN  
               SELECT 'final alter statement', RTRIM(@c_msg)  
            END  
         END  
  
         EXEC (@c_msg)  
         SELECT @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN    
            SELECT @n_continue = 3  
            SELECT @n_err =   73302  
  
            IF (@b_debug = 1)  
            BEGIN  
               SELECT 'in dbo.nsp_BUILD_ARCHIVE_TABLE_GENERIC', @c_tablename, @c_schema
               SELECT '@c_msg ', @c_msg  
               SELECT '  '  
            END  
  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) + ':  fetch failed. (dbo.nsp_BUILD_ARCHIVE_TABLE_GENERIC) ' + ' ( ' +  
                  ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@c_errmsg)) + ')'  
         END     
      END     
  
      CLOSE      CUR_TABLE_BUILD  
      DEALLOCATE CUR_TABLE_BUILD
      
      EXECUTE isp_Build_ARCHIVE_Table_PK_GENERIC 
              @c_schema
             ,@c_copyfrom_db
             ,@c_copyto_db
             ,@c_tablename
             ,@b_Success OUTPUT
             ,@n_err OUTPUT
             ,@c_errmsg OUTPUT  

      IF not @b_Success = 1  
      BEGIN  
         SELECT @n_continue = 3  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'dbo.nsp_BUILD_ARCHIVE_TABLE_GENERIC'    
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