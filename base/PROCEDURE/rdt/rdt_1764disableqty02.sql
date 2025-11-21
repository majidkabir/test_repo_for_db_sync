SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764DisableQTY02                                */
/* Purpose: Disable QTY field                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-07-13   Ung       1.0   SOS370418 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764DisableQTY02]
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

   DECLARE @cUOM NVARCHAR(10)

   -- Get TaskDetail info
   SELECT @cUOM = UOM 
   FROM TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskDetailKey

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @cUOM = '6'
         SET @cDisableQTYField = '1' -- Disable
      ELSE
         SET @cDisableQTYField = '0' -- Enable
   END
END

GO