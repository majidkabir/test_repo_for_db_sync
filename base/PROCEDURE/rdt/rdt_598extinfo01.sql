SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 23-Aug-2015  Ung       1.0   SOS347636 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598ExtInfo01]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cRefNo        NVARCHAR( 20), 
   @cColumnName   NVARCHAR( 20), 
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
   @cReceiptKey   NVARCHAR( 10), 
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

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nAfterStep = 6 -- QTY
      BEGIN
         -- Get SKU info
         DECLARE @fCaseCnt FLOAT
         SELECT @fCaseCnt = CaseCnt
         FROM SKU WITH (NOLOCK) 
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         
         -- Get balance QTY
         DECLARE @nBal INT
         SELECT @nBal = ISNULL( SUM( RD.QTYExpected - RD.BeforeReceivedQTY), 0)
         FROM ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
         WHERE Mobile = @nMobile
            AND RD.StorerKey = @cStorerKey
            AND RD.SKU = @cSKU
         
         -- Over received
         IF @nBal < 0
            SET @nBal = 0

         -- Balance
         SET @cExtendedInfo = 
            N'µ£¬µö╢:' + CAST( @nBal AS NVARCHAR(6)) + SPACE(1) + 
            N'σàÑµò╕:' + CAST( @fCaseCnt AS NVARCHAR(5))
      END
   END
END

GO