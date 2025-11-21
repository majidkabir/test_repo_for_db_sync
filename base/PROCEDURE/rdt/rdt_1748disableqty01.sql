SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1748DisableQTY01                                */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-05-20   Ung       1.0   SOS340175 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1748DisableQTY01]
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

   DECLARE @cLoseUCC NVARCHAR(1)

   -- Get TaskDetail info
   SELECT 
      @cLoseUCC = LOC.LoseUCC
   FROM TaskDetail WITH (NOLOCK) 
      JOIN LOC WITH (NOLOCK) ON (LOC.LOC = TaskDetail.FromLOC)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- TM Move
   IF @nFunc = 1748
   BEGIN
      -- Disable by default
      SET @cDisableQTYField = '1' -- Disable
      
      -- Enable if DPP
      IF @cLoseUCC = '1'
         SET @cDisableQTYField = '0' -- Enable
   END
END

GO