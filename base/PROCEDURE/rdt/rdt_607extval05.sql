SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtVal05                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check Multi ID                                                    */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 12-05-2022  YeeKung    1.0   WMS-19558 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtVal05]
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
   
   IF @nFunc = 607 -- Return V7
   BEGIN  

      IF @nStep = 5 -- ID, LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF ISNULL(@cID,'') =''
            BEGIN  
               SET @nErrNo = 186601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
               GOTO Quit  
            END


            IF EXISTS (SELECT 1
                       FROM RECEIPTDETAIL (NOLOCK)
                       WHERE receiptkey=@cReceiptKey
                       AND TOID =@cID
                       AND SKU <>@cSKU)
            BEGIN  
               SET @nErrNo = 186602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
               GOTO Quit  
            END

         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO