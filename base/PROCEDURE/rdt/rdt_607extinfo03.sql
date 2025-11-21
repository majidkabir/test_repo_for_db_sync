SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_607ExtInfo03                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Show balance QTY                                            */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 28-03-2018  1.0  ChewKP       WMS-3836. Created                      */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_607ExtInfo03]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT,           
   @cLottable01   NVARCHAR( 18), 
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME,      
   @dLottable05   DATETIME,      
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME,      
   @dLottable14   DATETIME,      
   @dLottable15   DATETIME,      
   @cReasonCode   NVARCHAR( 10), 
   @cSuggToID     NVARCHAR( 18), 
   @cSuggToLOC    NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @cExtendedInfo NVARCHAR(20)  OUTPUT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTotalQtyExpected INT
          ,@nTotalReceivedQty INT

   IF @nFunc = 607 -- Return V7
   BEGIN
      IF @nStep = 2 -- QTY
      BEGIN
         SELECT @nTotalQtyExpected = SUM(QtyExpected)
               ,@nTotalReceivedQty = SUM(BeforeReceivedQty)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey 
         AND SKU = @cSKU 
         
            
         SET @cExtendedInfo =  'TTL SCAN:' + CAST( @nTotalReceivedQty AS NVARCHAR(4)) + '/'+ CAST( @nTotalQtyExpected AS NVARCHAR(4))
      END
   END
   
Quit:
   
END

GO