SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 /************************************************************************/  
/* Store Procedure:  isp_RecordsArchiving                               */  
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
/* 2008/8/28    TLTING    Put Orderby Column in Select  (TLTING01)      */ 
/*						  Order by   , "" will cuase problem			*/
/************************************************************************/  

CREATE PROC [dbo].[isp_RecordsArchiving]    
    @cSourceDB NVARCHAR(15) ,   
    @cArchiveDB NVARCHAR(15) ,   
    @cTableName1 NVARCHAR(30) ,   
    @cTableName2 NVARCHAR(30) ,   
    @cKeyName1 NVARCHAR(30) ,   
    @cKeyName2 NVARCHAR(30) ,   
    @cStatusFlag NVARCHAR(30) ,   
    @nDays INT ,    
    @b_success INT OUTPUT ,   
    @n_err INT OUTPUT ,   
    @c_errmsg NVARCHAR(250) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE  @b_debug INT   
   DECLARE  @n_rowid INT   -- TLTING01

   SELECT   @b_debug = 0   

   DECLARE  @n_starttcnt INT , -- Holds the current transaction count    
            @n_continue INT ,   
            @cTableName NVARCHAR(30) ,   
            @cKey1 NVARCHAR(10) ,   
            @cKey2 NVARCHAR(10) ,   
            @cExecStatements NVARCHAR(2000) ,   
            @nCounter INT ,   
            @cMaxAddDate NVARCHAR(8) ,   
            @cAddDate NVARCHAR(8)   
   SELECT   @n_starttcnt = @@TRANCOUNT ,   
            @n_continue = 1 ,   
            @b_success = 0 ,   
            @n_err = 0 ,   
            @c_errmsg = '' ,   
            @cTableName = '' ,    
            @cKey1 = '' ,   
            @cKey2 = '' ,   
            @cExecStatements = '' ,   
            @nCounter = 0 ,   
            @cMaxAddDate = '' ,   
            @cAddDate = ''   
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      CREATE TABLE [#TempArchive] (  
         [RowID] [varchar] (2) NULL ,    
         [TableName] [varchar] (30) NULL )   
  
      -- Check and insert into temp table if parameters of TableName having values.  
      IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cTableName1)),'') <> ''   
      BEGIN   
         INSERT INTO #TempArchive (RowID, TableName) VALUES ('1', @cTableName1)  
      END  
      IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cTableName2)),'') <> ''   
      BEGIN   
         INSERT INTO #TempArchive (RowID, TableName) VALUES ('2', @cTableName2)  
      END  
  
  
      -- Cursor Start   
      DECLARE TempArchive CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
  
      SELECT TableName, RowID FROM #TempArchive (NOLOCK) ORDER BY RowID     -- TLTING01
      OPEN TempArchive  
      FETCH NEXT FROM TempArchive INTO @cTableName  , @n_rowid  -- TLTING01
  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT * FROM #TempArchive (NOLOCK)   
         SELECT 'Start processing cursor TempArchive... ' , master.dbo.fnc_GetCharASCII(13) ,   
                '@cTableName to get minimum date : ' , @cTableName   
      END  
  
      -- Get the Minimum date for records archiving - Start  
      SELECT @cMaxAddDate = '' ,   
             @cAddDate = '' ,   
             @nCounter = 0    
      SELECT @cExecStatements = N'SELECT DISTINCT @cMaxAddDate = MAX(CONVERT(CHAR(8), AddDate, 112)) '   
                                + ' FROM ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) + ' (NOLOCK) '  
      EXEC sp_executesql @cExecStatements, N'@cMaxAddDate NVARCHAR(8) OUTPUT ', @cMaxAddDate OUTPUT   
  
      IF @b_debug = 1  
      BEGIN  
         SELECT '@cMaxAddDate : ' , @cMaxAddDate   
      END  
  
      -- Loop to get the Minimum date for specific working days prior to the Maximum date.  
      WHILE @nCounter < @nDays  
      BEGIN  
         SELECT @cExecStatements = N'SELECT @cAddDate = MAX(CONVERT(CHAR(8), AddDate, 112)) '   
                                   + ' FROM ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) + ' (NOLOCK) '  
                                   + ' WHERE CONVERT(CHAR(8), AddDate, 112) < "' + @cMaxAddDate + '" '   
         EXEC sp_executesql @cExecStatements, N'@cAddDate NVARCHAR(8) OUTPUT ', @cAddDate OUTPUT   
  
         SELECT @cMaxAddDate = @cAddDate   
  
         IF @b_debug = 1  
         BEGIN  
            SELECT '@cAddDate : ' , @cAddDate   
         END  
  
         SET @nCounter = @nCounter + 1   
      END -- WHILE @nCounter < @nDays  
      -- Get the Minimum date for records archiving - End  
  

      WHILE @@fetch_status <> -1  
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
          SELECT '@cTableName : ' , @cTableName   
         END  
  
         -- Archive all the records older than the Minimum date for specific working days.  
         IF ISNULL(@cMaxAddDate,'') <> ''   
         BEGIN  
            CREATE TABLE #TempArchiveRec (Key1 NVARCHAR(10), Key2 NVARCHAR(10))  
  
