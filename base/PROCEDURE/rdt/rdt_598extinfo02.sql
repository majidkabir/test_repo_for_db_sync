SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598ExtInfo02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show total carton (SSCC) received                                 */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2019-06-24   James     1.0   WMS-9426 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598ExtInfo02]
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

   DECLARE @nReceivedCTN   INT

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nAfterStep = 4 -- SKU
      BEGIN
            SELECT @nReceivedCTN = COUNT( DISTINCT RD.UserDefine01)
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.BeforeReceivedQty > 0

         -- Balance
         SET @cExtendedInfo = N'共刷: ' + CAST( @nReceivedCTN AS NVARCHAR( 5)) + N' 箱'
      END
   END
END

GO