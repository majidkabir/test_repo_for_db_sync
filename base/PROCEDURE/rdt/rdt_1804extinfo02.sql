SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1804ExtInfo02                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 27-04-2018 1.0 Ung         WMS-4665 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1804ExtInfo02] (
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

   IF @nFunc = 1804 -- Move to UCC
   BEGIN
      IF @nAfterStep IN (5, 6) -- SKU
      BEGIN
         -- Variable mapping
         DECLARE @cSKU        NVARCHAR(20),
                 @nCaseCnt    INT

         SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'

         IF @cSKU <> ''
         BEGIN
            SELECT @nCaseCnt = CaseCnt
            FROM dbo.Pack Pack WITH (NOLOCK) 
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( Pack.PackKey = SKU.PackKey)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cSKU

            SET @cExtendedInfo = 'CaseCnt: ' + CAST( @nCaseCnt AS NVARCHAR(5))
         END
      END
   END

Quit:

END

GO