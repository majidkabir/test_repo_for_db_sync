SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523DecodeSP03                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: decode Serialno to SKU                                      */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2023-07-26  1.0  yeekung     WMS-23078 Created                       */ 
/* 2023-10-09  1.1  ivanyi  bug fix INC2178187(ivan01)                  */   
/* 2024-10-24  1.2  ShaoAn      Extended parameter definition           */ 
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_523DecodeSP03
   @nMobile           INT,           
   @nFunc             INT,           
   @cLangCode         NVARCHAR( 3),  
   @nStep             INT,           
   @nInputKey         INT,           
   @cFacility         NVARCHAR( 5),  
   @cStorerKey        NVARCHAR( 15), 
   @cBarcode          NVARCHAR( 60), 
   @cBarcodeUCC       NVARCHAR( 60), 
   @cID               NVARCHAR( 18)  OUTPUT, 
   @cUCC              NVARCHAR( 20)  OUTPUT, 
   @cLOC              NVARCHAR( 10)  OUTPUT, 
   @cSKU              NVARCHAR( 20)  OUTPUT, 
   @nQTY              INT            OUTPUT, 
   @cLottable01       NVARCHAR( 18)  OUTPUT, 
   @cLottable02       NVARCHAR( 18)  OUTPUT, 
   @cLottable03       NVARCHAR( 18)  OUTPUT, 
   @dLottable04       DATETIME       OUTPUT, 
   @nErrNo            INT            OUTPUT, 
   @cErrMsg           NVARCHAR( 20)  OUTPUT    
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTempSKU       NVARCHAR( 20)
   DECLARE @cTempBarcode   NVARCHAR( 60)
   DECLARE @nPosition   INT
   
   SET @nErrNo = 0
            
   IF @nStep = 2 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN

         IF LEN(@cBarcode) >20
         BEGIN
            --HTTP://TY.DOTERRA.CN/F0101DDGDQJDFDEFZ
            SET @cTempBarcode = @cBarcode
            --SET @nPosition = PATINDEX('%A%CN%', @cTempBarcode)
            --SET @cTempBarcode = RIGHT( @cTempBarcode, @nPosition)

            -- (james01)
            SET @cTempBarcode = REPLACE( @cBarcode, 'http://ty.doterra.cn/', '')

            SELECT TOP 1 @cSKU = SKU
            FROM dbo.SerialNo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SerialNo = @cTempBarcode
            ORDER BY 1
         END
         ELSE--ivan01  	
         BEGIN  
            SET @cSKU=@cBarcode  
         END  

      END
   END

Quit:
END

GO