SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCCLabel01_RP                                  */
/*                                                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  UCC label                                                  */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 18-Apr-2018  James   1.0   WMS4665. Created                          */
/************************************************************************/
CREATE PROC [dbo].[isp_UCCLabel01_RP] (
   @nMobile     INT,   
   @nFunc       INT,   
   @cLangCode   NVARCHAR( 3),   
   @cStorerKey  NVARCHAR( 15),   
   @cByRef1     NVARCHAR( 20),   
   @cByRef2     NVARCHAR( 20),   
   @cByRef3     NVARCHAR( 20),   
   @cByRef4     NVARCHAR( 20),   
   @cByRef5     NVARCHAR( 20),   
   @cByRef6     NVARCHAR( 20),   
   @cByRef7     NVARCHAR( 20),   
   @cByRef8     NVARCHAR( 20),   
   @cByRef9     NVARCHAR( 20),   
   @cByRef10    NVARCHAR( 20),   
   @cPrintTemplate NVARCHAR( MAX),   
   @cPrintData  NVARCHAR( MAX) OUTPUT,  
   @nErrNo      INT            OUTPUT,  
   @cErrMsg     NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max     
) 
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSKU           NVARCHAR( 20), 
           @cLOC           NVARCHAR( 10), 
           @cStyle         NVARCHAR( 20),
           @cColor         NVARCHAR( 10),
           @cSize          NVARCHAR( 10),
           @cBUSR1         NVARCHAR( 30),
           @cMeasurement   NVARCHAR( 5),
           @nQty           INT

   SET @cPrintData = ''

   -- Get UCC info
   SELECT @nQty = ISNULL( SUM( Qty), 0)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cByRef1
   AND   SKU = @cByRef2
   AND   LOC = @cByRef3
   AND   StorerKey = @cStorerKey
   AND   [Status] < 6

   SELECT @cBUSR1 = BUSR1,
          @cStyle = Style,
          @cColor = Color,
          @cSize = Size,
          @cMeasurement = Measurement
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cByRef2

   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cByRef3))   -- LOC
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cStyle))    -- STYLE
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cBUSR1))    -- BUSR1
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cColor))    -- COLOR
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cSize))     -- SIZE
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', RTRIM( @cMeasurement))  -- MEASUREMENT
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', RTRIM( @nQty))      -- QTY
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field08>', RTRIM( @cByRef2))   -- SKU
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field09>', RTRIM( @cByRef1))   -- UCCNO

   IF ISNULL( @cPrintTemplate, '') <> ''
      SET @cPrintData = @cPrintTemplate  

END

GO