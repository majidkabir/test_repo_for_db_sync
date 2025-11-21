SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_598ExtInfo03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show total QTY received                                           */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2021-06-23   James     1.0   WMS-17264 Created                             */
/* 2021-10-11   James     1.1   Enhance id qty calculation (james01)          */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598ExtInfo03]
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

   DECLARE @nBeforeReceivedQty      INT
   DECLARE @nQtyExpected            INT
   DECLARE @nID_BeforeReceivedQty   INT
   DECLARE @nID_LLIQty              INT
   
   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nAfterStep = 4 -- SKU
      BEGIN
         --SELECT @cSKU = I_Field02
         --FROM RDT.RDTMOBREC WITH (NOLOCK)
         --WHERE Mobile = @nMobile
         
         SELECT @nBeforeReceivedQty = ISNULL( SUM( RD.BeforeReceivedQty), 0), 
                  @nQtyExpected = ISNULL( SUM( RD.QtyExpected), 0)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         AND   RD.Sku = @cSKU
            
         SELECT @nID_BeforeReceivedQty = ISNULL( SUM( RD.BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         AND   RD.ToId = @cID
         AND   RD.FinalizeFlag <> 'Y'

         SELECT @nID_LLIQty = ISNULL( SUM( LLI.Qty), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         WHERE LLI.StorerKey = @cStorerKey
         AND   EXISTS ( SELECT 1  
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         AND   RD.ToId = LLI.Id
         AND   RD.ToLoc = LLI.Loc
         AND   RD.Sku = LLI.Sku
         AND   RD.FinalizeFlag = 'Y'
         AND   RD.ToId = @cID)
         
         SET @cExtendedInfo = CAST( @nBeforeReceivedQty AS NVARCHAR( 5)) + 
                              '/' + 
                              CAST( @nQtyExpected AS NVARCHAR( 5)) + 
                              ' ID:' + 
                              CAST( (@nID_BeforeReceivedQty + @nID_LLIQty) AS NVARCHAR( 5))
      END
   END
END

GO