SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: update_all_stats                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[update_all_stats]
AS
/*
This procedure will run UPDATE STATISTICS against
all user-defined tables within this database.
*/
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @tablename NVARCHAR(30)
   DECLARE @tablename_header NVARCHAR(75)
   DECLARE tnames_cursor CURSOR FOR SELECT name FROM sysobjects
   WHERE type = 'U'
   OPEN tnames_cursor
   FETCH NEXT FROM tnames_cursor INTO @tablename
   WHILE (@@fetch_status <> -1)
   BEGIN
      IF (@@fetch_status <> -2)
      BEGIN
         SELECT @tablename_header = "Updating " + dbo.fnc_RTrim(UPPER(@tablename))
         PRINT @tablename_header
         EXEC ("UPDATE STATISTICS " + @tablename )
      END
      FETCH NEXT FROM tnames_cursor INTO @tablename
   END
   PRINT " "
   PRINT " "
   SELECT @tablename_header = "*************  NO MORE TABLES ***************"
   PRINT @tablename_header
   PRINT " "
   PRINT "Statistics have been updated for all tables."
   DEALLOCATE tnames_cursor
END

GO