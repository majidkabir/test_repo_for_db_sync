SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812DisableQTY01                                */
/* Purpose: Disable QTY field                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-03-27   Ung       1.0   WMS-3333 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812DisableQTY01]
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@nStep              INT 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@cDisableQTYField   NVARCHAR( 1)  OUTPUT
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLOCType NVARCHAR(10)
   DECLARE @cLOCCat NVARCHAR(10)

   -- Get TaskDetail info
   SELECT 
      @cLOCType = LOC.LocationType, 
      @cLOCCat = LOC.LocationCategory
   FROM TaskDetail TD WITH (NOLOCK) 
      JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- TM case pick
   IF @nFunc = 1812
   BEGIN
      IF @cLOCType = 'OTHER' OR @cLOCCat = 'FLOWRACK'
         SET @cDisableQTYField = '1' -- Disable
      ELSE
         SET @cDisableQTYField = '0' -- Enable
   END
END

GO