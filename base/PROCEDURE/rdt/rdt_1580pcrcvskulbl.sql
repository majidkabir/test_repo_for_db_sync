SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1580PCRcvSKULBL                                 */  
/* Copyright      : LF logistics                                        */  
/*                                                                      */  
/* Purpose: Call from RDT piece receiving, SKULabelSP                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author      Purposes                                */  
/* 19-03-2015  1.0  James       SOS333459. Created                      */  
/* 26-08-2015  1.1  James       SOS350478 - Get No of label to print    */  
/*                              from Qty (james01)                      */
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1580PCRcvSKULBL]  
    @nMobile            INT  
   ,@nFunc              INT  
   ,@nStep              INT  
   ,@cLangCode          NVARCHAR( 3)  
   ,@cStorerKey         NVARCHAR( 15)  
   ,@cDataWindow        NVARCHAR( 60)  
   ,@cPrinter           NVARCHAR( 10)  
   ,@cTargetDB          NVARCHAR( 20)  
   ,@cReceiptKey        NVARCHAR( 10)   
   ,@cReceiptLineNumber NVARCHAR( 5)   
   ,@nQTY               INT  
   ,@nErrNo             INT           OUTPUT   
   ,@cErrMsg            NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nCaseQTY       INT, 
           @nNo_Of_Copy    INT, 
           @cCaseQTY       NVARCHAR( 10), 
           @cNo_Of_Copy    NVARCHAR( 20), 
           @cSKU           NVARCHAR( 20) 

   SELECT @cSKU = SKU 
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey 
   AND   ReceiptLineNumber = @cReceiptLineNumber 

   SELECT @cCaseQTY = V_LoadKey FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF rdt.rdtIsValidQty( @cCaseQTY, 1) = 0
      GOTO Quit

   SET @nCaseQTY = CAST( @cCaseQTY AS INT)
   
   IF @nCaseQTY = 0 OR ISNULL( @cSKU, '') = ''
      GOTO Quit

   SET @nNo_Of_Copy = @nQTY/@nCaseQTY
   
   IF @nNo_Of_Copy = 0 
      GOTO Quit
   
   EXEC RDT.rdt_BuiltPrintJob  
      @nMobile,  
      @cStorerKey,  
      'SKULABEL',       -- ReportType  
      'PRINT_SKULABEL', -- PrintJobName  
      @cDataWindow,  
      @cPrinter,  
      @cTargetDB,  
      @cLangCode,  
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT,  
      @cStorerKey,  
      @cSKU, 
      @nQTY,
      @nNo_Of_Copy 
   
   -- Reset back the case count from piece receiving
   IF @nErrNo = 0
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET 
         V_LoadKey = '' 
      WHERE Mobile = @nMobile

   Quit:  
END  

GO