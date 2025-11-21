SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_SKULabel11_RP                                  */
/* Copyright: LF logistics                                              */
/*                                                                      */
/* Purpose:  Receiving SKU label                                        */
/*                                                                      */
/* Date         Author  Ver   Purposes                                  */
/* 06-May-2020  Ung     1.0   WMS-13140 Created                         */
/* 18-May-2021  Chermain1.1   WMS-16328 Change suggestLoc (cc01)        */
/* 04-Jul-2022  Ung     1.2   WMS-19596 Add new mapping                 */
/************************************************************************/
CREATE   PROC [dbo].[isp_SKULabel11_RP] (
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

   DECLARE @cReceiptKey        NVARCHAR( 10)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   DECLARE @cSKU               NVARCHAR( 20)
   DECLARE @cUDF09             NVARCHAR( 10)
   DECLARE @cToLOC             NVARCHAR( 10)
   DECLARE @cLottable01        NVARCHAR( 18)
   DECLARE @nPackQTYIndicator  INT
   DECLARE @nRowRef            INT
   DECLARE @nBeforeRecQty      INT
   DECLARE @nSKUQTY            INT --(cc01)
   DECLARE @cPackKey           NVARCHAR( 10)
   DECLARE @nCaseCNT           INT
   DECLARE @cSuggestedLOC      NVARCHAR( 10)
   DECLARE @cBUSR5             NVARCHAR( 30)
   DECLARE @cRetailSKU         NVARCHAR( 20)
   DECLARE @cUDF02             NVARCHAR( 60)  --(ZOE)  
   DECLARE @cUDF03             NVARCHAR( 60)
   DECLARE @cPaBookingkey      NVARCHAR( 20)  -- (yeekUng01)  
   SET @cPrintData = ''

   -- Parameter mapping
   SET @cReceiptKey = @cByRef1
   SET @cReceiptLineNumber = @cByRef2
   SET @nSKUQTY = @cByRef3  --(cc01)

   -- Get receipt info
   DECLARE @cProcessType NVARCHAR(1)
   DECLARE @cDTOWProcess NVARCHAR(5)
   SELECT 
      @cProcessType = ISNULL( ProcessType, ''),
      @cDTOWProcess = UserDefine03
   FROM Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   IF @cProcessType = 'N'
   BEGIN
      IF @cDTOWProcess = 'DT'
      BEGIN
         SELECT 
            @cSKU = SKU, 
            @cUDF09 = UserDefine09, 
            @cToLOC = ToLOC, 
            @cLottable01 = Lottable01
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber

         ---GET RFPUTAWAY.UDF02/UDF03 by zoe    
         SET @cUDF02 = '-'  
         SET @cUDF03  ='-'   
      END
      ELSE
      BEGIN
         -- Get Receipt detail info    --(cc01)     
         SELECT TOP 1  
            @cSKU = RD.SKU, 
            @cUDF09 = RP.SuggestedLoc, 
            @cToLOC = RD.ToLOC, 
            @cLottable01 = RD.Lottable01,
            @nRowRef = RP.RowRef,
            @nBeforeRecQty = RD.BeforeReceivedQty,  
            @cPaBookingkey = userdefine10  
         FROM ReceiptDetail RD WITH (NOLOCK)
         JOIN RFPutaway RP WITH (NOLOCK) ON (RD.StorerKey = RP.StorerKey AND RD.UserDefine10 = RP.PABookingKey AND RD.SKU = RP.SKU)
         WHERE RD.ReceiptKey = @cReceiptKey
            AND RD.ReceiptLineNumber = @cReceiptLineNumber    
            AND qtyprinted<>0
            AND RP.CaseID <> 'Close Pallet'
         ORDER BY RP.rowref  desc          

          ---GET RFPUTAWAY.UDF02/UDF03 by zoe
         SELECT TOP 1
            @cUDF02 = UDF02,
            @cUDF03 = ISNULL( UDF03,'')
         FROM RFPutaway WITH (NOLOCK)
         WHERE PABookingKey= @cPABookingKey
            AND SuggestedLOC = @cUDF09
            AND (ISNULL( UDF02, '') <> '' OR ISNULL( UDF03, '') <> '')

         SET @cUDF02 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN '-' ELSE @cUDF02 END
      END
      
      -- Get SKU info
      SELECT 
         @cPackKey = PackKey, 
         @nPackQTYIndicator = PackQTYIndicator, 
         @cBUSR5 = ISNULL( BUSR5, ''), 
         @cRetailSKU = ISNULL( RetailSKU, '')
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      -- Get pack key info
      SELECT @nCaseCNT = CAST( CaseCNT AS INT)
      FROM Pack WITH (NOLOCK)
      WHERE PackKey = @cPackKey
      
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', SUBSTRING( RTRIM( @cUDF09), 1, 3))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', SUBSTRING( RTRIM( @cUDF09), 4, 3))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', SUBSTRING( RTRIM( @cUDF09), 7, 2))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', SUBSTRING( RTRIM( @cUDF09), 9, 1))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', SUBSTRING( RTRIM( @cUDF09), 10, 1))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', RTRIM( @cToLOC))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field08>', RTRIM( @cLottable01))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field09>', RIGHT( SUSER_SNAME(), 4))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field10>', RTRIM( CAST( @nPackQTYIndicator AS NVARCHAR(2))))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field11>', RTRIM( @cPackKey))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field12>', RTRIM( CAST( @nCaseCNT AS NVARCHAR(3))))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field13>', RTRIM( @cBUSR5))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field14>', RTRIM( @cDTOWProcess))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field15>', RTRIM( @cUDF02))        
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field16>', RTRIM( @cUDF03))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field17>', SUBSTRING( RTRIM( @cSKU), 1, 6))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field18>', SUBSTRING( RTRIM( @cSKU), 7, 3))
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field19>', SUBSTRING( RTRIM( @cSKU), 10, 6))

      SET @cPrintData = ISNULL(@cPrintTemplate,'')  
   END
   ELSE
      SET @nErrNo = -1 -- No print and skip err message
END

GO