--            SELECT @cExecStatements = N'SELECT DISTINCT ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName1)) + ',' +   
--                                        ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)),'""') + ' FROM ' +   
--                                        dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
--                                      ' WHERE CONVERT(CHAR(8), AddDate, 112) < "' + @cMaxAddDate + '"' +   
--                                      ' AND ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cStatusFlag)) + ' = "9"' +   
--                                      ' ORDER BY ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName1)) + ',' +   
--                                        ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)),'""')   
			/* TLTING01  Order by   , "" will cuase problem   */
            SELECT @cExecStatements = N'SELECT DISTINCT ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName1)) + ',' +
										ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)),'""') + ' FROM ' +   
                                        dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
                                      ' WHERE CONVERT(CHAR(8), AddDate, 112) < "' + @cMaxAddDate + '"' +   
                                      ' AND ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cStatusFlag)) + ' = "9"' +   
                                      ' ORDER BY ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName1)) +   
										 CASE WHEN ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)),'') = '' THEN '' ELSE
										',' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)) END 
 
            INSERT INTO #TempArchiveRec (Key1, Key2)  
            EXEC ( @cExecStatements )  

            DECLARE TempArchiveRec CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
            SELECT Key1, Key2 FROM #TempArchiveRec (NOLOCK) ORDER BY Key1, Key2    
  
            OPEN TempArchiveRec  
            FETCH NEXT FROM TempArchiveRec INTO @cKey1, @cKey2    
  
            SELECT @cExecStatements = N'UPDATE ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
                                      ' SET ArchiveCop = "9" WHERE CONVERT(CHAR(8), AddDate, 112) < "' +   
                                        @cMaxAddDate + '"' +   
                                      ' AND ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cStatusFlag)) + ' = "9"'    
            BEGIN TRAN   
            EXEC sp_executesql @cExecStatements   
  
            IF @@ERROR = 0  
            BEGIN  
               COMMIT TRAN    
            END  
            ELSE  
            BEGIN  
               ROLLBACK TRAN  
               SELECT @n_Continue = 3  
               SELECT @n_err = 65000  
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) +   
                                  ': Update of ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
                                  ' failed - (isp_RecordsArchiving)'    
            END    
  
            IF @b_debug = 1  
            BEGIN  
               SELECT * FROM #TempArchiveRec (NOLOCK)   
               SELECT 'Start processing cursor TempArchiveRec... '    
            END  
  
            WHILE @@fetch_status <> -1 -- TempArchiveRec  
            BEGIN  
               SELECT @cExecStatements = N'INSERT INTO ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cArchiveDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
                                         ' SELECT * FROM ' +   
                                           dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
                                         ' WHERE ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName1)) + ' = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKey1)) + '''' +   
                                         ' AND ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)),'''''') +   
                                         ' = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKey2)) + ''''  
               BEGIN TRAN  
               EXEC sp_executesql @cExecStatements   
  
               IF @@ERROR = 0  
               BEGIN  
                  COMMIT TRAN    
  
                  SELECT @cExecStatements = N'DELETE ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cSourceDB)) + '..' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cTableName)) +   
                                            ' WHERE ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName1)) + ' = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKey1)) + '''' +   
                                            ' AND ' + ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@cKeyName2)),'''''') +   
                                            ' = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cKey2)) + ''''  
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT 'Purging record key = ' , @cKeyName1 , master.dbo.fnc_GetCharASCII(13)   
                  END  
  
                  BEGIN TRAN  
                  EXEC sp_executesql @cExecStatements   
                  COMMIT TRAN  
               END -- IF @@ERROR = 0  
  
               FETCH NEXT FROM TempArchiveRec INTO @cKey1, @cKey2    
            END -- WHILE @@fetch_status <> -1 -- TempArchiveRec  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'End Cursor TempArchiveRec ! '  
            END  
  
            CLOSE TempArchiveRec   
            DEALLOCATE TempArchiveRec  
            -- Cursor End   
  
            DROP TABLE #TempArchiveRec  
         END  
  
         FETCH NEXT FROM TempArchive INTO @cTableName , @n_rowid       -- TLTING01
      END -- WHILE @@fetch_status <> -1   
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'End Cursor TempArchive ! '  
      END  
  
      CLOSE TempArchive   
      DEALLOCATE TempArchive  
      -- Cursor End   
     
      DROP TABLE #TempArchive   
   END -- IF @n_continue = 1 OR @n_continue = 2  
  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_RecordsArchiving'    
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