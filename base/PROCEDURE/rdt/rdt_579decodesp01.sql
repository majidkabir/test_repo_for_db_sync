SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_579DecodeSP01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Sort full case                                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-23 1.0  Ung      WMS-4202 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_579DecodeSP01] (
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cStorerKey   NVARCHAR( 15),   
   @cFacility    NVARCHAR( 5),    
   @cBarcode     NVARCHAR( 2000), 
   @cUCCNo       NVARCHAR( 20)  OUTPUT,   
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT
   DECLARE @nCaseCNT FLOAT
   DECLARE @cUPC     NVARCHAR( 30)
   
   SET @cUPC = LEFT( @cBarcode, 30)
  
   -- Get SKU
   EXEC rdt.rdt_GetSKU
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC      OUTPUT
      ,@bSuccess    = @bSuccess  OUTPUT
      ,@nErr        = @nErrNo    OUTPUT
      ,@cErrMsg     = @cErrMsg   OUTPUT
   
   IF @nErrNo <> 0 OR @bSuccess <> 1
   BEGIN
      SET @cSKU = @cUPC

      SELECT @nCaseCNT = CaseCNT 
      FROM SKU WITH (NOLOCK) 
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey 
         AND SKU.SKU = @cSKU

      IF @nCaseCNT > 0
         SET @nQTY = CAST( @nCaseCNT AS INT)
   END
END

GO