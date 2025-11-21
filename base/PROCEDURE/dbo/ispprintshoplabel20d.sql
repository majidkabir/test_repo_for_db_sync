SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPrintShopLabel20d                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Build IDX Shop Label No with 20 digits (no check digits)    */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2014-04-02 1.0  James    SOS307345 Created                           */   
/* 2014-10-28 1.1  James    SOS324404 Extend var length (james01)       */   
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispPrintShopLabel20d]  
   @cLoadKey      NVARCHAR( 10),   
   @cLabelType    NVARCHAR( 10),   
   @cStorerKey    NVARCHAR( 15),  
   @cDistCenter   NVARCHAR( 6),  -- (james01)
   @cShopNo       NVARCHAR( 6),  -- (james01)
   @cSection      NVARCHAR( 5),  
   @cSeparate     NVARCHAR( 5),  
   @nBultoNo      INT,  
   @cLabelNo      NVARCHAR(20)   OUTPUT,  
   @bSuccess      INT            OUTPUT, 
   @nErrNo        INT            OUTPUT,   
   @cErrMsg       NVARCHAR(20)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cTempBarcodeFrom    NVARCHAR( 20), 
           @cCheckDigit         NVARCHAR( 1) 
   
   SET @bSuccess = 1

   SET @cTempBarcodeFrom = ''
   SET @cTempBarcodeFrom = '3'
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '000000' + RTRIM(LTRIM(@cDistCenter)), 6)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '000000' + RTRIM(LTRIM(@cShopNo)), 6)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSection, 1, 1)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSeparate, 1, 1)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)

   IF ISNULL( @cTempBarcodeFrom, '') <> ''
      SET @cLabelNo = @cTempBarcodeFrom
   ELSE
      SET @bSuccess = 0


QUIT:  
END -- End Procedure  

GO