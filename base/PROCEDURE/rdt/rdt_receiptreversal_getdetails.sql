SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_ReceiptReversal_GetDetails                      */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next receipt detail lines to display                    */  
/*          Group by asn, id (if keyed in) & lottables                  */
/*                                                                      */
/* Called from: rdtfnc_Receipt_Reversal                                 */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 28-Jul-2015 1.0  James       SOS338503 - Created                     */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_ReceiptReversal_GetDetails] (  
   @nMobile                INT, 
   @nFunc                  INT, 
   @cLangCode              NVARCHAR( 3),  
   @nScn                   INT, 
   @nInputKey              INT, 
   @cStorerKey             NVARCHAR( 15),  
   @cReceiptKey            NVARCHAR( 10),  
   @cFacility              NVARCHAR( 5),  
   @cID                    NVARCHAR( 18),  
   @cSKU                   NVARCHAR( 20)      OUTPUT,  
	@cLottable1Value        NVARCHAR( 20)      OUTPUT,
	@cLottable2Value        NVARCHAR( 20)      OUTPUT,
   @cLottable3Value        NVARCHAR( 20)      OUTPUT,
   @cLottable4Value        NVARCHAR( 20)      OUTPUT,
   @cLottable5Value        NVARCHAR( 20)      OUTPUT,
   @cReceiptLineNumber     NVARCHAR( 5)       OUTPUT,
   @nQty                   INT                OUTPUT,
   @nErrNo                 INT                OUTPUT,   
   @cErrMsg                NVARCHAR( 20)      OUTPUT 
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
   @nLoop               INT,
   @cOutField           NVARCHAR( 60), 
   @cLot01              NVARCHAR( 30), 
   @cLot02              NVARCHAR( 20), 
   @cLot03              NVARCHAR( 20), 
   @cLot04              NVARCHAR( 20), 
   @cLot05              NVARCHAR( 20), 
   @cLottableCode       NVARCHAR( 30), 
   @nMorePage           INT, 
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME, 
   @dLottable05         DATETIME, 
   @cLottable06         NVARCHAR( 30), 
   @cLottable07         NVARCHAR( 30), 
   @cLottable08         NVARCHAR( 30), 
   @cLottable09         NVARCHAR( 30), 
   @cLottable10         NVARCHAR( 30), 
   @cLottable11         NVARCHAR( 30), 
   @cLottable12         NVARCHAR( 30), 
   @dLottable13         DATETIME, 
   @dLottable14         DATETIME, 
   @dLottable15         DATETIME, 
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60), 
   @cFieldAttr01 NVARCHAR( 1),  @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1),  @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1),  @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1),  @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1),  @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1),  @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1),  @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1) 

   DECLARE @cExecStatements  NVARCHAR( 4000),  
           @cExecArguments   NVARCHAR( 4000) 

   DECLARE @b_debug INT , @cNewSKU nvarchar( 20)

   --if suser_sname() = 'jameswong' or suser_sname() = 'wmsgt'
   --   SET @b_debug = 1

   SET @cNewSKU = ''
   SET @nQty = 0

   -- Get 1st receiptdetail record
   IF ISNULL( @cSKU, '') = ''
      SELECT TOP 1 
         @cNewSKU = SKU, 
         @cReceiptLineNumber = ReceiptLineNumber, 
         @nQty = ISNULL( CASE WHEN FinalizeFlag <> 'Y' THEN BeforeReceivedQty ELSE QtyReceived END, 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   ToID = CASE WHEN ISNULL( @cID, '') = '' THEN ToID ELSE @cID END
      AND   ( BeforeReceivedQty > 0 OR QtyReceived > 0)
      ORDER BY SKU, ReceiptLineNumber 
   ELSE
      -- pass in with sku then check for same sku different line#
      SELECT TOP 1 
         @cNewSKU = SKU, 
         @cReceiptLineNumber = ReceiptLineNumber, 
         @nQty = ISNULL( CASE WHEN FinalizeFlag <> 'Y' THEN BeforeReceivedQty ELSE QtyReceived END, 0) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   ToID = CASE WHEN ISNULL( @cID, '') = '' THEN ToID ELSE @cID END
      AND   SKU = @cSKU
      AND   ReceiptLineNumber > @cReceiptLineNumber
      AND   ( BeforeReceivedQty > 0 OR QtyReceived > 0)
      ORDER BY ReceiptLineNumber 

   -- If same sku no more next line#, go for next sku
   IF ISNULL( @cNewSKU, '') = ''
      SELECT TOP 1 
         @cNewSKU = SKU, 
         @cReceiptLineNumber = ReceiptLineNumber, 
         @nQty = ISNULL( CASE WHEN FinalizeFlag <> 'Y' THEN BeforeReceivedQty ELSE QtyReceived END, 0) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   ToID = CASE WHEN ISNULL( @cID, '') = '' THEN ToID ELSE @cID END
      AND   SKU > @cSKU
      AND   ( BeforeReceivedQty > 0 OR QtyReceived > 0)
      ORDER BY SKU, ReceiptLineNumber 

   -- No record found
   IF ISNULL( @cNewSKU, '') = ''
   BEGIN
      SET @cSKU = ''
      GOTO Quit
   END
   ELSE
      SET @cSKU = @cNewSKU

   SELECT 
      @cLottable01 = Lottable01, 
      @cLottable02 = Lottable02, 
      @cLottable03 = Lottable03, 
      @dLottable04 = Lottable04, 
      @dLottable05 = Lottable05, 
      @cLottable06 = Lottable06, 
      @cLottable07 = Lottable07, 
      @cLottable08 = Lottable08, 
      @cLottable09 = Lottable09, 
      @cLottable10 = Lottable10, 
      @cLottable11 = Lottable11, 
      @cLottable12 = Lottable12, 
      @dLottable13 = Lottable13, 
      @dLottable14 = Lottable14, 
      @dLottable15 = Lottable15  
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   ReceiptLineNumber = @cReceiptLineNumber

   SELECT @cLottableCode = LottableCode
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   -- Dynamic lottable
   EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 7, 
      @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
      @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
      @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
      @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
      @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
      @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
      @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
      @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
      @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
      @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
      @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
      @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
      @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
      @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
      @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
      @nMorePage   OUTPUT,
      @nErrNo      OUTPUT,
      @cErrMsg     OUTPUT,
      '',      -- SourceKey
      @nFunc   -- SourceType

   SET @cLottable1Value = @cOutField07
   SET @cLottable2Value = @cOutField08
   SET @cLottable3Value = @cOutField09
   SET @cLottable4Value = @cOutField10
   SET @cLottable5Value = @cOutField11

   Quit:
END 

GO