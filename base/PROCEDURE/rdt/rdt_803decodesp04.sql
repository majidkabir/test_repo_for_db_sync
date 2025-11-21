SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 /***********************************************************************/  
/* Store procedure: rdt_803DecodeSP04                                   */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2023-08-16  1.1  James       WMS-23379 Created                       */  
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_803DecodeSP04]    (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cStation     NVARCHAR( 10), 
   @cMethod      NVARCHAR( 10), 
   @cBarcode     NVARCHAR( 60), 
   @cUPC         NVARCHAR( 30)   OUTPUT,  
   @nErrNo       INT             OUTPUT,
   @cErrMsg      NVARCHAR( 20)   OUTPUT
)
AS
BEGIN
	DECLARE @cTempBarcode   NVARCHAR( 60)
	
   IF @nStep = 3
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
         IF LEN( @cBarcode) > 20  
         BEGIN  
            --HTTP://TY.DOTERRA.CN/F0101DDGDQJDFDEFZ  
            SET @cTempBarcode = @cBarcode  
  
            SET @cTempBarcode = REPLACE( @cBarcode, 'http://ty.doterra.cn/', '')  
  
            SELECT TOP 1 @cUPC = SKU  
            FROM dbo.SerialNo WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SerialNo = @cTempBarcode  
            ORDER BY 1
         END  
      END  
    END
END

GO