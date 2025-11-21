SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620PromptDrop02                                */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: If loc.loseid = 0 then go back drop id screen               */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 10-03-2023   1.0  James       WMS-21711. Created                     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1620PromptDrop02] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cLoc                      NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @nPromptDropIDScn          INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility      NVARCHAR( 5)

   SET @nPromptDropIDScn = 0

   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Always prompt Drop Id screen
         SET @nPromptDropIDScn = 1
      END
   END

   Quit:
END

GO