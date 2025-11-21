SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtInfo07                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-07-12   Ung       1.0   WMS-22834 Show style color size         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1812ExtInfo07]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nAfterStep = 4   -- SKU, QTY
      BEGIN
         DECLARE @cStyle NVARCHAR( 20)
         DECLARE @cColor NVARCHAR( 10)
         DECLARE @cSize  NVARCHAR( 10)

         -- Get task info
         SELECT 
            @cStyle = SKU.Style, 
            @cColor = SKU.Color, 
            @cSize = ISNULL( SKU.Size, '')
         FROM dbo.TaskDetail TD WITH (NOLOCK)
            JOIN dbo.SKU WITH (NOLOCK) ON (TD.StorerKey = SKU.StorerKey AND TD.SKU = SKU.SKU)
         WHERE TaskDetailKey = @cTaskDetailKey
         
         SET @cExtendedInfo1 = LEFT( TRIM( @cStyle)  + '-' + TRIM( @cColor) + ' ' + TRIM( @cSize), 20)
      END
   END
END

GO