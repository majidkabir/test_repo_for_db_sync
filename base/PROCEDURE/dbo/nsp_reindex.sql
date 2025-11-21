SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 


/************************************************************************/
/* Store procedure: nsp_ReIndex                                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: table reindex                                               */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From scheduler                                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 31-Aug-2021 1.1  TLTING01 Performance tune - less blocking           */
/*                                                                      */
/************************************************************************/


CREATE PROC [dbo].[nsp_ReIndex]
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @vcTableName nvarchar(50), @max tinyint

DECLARE cur CURSOR FAST_FORWARD READ_ONLY FOR
SELECT vcTableName FROM indexes ORDER BY nmPriority ASC
OPEN cur
FETCH NEXT FROM cur INTO @vcTableName
WHILE @@FETCH_STATUS = 0
BEGIN
	 
   -- LTTING01
   EXEC ('ALTER INDEX ALL ON  ' +  @vcTableName + ' REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON, STATISTICS_NORECOMPUTE = OFF,  ' +
   'ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON ); ')

--	EXEC ('DBCC DBREINDEX (N''' + @vcTableName + ''') WITH NO_INFOMSGS')
	SELECT @max=MAX(nmPriority) FROM indexes
	UPDATE indexes SET nmPriority = @max, dtLastUpdated = getDate() WHERE vcTableName = @vcTableName
	UPDATE indexes SET nmPriority = nmPriority - 1 WHERE vcTableName NOT IN (@vcTableName)
	
	FETCH NEXT FROM cur INTO @vcTableName

END
CLOSE cur
DEALLOCATE cur
SET NOCOUNT OFF
/*
Final result

A 1 	4 3 2 1
B 2 	1 4 3 2
C 3 	2 1 4 3
D 4 	3 2 1 4
*/

GO