SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_510ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 2018-10-23 1.0 James       WMS6778 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_510ExtInfo01] (
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

   DECLARE @cSKU              NVARCHAR( 10),
           @nReplenQty        INT,
           @nCaseCnt          INT,
           @nPackCaseCnt      INT,
           @nPackQtyIndicator INT,
           @nTTL_CS           INT,
           @nTTL_PCS          INT

   IF @nFunc = 510 -- Replen
   BEGIN
      IF @nAfterStep = 3 -- SKU QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Variable mapping
            SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'
            SELECT @nReplenQty = Value FROM @tVar WHERE Variable = '@nQty'

            SELECT @nPackCaseCnt = PACK.CASECNT,
                   @nPackQtyIndicator = SKU.PackQtyIndicator
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PackKey = PACK.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
            AND   SKU.SKU = @cSKU

            IF ISNULL( @nPackCaseCnt, 0) = 0
               SET @nCaseCnt = @nPackQtyIndicator
            ELSE
               SET @nCaseCnt = @nPackCaseCnt

            IF ISNULL( @nCaseCnt, 0) = 0
               GOTO Quit

            SET @nTTL_CS = FLOOR(@nReplenQty / @nCaseCnt)
            SET @nTTL_PCS = @nReplenQty % @nCaseCnt

            SET @cExtendedInfo = 'TTL CS/PCS:' + 
            CAST( IsNULL( @nTTL_CS, 0) AS NVARCHAR( 5)) + 
            '/' +
            CAST( IsNULL( @nTTL_PCS, 0) AS NVARCHAR( 5)) 
         END
      END
   END

Quit:

END

GO