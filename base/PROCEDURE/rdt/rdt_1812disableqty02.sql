SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812DisableQTY02                                */
/* Purpose: Disable QTY field                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2019-03-12   Ung       1.0   WMS-8058 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812DisableQTY02]
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

   DECLARE @cStorerKey  NVARCHAR(15)
   DECLARE @cSKU        NVARCHAR(20)
   DECLARE @cBUSR1      NVARCHAR(30)

   -- TM case pick
   IF @nFunc = 1812
   BEGIN
      -- Get TaskDetail info
      SELECT 
         @cStorerKey = StorerKey, 
         @cSKU = SKU
      FROM TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey

      -- Get SKU info
      SELECT @cBUSR1 = ISNULL( BUSR1, '') FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

      IF @cBUSR1 = 'Y' -- SKU with UCC
         SET @cDisableQTYField = '1' -- Disable
      ELSE
         SET @cDisableQTYField = '0' -- Enable
   END
END

GO