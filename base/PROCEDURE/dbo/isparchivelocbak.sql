SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : ispArchiveLOCBak                       		            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Archive LOCBAK Table                          					*/
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: 	datawindow                          				         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/************************************************************************/
CREATE PROC [dbo].[ispArchiveLOCBak]
  @nDayRetains int 
AS
SET NOCOUNT ON

DECLARE @dBeforeDate datetime
   , @cSKU  NVARCHAR(20)
   , @cLOC  NVARCHAR(10)
   , @cID   NVARCHAR(18)
   , @dInventoryDate datetime 
   , @cStorerKey     NVARCHAR(15)
   , @nContinue      int


SET @nContinue = 1
SET @nDayRetains = @nDayRetains * -1
SET @dBeforeDate = DateAdd(day, @nDayRetains, GetDate())

DECLARE curLOCBAK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT InventoryDate, LOC
   FROM LOCBAK WITH (NOLOCK)
   WHERE InventoryDate < @dBeforeDate
   -- ORDER by InventoryDate, Storerkey, Sku, Loc

OPEN curLOCBAK 

FETCH NEXT FROM curLOCBAK INTO @dInventoryDate, @cLOC 

WHILE @@FETCH_STATUS <> -1
BEGIN
   BEGIN TRAN 

   IF NOT EXISTS(SELECT 1 FROM Archive..LOCBAK WHERE 
                 InventoryDate = @dInventoryDate AND
                 Loc = @cLOC 
)
   BEGIN
      INSERT INTO [Archive].[dbo].[LOCBAK]
                 ([Loc]
                 ,[LocationType]
                 ,[PutawayZone]
                 ,[InventoryDate]
                 ,[Adddate]
                 ,[Addwho]
                 ,[Editdate]
                 ,[Editwho])
     SELECT [Loc]
           ,[LocationType]
           ,[PutawayZone]
           ,[InventoryDate]
           ,[Adddate]
           ,[Addwho]
           ,[Editdate]
           ,[Editwho]
      FROM LOCBAK WITH (NOLOCK)
      WHERE InventoryDate = @dInventoryDate AND 
            Loc = @cLOC 
            
      IF @@ERROR <> 0 
      BEGIN
         SET @nContinue = 3
         BREAK 
      END 
   END

   IF EXISTS(SELECT 1 FROM Archive..LOCBAK 
             WHERE InventoryDate = @dInventoryDate AND 
             Loc = @cLOC)
   BEGIN
      DELETE FROM LOCBAK WITH (ROWLOCK)
      WHERE InventoryDate = @dInventoryDate AND 
            Loc = @cLOC 


      IF @@ERROR <> 0 
      BEGIN
         SET @nContinue = 3
         BREAK 
      END 
   END 

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN 

   FETCH NEXT FROM curLOCBAK INTO @dInventoryDate, @cLOC 
END -- While
CLOSE curLOCBAK
DEALLOCATE curLOCBAK

IF @nContinue = 3
   ROLLBACK TRAN 


GO