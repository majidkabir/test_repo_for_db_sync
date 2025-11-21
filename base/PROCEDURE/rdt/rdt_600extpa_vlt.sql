SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtPA_VLT                                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Extended putaway for VLT                                          */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2024-10-31   Dennis    1.0   FCR-632 Created                               */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_600ExtPA_VLT]
 @nMobile      INT, 
 @nFunc        INT, 
 @cLangCode    NVARCHAR( 3),   
 @nStep        INT, 
 @nInputKey    INT, 
 @cStorerKey   NVARCHAR( 15),  
 @cReceiptKey  NVARCHAR( 10),  
 @cPOKey       NVARCHAR( 10),  
 @cLOC         NVARCHAR( 10),  
 @cID          NVARCHAR( 18),  
 @cSKU         NVARCHAR( 20),  
 @nQTY         INT, 
 @cLottable01  NVARCHAR( 18),  
 @cLottable02  NVARCHAR( 18),  
 @cLottable03  NVARCHAR( 18),  
 @dLottable04  DATETIME,       
 @dLottable05  DATETIME,       
 @cLottable06  NVARCHAR( 30),  
 @cLottable07  NVARCHAR( 30),  
 @cLottable08  NVARCHAR( 30),  
 @cLottable09  NVARCHAR( 30),  
 @cLottable10  NVARCHAR( 30),  
 @cLottable11  NVARCHAR( 30),  
 @cLottable12  NVARCHAR( 30),  
 @dLottable13  DATETIME,       
 @dLottable14  DATETIME,       
 @dLottable15  DATETIME,       
 @cPutaway     NVARCHAR( 1)   OUTPUT,  
 @nErrNo       INT OUTPUT,  
 @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @cFindPutawayLoc NVARCHAR(1),
   @cFacility NVARCHAR(5),
   @cReceiptLineNumber NVARCHAR(5),
   @nPABookingKey       INT,
   @cSuggToLOC    NVARCHAR( 20)

   SELECT @cFacility = Facility FROM RDT.RDTMOBREC WHERE Mobile = @nMobile
   SET @cFindPutawayLoc = rdt.RDTGetConfig( @nFunc, 'FindPutawayLoc', @cStorerKey)

   SELECT TOP 1
      @cReceiptLineNumber = ReceiptLineNumber
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE Sku = @cSKU AND StorerKey = @cStorerKey AND ToId = @cID AND ReceiptKey = @cReceiptKey
   ORDER BY ReceiptLineNumber,EditDate DESC

   IF @nFunc = 600 -- RECEIVE v7
   BEGIN
      IF @cFindPutawayLoc = '1'
      BEGIN
         SET @cPutaway = 'N'
         -- Suggest LOC
         EXEC rdt.rdt_NormalReceipt_Putaway_VLT @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SUGGEST',
            @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReceiptLineNumber--RECEIPT LINE NUMBER
            , '',
            @cSuggToLOC    OUTPUT,
            @nPABookingKey OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF


GO