SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtInfo08                                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Display Qty Received for Indetex                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 17-Oct-2024  LJQ006    1.0   FCR-841                                       */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_600ExtInfo08
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
      IF @nAfterStep = 6 -- QTY
      BEGIN
         DECLARE 
            @nTotalQtyReceived INT,
            @cUserUOM          NVARCHAR(1),
            @cUserUOMDesc      NVARCHAR(10),
            @nUserUOMDiv       INT
         -- get user UOM   
         SELECT @cUserUOM = ISNULL(usr.DefaultUOM, '6')
         FROM rdt.RDTUser usr WITH (NOLOCK) 
         INNER JOIN rdt.RDTMOBREC mob WITH (NOLOCK)  ON usr.UserName = mob.UserName
         WHERE mob.Mobile = @nMobile

         -- get user UOM div
         SELECT 
            @nUserUOMDiv = CAST(ISNULL(
            CASE @cUserUOM
               WHEN '2' THEN pack.CaseCNT
               WHEN '3' THEN pack.InnerPack
               WHEN '6' THEN pack.QTY
               WHEN '1' THEN pack.Pallet
               WHEN '4' THEN pack.OtherUnit1
               WHEN '5' THEN pack.OtherUnit2
            END, 1) AS INT),
            @cUserUOMDesc = ISNULL(
            CASE @cUserUOM
               WHEN '2' THEN pack.PackUOM1
               WHEN '3' THEN pack.PackUOM2
               WHEN '6' THEN pack.PackUOM3
               WHEN '1' THEN pack.PackUOM4
               WHEN '4' THEN pack.PackUOM8
               WHEN '5' THEN pack.PackUOM9
            END, 'EA')
         FROM dbo.PACK pack WITH (NOLOCK) 
         INNER JOIN dbo.SKU sku WITH (NOLOCK) ON pack.PackKey = sku.PackKey
         WHERE sku.StorerKey = @cStorerKey
            AND sku.Sku = @cSKU
         
         -- calculate the total qty of the receipt
         SELECT @nTotalQtyReceived = SUM(BeforeReceivedQty) 
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cSKU
            AND StorerKey = @cStorerKey
            AND Lottable01 = @cLottable01
            AND Lottable02 = @cLottable02
            AND Lottable03 = @cLottable03
            AND ISNULL(Lottable04, '') = ISNULL(@dLottable04, '')
            AND ISNULL(Lottable05, '') = ISNULL(@dLottable05, '')
            AND Lottable06 = @cLottable06
            AND Lottable07 = @cLottable07
            AND Lottable08 = @cLottable08
            AND Lottable09 = @cLottable09
            AND Lottable10 = @cLottable10
            AND Lottable11 = @cLottable11
            AND Lottable12 = @cLottable12
            AND ISNULL(Lottable13, '') = ISNULL(@dLottable13, '')
            AND ISNULL(Lottable14, '') = ISNULL(@dLottable14, '')
            AND ISNULL(Lottable15, '') = ISNULL(@dLottable15, '')
            
         -- cast total qty in master UOM to qty in user UOM
         SET @nTotalQtyReceived = @nTotalQtyReceived / @nUserUOMDiv
         SET @cExtendedInfo = N'RCVD QTY: ' + CAST( @nTotalQtyReceived AS NVARCHAR(10)) + ' ' + LEFT(@cUserUOMDesc, 4)
         --SET @cExtendedInfo = N'RECV QUANTITY:' + @cUserUOMDesc
         -- SET @cExtendedInfo = @cReceiptKey
      END
   END
END

GO