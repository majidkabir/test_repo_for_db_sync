SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_600ExtVal06                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: LOGITECH																		*/
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-08-02 1.0  ChewKP     WMS-5802 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_600ExtVal06] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
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
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPackKey NVARCHAR(10) 
          ,@nPallet  INT
          ,@dLLILottable04 DATETIME


   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 6 -- Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            
            SELECT TOP 1 @dLLILottable04 = LA.Lottable04 
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
            WHERE LLI.StorerKey = @cStorerKey 
            AND LLI.SKU = @cSKU 
            AND LLI.QTY > 0 
            ORDER BY LA.Lottable04 DESC
            
            IF @dLLILottable04 > @dLottable04 
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                               WHERE ReceiptKey = @cReceiptKey
                               AND StorerKey = @cStorerKey
                               AND DocType = 'A'
                               AND LEN(Notes) > 0 )
               BEGIN
                  SET @nErrNo = 127201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ReverseExpDate
                  GOTO Fail
               END
            END
                   
         END   -- ENTER
      END      -- Qty
   END         -- Normal receiving

   Fail:
   Quit:


GO