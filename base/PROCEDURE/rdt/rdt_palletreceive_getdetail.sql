SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PalletReceive_GetDetail                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive ASN by pallet ID                                          */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2015-09-04 1.0  Ung        SOS347636 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PalletReceive_GetDetail] (
   @nFunc        INT,
   @nMobile      INT,
   @cLangCode    NVARCHAR(  3),
   @nScn         INT, 
   @nInputKey    INT, 
   @cFacility    NVARCHAR(  5),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cToID        NVARCHAR( 18),
   @cSKU         NVARCHAR( 20) OUTPUT, 
   @nQTY         INT           OUTPUT, 
   @cRDLineNo    NVARCHAR( 5)  OUTPUT, 
   @cOutField01  NVARCHAR( 60) OUTPUT, 
   @cOutField02  NVARCHAR( 60) OUTPUT, 
   @cOutField03  NVARCHAR( 60) OUTPUT, 
   @cOutField04  NVARCHAR( 60) OUTPUT, 
   @cOutField05  NVARCHAR( 60) OUTPUT, 
   @cOutField06  NVARCHAR( 60) OUTPUT, 
   @cOutField07  NVARCHAR( 60) OUTPUT, 
   @cOutField08  NVARCHAR( 60) OUTPUT, 
   @cOutField09  NVARCHAR( 60) OUTPUT, 
   @cOutField10  NVARCHAR( 60) OUTPUT, 
   @cOutField11  NVARCHAR( 60) OUTPUT, 
   @cOutField12  NVARCHAR( 60) OUTPUT, 
   @cOutField13  NVARCHAR( 60) OUTPUT, 
   @cOutField14  NVARCHAR( 60) OUTPUT, 
   @cOutField15  NVARCHAR( 60) OUTPUT, 
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cInField01 NVARCHAR( 60), @cFieldAttr01 NVARCHAR(1), @cLottable01  NVARCHAR( 18)
   DECLARE @cInField02 NVARCHAR( 60), @cFieldAttr02 NVARCHAR(1), @cLottable02  NVARCHAR( 18)
   DECLARE @cInField03 NVARCHAR( 60), @cFieldAttr03 NVARCHAR(1), @cLottable03  NVARCHAR( 18)
   DECLARE @cInField04 NVARCHAR( 60), @cFieldAttr04 NVARCHAR(1), @dLottable04  DATETIME
   DECLARE @cInField05 NVARCHAR( 60), @cFieldAttr05 NVARCHAR(1), @dLottable05  DATETIME
   DECLARE @cInField06 NVARCHAR( 60), @cFieldAttr06 NVARCHAR(1), @cLottable06  NVARCHAR( 30)
   DECLARE @cInField07 NVARCHAR( 60), @cFieldAttr07 NVARCHAR(1), @cLottable07  NVARCHAR( 30)
   DECLARE @cInField08 NVARCHAR( 60), @cFieldAttr08 NVARCHAR(1), @cLottable08  NVARCHAR( 30)
   DECLARE @cInField09 NVARCHAR( 60), @cFieldAttr09 NVARCHAR(1), @cLottable09  NVARCHAR( 30)
   DECLARE @cInField10 NVARCHAR( 60), @cFieldAttr10 NVARCHAR(1), @cLottable10  NVARCHAR( 30)
   DECLARE @cInField11 NVARCHAR( 60), @cFieldAttr11 NVARCHAR(1), @cLottable11  NVARCHAR( 30)
   DECLARE @cInField12 NVARCHAR( 60), @cFieldAttr12 NVARCHAR(1), @cLottable12  NVARCHAR( 30)
   DECLARE @cInField13 NVARCHAR( 60), @cFieldAttr13 NVARCHAR(1), @dLottable13  DATETIME
   DECLARE @cInField14 NVARCHAR( 60), @cFieldAttr14 NVARCHAR(1), @dLottable14  DATETIME
   DECLARE @cInField15 NVARCHAR( 60), @cFieldAttr15 NVARCHAR(1), @dLottable15  DATETIME

   DECLARE @cLottableCode NVARCHAR( 30)
   DECLARE @nMorePage     INT 

   -- Get 1st line
   IF @cSKU = ''
      SELECT TOP 1 
         @cSKU = SKU, 
         @nQTY = QTYExpected, 
         @cRDLineNo = ReceiptLineNumber
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cToID
         AND BeforeReceivedQTY = 0
      ORDER BY SKU, ReceiptLineNumber 
   ELSE
   BEGIN
      -- Get same SKU, next line
      SELECT TOP 1 
         @cSKU = SKU, 
         @nQTY = QTYExpected, 
         @cRDLineNo = ReceiptLineNumber 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cToID
         AND SKU = @cSKU
         AND BeforeReceivedQTY = 0
         AND ReceiptLineNumber > @cRDLineNo
      ORDER BY ReceiptLineNumber 

      -- Get next SKU
      IF @@ROWCOUNT = 0
         SELECT TOP 1 
            @cSKU = SKU, 
            @nQTY = QTYExpected, 
            @cRDLineNo = ReceiptLineNumber 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND ToID = @cToID
            AND SKU > @cSKU
            AND BeforeReceivedQTY = 0
         ORDER BY SKU, ReceiptLineNumber 
   END
   
   -- No more record
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = -1
      GOTO Quit 
   END
   
   -- Get SKU info
   SELECT @cLottableCode = LottableCode
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Get ReceiptDetail info
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
      AND ReceiptLineNumber = @cRDLineNo

   -- Dynamic lottable
   EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 8, 
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

Quit: 


GO