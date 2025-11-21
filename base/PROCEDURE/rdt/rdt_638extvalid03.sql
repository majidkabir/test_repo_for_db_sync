SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638ExtValid03                                   */
/* Purpose: Check receiveinfo                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-04-14 1.0  YeeKung    WMS-14241. Created                        */
/* 2020-08-18 1.1  Ung        WMS-13555 Change params                   */
/* 2020-09-30 1.2  Ung        WMS-14241 Fix RefNo could also be OrderKey*/
/* 2022-09-23 1.3  YeeKung    WMS-20820 Extended refno length (yeekung01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtValid03] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung01)
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

   SET @nErrNo = 0

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         DECLARE @nQTYExpected_Total INT,
                 @nBeforeReceivedQTY_Total INT,
                 @cExternReceiptKey NVARCHAR( 20)

         SELECT @cExternReceiptKey = ExternReceiptKey
         FROM Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SELECT @nQTYExpected_Total= ISNULL(SUM(ShippedQty),0)
         FROM ORDERDETAIL (NOLOCK)
         WHERE Externorderkey=@cExternReceiptKey
            AND sku=@cSKU
            AND StorerKey=@cStorerKey
            and ShippedQty<>0

         SELECT
            @nBeforeReceivedQTY_Total = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE externreceiptkey=@cExternReceiptKey
            AND sku=@cSKU
            AND StorerKey=@cStorerKey

         IF @nQTYExpected_Total = 0
         BEGIN
            SET @nErrNo = 155851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non LF Item
            GOTO Quit
         END

         -- Check over receipt
         IF  (1 + @nBeforeReceivedQTY_Total) > @nQTYExpected_Total
         BEGIN
            SET @nErrNo = 155852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non LF Item
            GOTO Quit
         END
      END
   END

Quit:

GO