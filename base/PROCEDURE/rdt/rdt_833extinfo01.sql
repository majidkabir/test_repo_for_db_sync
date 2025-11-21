SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_833ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Called from: rdtfnc_PackByCartonID                                   */
/*                                                                      */
/* Purpose: Display carton count                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 2019-04-03 1.0  James      WMS-8119 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_833ExtInfo01] (
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nInputKey    INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerkey   NVARCHAR( 15),
   @cWaveKey     NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @cCaseID      NVARCHAR( 20),
   @cSerialNo    NVARCHAR( 50),
   @cExtendedInfo   NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @fCaseCount  FLOAT

   IF @nFunc = 833 -- Carton Pack
   BEGIN
      IF @nStep = 2 -- SKU/CASE ID/SERIAL NO
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @fCaseCount = PACK.CaseCnt
            FROM dbo.PACK PACK WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            WHERE SKU.Storerkey = @cStorerKey
            AND   SKU.SKU = @cSKU

            SET @cExtendedInfo = 'CASE COUNT:' + CAST( @fCaseCount AS NVARCHAR( 3))
         END
      END
   END

Quit:

END

GO