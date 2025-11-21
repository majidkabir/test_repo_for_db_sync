SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtInfo04                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 04-10-2021   Chermaine 1.0   WMS-18067 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_600ExtInfo04]
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
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cSKU          NVARCHAR( 20), 
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
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
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

   IF @nFunc = 600 -- Normal receive v7
   BEGIN
      IF @nStep = 5 -- Lottable
      BEGIN
         DECLARE @cSUSR2   NVARCHAR( 18)
         DECLARE @dLot04   DATETIME
         DECLARE @cErrMsg1 NVARCHAR( 125)
         DECLARE @cErrMsg2 NVARCHAR( 125)
         
         SET @cErrMsg1 = '' 
         SET @cErrMsg2 = ''
         
         IF @cLottable03 > GETDATE()
         BEGIN
         	SET @cErrMsg1 = rdt.rdtgetmessage( '176451', @cLangCode,'DSP')--'InvProdDate'
         END

         SELECT @dLot04 = Lottable04 FROM dbo.RECEIPTDETAIL WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cReceiptKey
         SELECT @cSUSR2 = SUSR2 FROM SKU WITH (NOLOCK) WHERE storerKey = @cStorerKey AND sku = @cSKU
         
         IF ABS((DATEDIFF(day,GETDATE(), @dLottable04))) < @cSUSR2 OR (@dLottable04 < GETDATE())
         BEGIN
         	SET @cErrMsg2 = rdt.rdtgetmessage( '176452', @cLangCode,'DSP')--'SKU>SSD'
         END
                  
         IF @cErrMsg1 <> '' OR @cErrMsg2 <> ''
         BEGIN
         	SET @nErrNo = 0
         	EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         END
         
      
      END
   END

Quit:

END

GO