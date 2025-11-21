SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Store Procedure:  isp_GenericPurgingALL                              */          
/* Creation Date: 14-Feb-2014                                           */          
/* Copyright: IDS                                                       */          
/* Written by: TLTING                                                   */          
/*                                                                      */          
/* Purpose:  A generic purging base on Codelkup - DataPurge             */          
/*           Calling script like isp_RecordsPurging2                    */          
/*                                                                      */          
/* Input Parameters:  Setup in Codelkup                                 */          
/*                   Codelkup    isp_RecordsPurging2                    */
/*                   Code     - Name                                    */
/*                   UDF01    - @cTableName1                            */
/*                   UDF02    - @cTableName2                            */ 
/*                   UDF03    - @cTableName3                            */ 
/*                   UDF04    - @cTableName4                            */ 
/*                   UDF05    - @cPurgeGroup                            */ 
/*                   Short    - @nDays                                  */ 
/*                   Long     - @cDateCol                               */ 
/*                   Notes    - @cCondition                             */ 
/*                                                                      */          
/* Usage:  Purge older records with the same batch of tables,           */          
/*         (same interface) at one time.                                */          
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
/* Date         Author  Ver  Purposes                                   */          
/* 08-Feb-2014  TLTING  1.0  Initial version                            */   
/* 04-Nov-2014  TLTING  1.0  Add debug                                  */   
/* 20-Nov-2015  TLTING    cahnge table name length to 100               */  
/*                        GOTO DB                                       */  
/************************************************************************/          


/*

INSERT INTO dbo.Codelist (LISTNAME,[DESCRIPTION])
VALUES ('TableHKP', 'WMS Table Housekeep')


INSERT INTO CODELKUP (LISTNAME,Code,[Description],Short,Long,Notes,UDF01,UDF02,UDF03,UDF04,UDF05)
VALUES ('TableHKP','RDT.RDTMESSAGE','Purge RDT message', '90','AddDate','','RDT.RDTMESSAGE','','','','')

*/
          
CREATE PROC [dbo].[isp_GenericPurgingALL]    
( @cPurgeGroup    Nvarchar(30) = '',
  @b_debug         INT         = 0 
          )         
AS          
BEGIN          
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
          
   DECLARE @b_success       INT          
         , @cTableName      NVARCHAR(100)          
   , @cExecStatements NVARCHAR(2000)          
         

      DECLARE @cTableName1 NVARCHAR(100),  -- UDF01
              @cTableName2 NVARCHAR(100),
              @cTableName3 NVARCHAR(100),
              @cTableName4 NVARCHAR(100),
              @cDays       Nvarchar(5),     -- short
              @cDateCol    Nvarchar(30), --   Long       
              @cCondition  Nvarchar(1000),   -- Notes
              @cDBName     NVARCHAR(30)
              
   SELECT  @b_success       = 1          
         , @cTableName      = ''     
         , @cExecStatements = ''

IF @b_debug is NULL
   SET @b_debug = 0

IF ISNULL(RTRIM(@cPurgeGroup), '') = ''
BEGIN
   DECLARE C_ITEM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT ISNULL(RTRIM(UDF01), ''), ISNULL(RTRIM(UDF02), ''), ISNULL(RTRIM(UDF03), ''),
         ISNULL(RTRIM(UDF04), ''),  ISNULL(RTRIM(Short), ''), 
         ISNULL(RTRIM(Long), ''), ISNULL(RTRIM(Notes), ''), code2
   FROM    dbo.CODELKUP with (NOLOCK)
   WHERE LISTNAME = 'TableHKP' 
   AND ( UDF05 IS NULL OR UDF05 = '' )
END
ELSE    
BEGIN    
   DECLARE C_ITEM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT ISNULL(RTRIM(UDF01), ''), ISNULL(RTRIM(UDF02), ''), ISNULL(RTRIM(UDF03), ''),
         ISNULL(RTRIM(UDF04), ''),  ISNULL(RTRIM(Short), ''), 
         ISNULL(RTRIM(Long), ''), ISNULL(RTRIM(Notes), ''), code2 
         
   FROM    dbo.CODELKUP with (NOLOCK)
   WHERE LISTNAME = 'TableHKP'
   AND UDF05 = RTRIM(@cPurgeGroup)
END
 
OPEN C_ITEM 

FETCH NEXT FROM C_ITEM INTO @cTableName1, @cTableName2, @cTableName3, @cTableName4, 
      @cDays, @cDateCol, @cCondition, @cDBName

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF  ISNULL( RTRIM(@cDBName), '' ) = ''
   BEGIN
      Set @cDBName =DB_NAME()
   END
        
   SET @cExecStatements = ''
   SET @cExecStatements = N'USE ' + @cDBName + ' ' + CHAR(13) 
                  + 'EXEC isp_RecordsPurging2 ''' + @cTableName1               
						+ ''', ''' + @cTableName2 + ''', ''' + @cTableName3 + 
						+ ''', ''' + @cTableName4 + ''', '''  						
			    		+ ''', ' + @cDays + ', ''' + @cDateCol  + ''', "' + @cCondition + '"'  
			
   IF @b_debug  = 1
   BEGIN						
      PRINT @cExecStatements
   END
   
   EXEC sp_ExecuteSql @cExecStatements      
   
  FETCH NEXT FROM C_ITEM INTO @cTableName1, @cTableName2, @cTableName3, @cTableName4, 
      @cDays, @cDateCol, @cCondition, @cDBName

END   
CLOSE C_ITEM
DEALLOCATE C_ITEM
    
END -- procedure     


GO