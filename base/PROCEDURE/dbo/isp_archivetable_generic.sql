SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Store Procedure:  dbo.isp_ArchiveTable_Generic                                      */
/* Creation Date:                                                                      */
/* Copyright: IDS                                                                      */
/* Written by:                                                                         */
/*                                                                                     */
/* Purpose:  Archive records WITH ArchiveCop column for more than                      */
/*           by specific condition - WITH dynamic schema                               */
/*                                                                                     */
/* Input Parameters:  @cSourceDB     - Source DB                                       */
/*                    @cArchiveDB    - Archive DB                                      */
/*                    @cSrcTableName    - Source Table                                 */
/*                    @cTgtTableName    - Target Table                                 */
/*                    @cCondition    - Filter Criteria, etc                            */
/*                    @cPK1          - 1st Primary Key                                 */
/*                    @cPK2          - 2nd Primary Key                                 */
/*                    @cPK3          - 3rd Primary Key                                 */
/*                    @cPK4          - 4th Primary Key                                 */
/*                    @cPK5          - 5th Primary Key                                 */
/*                    @cPKdate       - Primary Key WITH DATETIME format                */
/*                                                                                     */
/* Usage: Derive from dbo.isp_archiveTable to allow multiple Primary Keys              */
/*                                                                                     */
/* Data Modifications:                                                                 */
/* Updates:                                                                            */
/* Date         Author        Purposes                                                 */
/* 06-Oct-2020  TLTING01      Uniqueidentifier Data Length                             */
/* 2023-03-19   kelvinongcy   Cloned isp_ArchiveTable2_Generic                         */
/* 2023-03-19   kelvinongcy   Enchance support alternative target tablename (kocy01)   */
/***************************************************************************************/
CREATE   PROC [dbo].[isp_archiveTable_GENERIC]       
(    
    @cSourceDB       NVARCHAR(128),            
    @cArchiveDB      NVARCHAR(128),            
    @cSchema         NVARCHAR(10) ,            
    @cSrcTableName   NVARCHAR(150),          
    @cTgtTableName   NVARCHAR(150),       --kocy01      
    @cCondition      NVARCHAR(MAX),            
    @cPK1            NVARCHAR(128),            
    @cPK2            NVARCHAR(128) = '',            
    @cPK3            NVARCHAR(128) = '',            
    @cPK4            NVARCHAR(128) = '',            
    @cPK5            NVARCHAR(128) = '',            
    @cPKdate         NVARCHAR(128) = '',    
    @b_debug         INT = 0        
)    
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
            
   DECLARE @b_success               INT,            
           @n_err                   INT,            
           @c_errmsg                NVARCHAR(255)          
                   
   DECLARE @n_starttcnt     INT, -- Holds the current transaction count            
           @n_continue      INT,            
           @cExecStatements NVARCHAR(MAX), --(jay01)            
           @cExecStmtArg    NVARCHAR(MAX)  --(jay01)            
            
   SELECT  @n_starttcnt = @@TRANCOUNT,            
           @n_continue  = 1,            
           @b_success   = 0,            
           @n_err       = 0,            
           @c_errmsg    = '',    
           @cExecStatements = ''            
            
   DECLARE @cPKvalue1 NVARCHAR(50),   --tlting01          
           @cPKvalue2 NVARCHAR(50),            
           @cPKvalue3 NVARCHAR(50),            
           @cPKvalue4 NVARCHAR(50),            
           @cPKvalue5 NVARCHAR(50),            
           @dPKvalue  DATETIME            
       
       
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cSrcTableName, '') <> ''            
   BEGIN    
          
      SELECT @b_success = 1            
      --EXEC dbo.nsp_Build_Archive_Table_Generic            
      --      @cSchema,            
      --      @cSourceDB,     
      --      @cArchiveDB,    
      --      @cSrcTableName,       
      --      @b_success OUTPUT,            
      --      @n_err     OUTPUT,            
      --      @c_errmsg  OUTPUT    
                
      --IF NOT @b_success = 1            
      --BEGIN            
      --   SELECT @n_continue = 3            
      --END            
           
      --IF (@b_debug = 1)            
      --BEGIN            
      --   PRINT 'building alter table string for '+@cSchema+'.'+ @cSrcTableName            
      --END            
            
      EXECUTE dbo.nspBuildAlterTableString_Generic            
            @cSchema,            
            @cArchiveDB,            
            @cSrcTableName,            
            @b_success OUTPUT,            
            @n_err     OUTPUT,            
            @c_errmsg  OUTPUT       
                  
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
                        
   SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '            
                           + 'SELECT DISTINCT ' + LTRIM(RTRIM(@cPK1))            
                           + CASE LTRIM(RTRIM(ISNULL(@cPK2   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK2 END            
                           + CASE LTRIM(RTRIM(ISNULL(@cPK3   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK3 END            
                           + CASE LTRIM(RTRIM(ISNULL(@cPK4   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK4 END            
                           + CASE LTRIM(RTRIM(ISNULL(@cPK5   ,''))) WHEN '' THEN ','''' ' ELSE ', ' + @cPK5 END            
                           + CASE LTRIM(RTRIM(ISNULL(@cPKdate,''))) WHEN '' THEN ',''1900-01-01T00:00:00.000'' ' ELSE ', ' + @cPKdate END            
                           + ' FROM '+@cSchema+ '.' + LTRIM(RTRIM(@cSrcTableName)) + ' WITH (NOLOCK) '            
                           + ' WHERE ' + @cCondition            
            
   IF (@b_debug = 1)            
   BEGIN            
      PRINT @cExecStatements            
   END            
   EXEC sp_ExecuteSql @cExecStatements            
            
   OPEN C_ITEM            
   FETCH NEXT FROM C_ITEM INTO @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue            
            
   WHILE @@FETCH_STATUS <> -1            
   BEGIN            
            
      IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cSrcTableName, '') <> ''            
   BEGIN     
          
         IF (@b_debug = 1)            
         BEGIN            
            PRINT 'building Update ArchiveCop for '+@cSchema+'.'+ @cSrcTableName            
         END            
         SELECT @b_success = 1            
            
         SET @cPKvalue1 = ISNULL(RTRIM(@cPKvalue1),'') --(jay01)            
       
         SET @cExecStatements = N'UPDATE '+ LTRIM(RTRIM(@cSchema))+'.' + LTRIM(RTRIM(@cSrcTableName)) + ' WITH (ROWLOCK) '            
                              + ' SET ArchiveCop = ''9'' '            
                              + ' WHERE '  + LTRIM(RTRIM(@cPK1)) + ' =  @cPKvalue1  '  --(jay01)            
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
         BEGIN            
            SET @cExecStatements = @cExecStatements            
                                 + ' AND ' + LTRIM(RTRIM(@cPKdate)) + ' =  CONVERT(CHAR(23),@dPKvalue,126)  '    --(jay01)            
         END            
            
         IF (@b_debug = 1)            
         BEGIN            
            PRINT @cExecStatements            
         END            
         BEGIN TRAN            
            
         SET @cExecStmtArg = N'@cPKvalue1 NVARCHAR(50), '            
                             +'@cPKvalue2 NVARCHAR(50), '            
                             +'@cPKvalue3 NVARCHAR(50), '            
                             +'@cPKvalue4 NVARCHAR(50), '            
                             +'@cPKvalue5 NVARCHAR(50), '            
                             +'@dPKvalue  DATETIME '            
            
         EXEC sp_ExecuteSql @cExecStatements, @cExecStmtArg, @cPKvalue1, @cPKvalue2, @cPKvalue3, @cPKvalue4, @cPKvalue5, @dPKvalue      --(jay01)            
            
         SELECT @n_err = @@ERROR          
                        
         IF ISNULL(@n_err, 0) <> 0            
         BEGIN            
            SELECT @n_continue = 3            
            SELECT @n_err = 73702            
            SELECT @c_errmsg = CONVERT(char(5),@n_err)            
            SELECT @c_errmsg =            
               ': Update of Archivecop failed - '+@cSchema+'.' + @cSrcTableName + '. (dbo.isp_ArchiveTable2_Generic) ( ' +            
               ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ')'            
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
                
         
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cSrcTableName, '') <> ''            
   BEGIN            
      IF (@b_debug = 1)            
      BEGIN            
         PRINT 'building insert for '+@cSchema+'.'+@cSrcTableName            
      END            
      SELECT @b_success = 1            
      EXEC dbo.nsp_Build_Insert_Generic            
         @cSchema,            
         @cArchiveDB,            
         @cSrcTableName,      
         @cTgtTableName,      --kocy01      
         1,            
         @b_success OUTPUT,            
         @n_err     OUTPUT,            
         @c_errmsg  OUTPUT    
             
      IF NOT @b_success = 1            
      BEGIN            
         SELECT @n_continue = 3            
      END            
   END            
          
   /* #INCLUDE <SPTPA01_2.SQL> */            
   IF @n_continue = 3  -- Error Occured - Process And Return            
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'dbo.isp_ArchiveTable2_Generic'            
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