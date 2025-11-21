SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtVal06                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check Multi ID                                                    */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-07-26  James     1.0   WMS-23005. Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_607ExtVal06]
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
   @cReasonCode   NVARCHAR( 5), 
   @cSuggID       NVARCHAR( 18), 
   @cSuggLOC      NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cUDF10      NVARCHAR( 30)
   DECLARE @nQtyExp     INT = 0
   DECLARE @nBefRcvQty  INT = 0
   
   IF @nFunc = 607 -- Return V7
   BEGIN  
      IF @nStep = 1 -- ASN, REF NO
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
         	SELECT @cUDF10 = UserDefine10
         	FROM dbo.RECEIPT WITH (NOLOCK)
         	WHERE ReceiptKey = @cReceiptKey
         	
            IF ISNULL( @cUDF10,'') NOT IN ('SKU','ARTICLE')
            BEGIN  
               SET @nErrNo = 204251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SortMethodReq
               GOTO Quit  
            END
         END
      END

      IF @nStep = 3 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check over receive
            SELECT 
               @nQtyExp = ISNULL( SUM( QtyExpected), 0),
               @nBefRcvQty = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   Sku = @cSKU
            
            IF ( @nBefRcvQty + @nQTY) > @nQtyExp
            BEGIN
               SET @nErrNo = 204252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receive
               GOTO Quit
            END
         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO