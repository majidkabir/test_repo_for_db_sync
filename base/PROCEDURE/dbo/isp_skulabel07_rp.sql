SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel07_RP                                  */
/*                                                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Receiving SKU label                                        */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 23-Jan-2018  James   1.0   WMS3658. Created                          */
/* 30-Apr-2018  Ung     1.1   WMS-4684 Change mapping Field09 to L01    */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel07_RP] (
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

   DECLARE @cSKU          NVARCHAR( 20), 
           @cToID         NVARCHAR( 18),
           @cLottable01   NVARCHAR( 18), 
           @cLottable03   NVARCHAR( 18),
           @cBUSR10       NVARCHAR( 30) 

   SET @cPrintData = ''

   -- Get ReceiptDetail info
   SELECT
      @cToID = ToID,
      @cSKU = SKU,
      @cLottable01 = Lottable01, 
      @cLottable03 = Lottable03
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cByRef1
   AND   ReceiptLineNumber = @cByRef2

   SELECT @cBUSR10 = BUSR10
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cBUSR10))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', SUBSTRING( RTRIM( @cLottable03), 1, 3))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', SUBSTRING( RTRIM( @cLottable03), 4, 3))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', SUBSTRING( RTRIM( @cLottable03), 7, 2))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', SUBSTRING( RTRIM( @cLottable03), 9, 1))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', SUBSTRING( RTRIM( @cLottable03), 10, 1))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', SUBSTRING( RTRIM( @cToID), 1, 7))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field08>', SUBSTRING( RTRIM( @cToID), 8, 4))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field09>', RTRIM( @cLottable01))  

   IF ISNULL( @cPrintTemplate, '') <> ''
      SET @cPrintData = @cPrintTemplate  

END

GO