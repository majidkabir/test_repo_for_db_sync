SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805ExtInfo02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 17-07-2017 1.0 Ung         WMS-2402 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_805ExtInfo02] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU NVARCHAR(20)

   IF @nFunc = 805 -- PTLStation
   BEGIN
      IF @nAfterStep = 4 -- Matrix
      BEGIN
         -- Variable mapping
         SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'

         SET @cExtendedInfo = @cSKU
      END
   END

Quit:

END

GO