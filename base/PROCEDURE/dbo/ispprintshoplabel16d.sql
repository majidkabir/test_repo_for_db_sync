SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPrintShopLabel16d                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Build IDX Shop Label No with 16 digits (with check digits)  */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2014-04-02 1.0  James    SOS307345 Created                           */   
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispPrintShopLabel16d]  
   @cLoadKey      NVARCHAR( 10),   
   @cLabelType    NVARCHAR( 10),   
   @cStorerKey    NVARCHAR( 15),  
   @cDistCenter   NVARCHAR( 5),  
   @cShopNo       NVARCHAR( 5),  
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
   SET @cTempBarcodeFrom = SUBSTRING(@cDistCenter, 1, 4)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '0000' + RTRIM(LTRIM(@cShopNo)), 4)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSection, 1, 1)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSeparate, 1, 1)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)
   SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcodeFrom), 0)
   SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + @cCheckDigit

   IF ISNULL( @cTempBarcodeFrom, '') <> ''
      SET @cLabelNo = @cTempBarcodeFrom
   ELSE
      SET @bSuccess = 0


QUIT:  
END -- End Procedure  

GO