SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638ExtValid01                                   */
/* Purpose: Validate SKU scanned must exists in                         */
/*          receiptdetail.userdefine01 = ''                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-11-21 1.0  James      WMS-10952. Created                        */
/* 2020-07-13 1.1  Ung        WMS-13555 Change params                   */
/* 2022-09-23 1.1  YeeKung    WMS-20820 Extended refno length (yeekung01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtValid01] (
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,                
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 20), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
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
   @cData1        NVARCHAR( 60), 
   @cData2        NVARCHAR( 60), 
   @cData3        NVARCHAR( 60), 
   @cData4        NVARCHAR( 60), 
   @cData5        NVARCHAR( 60), 
   @cOption       NVARCHAR( 1),  
   @dArriveDate   DATETIME,
   @tExtUpdateVar VariableTable READONLY, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTYExpected_Total   INT = 0
   DECLARE @nBeforeReceivedQTY_Total   INT = 0
   DECLARE @cAllowOverReceipt    NVARCHAR( 1) = ''

   SET @nErrNo = 0

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cAllowOverReceipt = rdt.RDTGetConfig( @nFunc, 'AllowOverReceipt', @cStorerKey)

         IF NOT EXISTS ( SELECT 1
                         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                         WHERE ReceiptKey = @cReceiptKey
                         AND   SKU = @cSKU
                         AND   ( ISNULL( UserDefine01, '') = '' AND ( QtyExpected > BeforeReceivedQty)) OR
                               ( ISNULL( UserDefine01, '') = '' AND @cAllowOverReceipt = '1')) -- Allow over receipt, no check on qty
         BEGIN
            SET @nErrNo = 146351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            GOTO Quit
         END

         SELECT
            @nQTYExpected_Total = ISNULL( SUM( QTYExpected), 0),
            @nBeforeReceivedQTY_Total = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ISNULL( UserDefine01, '') = ''

         -- Check over receipt
         IF @cAllowOverReceipt <> '1' AND
            (1 + @nBeforeReceivedQTY_Total) > @nQTYExpected_Total
         BEGIN
            SET @nErrNo = 146352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non LF Item
            GOTO Quit
         END

         IF @nQTYExpected_Total = 0
         BEGIN
            SET @nErrNo = 146353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non LF Item
            GOTO Quit
         END
      END
   END

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.RECEIPTDETAIL R WITH (NOLOCK)
                            WHERE R.ReceiptKey = @cReceiptKey
                            AND   R.BeforeReceivedQty > 0   -- something received
                            AND   R.FinalizeFlag <> 'Y'     -- not finalize yet
                            AND   R.UserDefine01 = '')      -- valid sku to receive
            BEGIN
               SET @nErrNo = 146354
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
               GOTO Quit
            END
         END
      END
   END

   Quit:

GO