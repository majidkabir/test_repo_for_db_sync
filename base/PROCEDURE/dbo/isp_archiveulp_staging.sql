SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_archiveULP_Staging                               */  
/* Creation Date: 08-Dec-2005                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YokeBeen                                                 */  
/*                                                                      */  
/* Purpose:  Archive records from the existing stand alone tables to    */  
/*           the Archive DB for more than specific days in order to     */  
/*           reduce the performance issues.                             */  
/*                                                                      */  
/* Input Parameters:  @cSourceDB     - Exceed DB                        */  
/*                    @cArchiveDB    - Archive DB                       */  
/*                    @cTableName1   - 1st Table to process             */  
/*                    @cTableName2   - 2nd Table to process             */  
/*                    @cKey1         - Key 1 (eg.Orderkey)              */  
/*                    @cKey2         - Key 2 (eg.Orderlinenumber)       */  
/*                    @cStatusFlag   - Status/TransmitFlag/etc          */  
/*                    @nDays         - # of days to to keep             */  
/*                    @b_success     - 0 (Output)                       */   
/*                    @n_err         - 0 (Output)                       */   
/*                    @c_errmsg      = '' (Output)                      */   
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
/*                                                                      */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_archiveULP_Staging]    
    @cSourceDB NVARCHAR(15) ,   
    @cArchiveDB NVARCHAR(15) ,   
    @cTableName NVARCHAR(30) ,   
    @cTableName1 NVARCHAR(30) ,   
    @cTableName2 NVARCHAR(30) ,   
    @cTableName3 NVARCHAR(30) , 
    @cKeyName NVARCHAR(30) ,             
    @cKeyName1 NVARCHAR(30) ,   
    @cKeyName2 NVARCHAR(30) ,   
    @cKeyName3 NVARCHAR(30) ,       
    @nDays INT 
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_success INT,   
            @n_err INT, 
            @c_errmsg NVARCHAR(250)  
  
   DECLARE  @b_debug INT   
   SELECT   @b_debug = 1   
   DECLARE  @n_starttcnt INT , -- Holds the current transaction count    
            @n_continue INT ,   
--            @cTableName NVARCHAR(30) ,   
--            @cKey1 NVARCHAR(10) ,   
--            @cKey2 NVARCHAR(10) ,   
            @cExecStatements NVARCHAR(2000)    
  --          @nCounter INT ,   
    --        @cMaxAddDate NVARCHAR(8) ,   
      --      @cAddDate NVARCHAR(8)   
   SELECT   @n_starttcnt = @@TRANCOUNT ,   
            @n_continue = 1 ,   
            @b_success = 0 ,   
            @n_err = 0 ,   
            @c_errmsg = '' ,   
         --   @cTableName = '' ,    
        --    @cKey1 = '' ,   
       --     @cKey2 = '' ,   
            @cExecStatements = ''    
       -- @nCounter = 0 ,   
       --     @cMaxAddDate = '' ,   
        --    @cAddDate = ''   
  

   DECLARE @c_KeyValue NVARCHAR(15),
           @c_SQLWhere NVARCHAR(2000),
           @c_KeyColumn NVARCHAR(50)
 
   	

   SET @cExecStatements = N'DECLARE C_ITEM CURSOR FAST_FORWARD READ_ONLY FOR '  
                              + 'SELECT DISTINCT ' + LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName))    
                              + ' FROM ' + LTRIM(RTRIM(@cTableName))   
                              + ' WITH (NOLOCK) '   
                              + ' JOIN ' + LTRIM(RTRIM(@cTableName1)) + ' WITH (NOLOCK) on ' 
                              + LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName)) + ' = '
                              + LTRIM(RTRIM(@cTableName1)) + '.' + LTRIM(RTRIM(@cKeyName1))
                              + ' WHERE ' + LTRIM(RTRIM(@cTableName)) + '.CTSTS in ("C","E", "X")  ' + 
             						+ ' AND CONVERT(CHAR(8), ' + LTRIM(RTRIM(@cTableName)) + '.CTCRDT, 112) ' +
                              + ' <= convert(char(8), getdate() - ' + cast(@nDays as varchar) + ', 112)  ' 

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
        -- SET @c_KeyColumn =  LTRIM(RTRIM(@cKeyName1)) 
         SET @c_SQLWhere =  LTRIM(RTRIM(@cTableName1)) + '.' + LTRIM(RTRIM(@cKeyName1)) 
                            + ' = N''' + RTRIM(@c_KeyValue) + ''' '
	      if (@b_debug =1 )
	      begin
            print @c_SQLWhere
	         print 'building insert for ' + @cTableName1
	      end
	      select @b_success = 1
	      exec nsp_Build_Insert2  
	         @cArchiveDB, 
	         @cTableName1,
            @cKeyName1,
	         @c_SQLWhere,
	         @b_success output , 
	         @n_err output, 
	         @c_errmsg output
	      if not @b_success = 1
	      begin
	         select @n_continue = 3
	      end
      END

   	IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName2, '') <> ''
   	BEGIN
         --SET @c_KeyColumn =  LTRIM(RTRIM(@cKeyName2)) 
         SET @c_SQLWhere =  LTRIM(RTRIM(@cTableName2)) + '.' + LTRIM(RTRIM(@cKeyName2)) 
                            + ' = N''' + @c_KeyValue + ''' '
	      if (@b_debug =1 )
	      begin
            print @c_SQLWhere
	         print 'building insert for ' + @cTableName2
	      end
	      select @b_success = 1
	      exec nsp_Build_Insert2  
	         @cArchiveDB, 
	         @cTableName2,
            @cKeyName2,
	         @c_SQLWhere,
	         @b_success output , 
	         @n_err output, 
	         @c_errmsg output
	      if not @b_success = 1
	      begin
	         select @n_continue = 3
	      end
      END

   	IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName3, '') <> ''
   	BEGIN

         SET @c_SQLWhere =  LTRIM(RTRIM(@cTableName3)) + '.' + LTRIM(RTRIM(@cKeyName3)) 
                            + ' = N''' + @c_KeyValue + ''' '
	      if (@b_debug =1 )
	      begin
            print @c_SQLWhere
	         print 'building insert for ' + @cTableName3
	      end
	      select @b_success = 1
	      exec nsp_Build_Insert2  
	         @cArchiveDB, 
	         @cTableName3,
            @cKeyName3,
	         @c_SQLWhere,
	         @b_success output , 
	         @n_err output, 
	         @c_errmsg output
	      if not @b_success = 1
	      begin
	         select @n_continue = 3
	      end
      END

   	IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@cTableName, '') <> ''
   	BEGIN
         --SET @c_KeyColumn = LTRIM(RTRIM(@cKeyName)) 
         SET @c_SQLWhere =  LTRIM(RTRIM(@cTableName)) + '.' + LTRIM(RTRIM(@cKeyName)) 
                            + ' = N''' + @c_KeyValue + ''' '
	      if (@b_debug =1 )
	      begin
            print @c_SQLWhere
	         print 'building insert for ' + @cTableName
	      end
	      select @b_success = 1
	      exec nsp_Build_Insert2  
	         @cArchiveDB, 
	         @cTableName,
            @cKeyName,
	         @c_SQLWhere,
	         @b_success output , 
	         @n_err output, 
	         @c_errmsg output
	      if not @b_success = 1
	      begin
	         select @n_continue = 3
	      end
		END   


      FETCH NEXT FROM C_ITEM INTO @c_KeyValue   
   END -- WHILE @@FETCH_STATUS <> -1   
   CLOSE C_ITEM  
   DEALLOCATE C_ITEM   

  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_archiveULP_Staging'    
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