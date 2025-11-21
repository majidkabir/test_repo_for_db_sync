SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_Receiving_Label_12_RP                              */
/* Purpose: SKU label                                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-08-11 1.0  Ung      SOS318064 Created                              */
/***************************************************************************/

CREATE PROC [dbo].[isp_Receiving_Label_12_RP] (
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
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cPickLOC    NVARCHAR( 10)
   DECLARE @cAisle      NVARCHAR( 10)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cAltSKU     NVARCHAR( 20)
   DECLARE @cFromID     NVARCHAR( 18)  
   DECLARE @cDateTime   NVARCHAR( 16)
   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   
   SET @cReceiptKey        = @cByRef1
   SET @cReceiptLineNumber = @cByRef2
   SET @cPickLOC           = @cByRef4 
   SET @cUserName          = LEFT( SUSER_SNAME(), 18)
   SET @cDateTime          = CONVERT(NVARCHAR, GETDATE(), 111) + ' ' + LEFT(CONVERT(NVARCHAR, GETDATE(), 114), 5) -- YYYY/MM/DD HH:MM
   SET @cSKU               = ''
   SET @cAltSKU            = ''
   SET @cFromID            = ''
   SET @cAisle             = ''

   -- Get receipt info
   SELECT 
      @cSKU = SKU, 
      @cFromID = ToID
   FROM ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey 
      AND ReceiptLineNumber = @cReceiptLineNumber
   
   -- Get SKU Info
   SELECT @cAltSKU = ISNULL( AltSKU, '') FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU 
   
   -- Get LOCAisle
   SELECT @cAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @cPickLOC

   --Replace Template Start 
   /*
   ^XA  ^SZ2^JMA  ^MCY^PMN  ^PW316  ~JSN  ^JZY  ^LH0,0^LRN  ^XZ  ^XA  ^FT152,265  ^CI0  ^A0N,28,19^FD<Field07>^FS  ^ISR:SS_TEMP.GRF,N^XZ  ^XA  ^ILR:SS_TEMP.GRF^FS  ^FT38,265  ^A0N,28,27^FD<Field05>^FS  ^FT25,79  ^A0N,34,23^FD<Field01>^FS  ^FT38,240  ^A0N,28,20^FD<Field04>^FS  ^FT27,41  ^A0N,34,23^FD<Field03>^FS  ^FT276,43  ^A0N,51,29^FD<Field08>^FS  ^FT56,164  ^A0N,34,23^FD<Field06>^FS  ^PQ1,0,1,Y  ^XZ  ^XA  ^IDR:SS_TEMP.GRF^XZ
   */   

   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cAltSKU))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cPickLOC))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cReceiptKey))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cUserName))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', RTRIM( @cFromID))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', RTRIM( @cDateTime))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field08>', RTRIM( @cAisle)) 
   
   SET @cPrintData = @cPrintTemplate  

GO