SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638ExtValid02                                   */
/* Purpose: Validate SKU qty expected same like before receive qty      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-03-18 1.0  YeeKung    WMS-12465. Created                        */
/* 2020-07-13 1.1  Ung        WMS-13555 Change params                   */
/* 2022-09-23 1.2  YeeKung    WMS-20820 Extended refno length (yeekung01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtValid02] (
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

   DECLARE @nQTYExpected_Total   INT = 0
   DECLARE @nBeforeReceivedQTY_Total   INT = 0
   DECLARE @cNonOverReceive    NVARCHAR( 1) = ''

   SET @nErrNo = 0

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @cNonOverReceive = rdt.RDTGetConfig( @nFunc, 'NonOverReceive', @cStorerKey)

            SELECT
               @nQTYExpected_Total = ISNULL( SUM( QTYExpected), 0),
               @nBeforeReceivedQTY_Total = ISNULL( SUM( BeforeReceivedQTY), 0)
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND   ISNULL( UserDefine01, '') = ''
               AND   SKU = @cSKU

            IF (@cSKU='')
            BEGIN
               IF ( @nQTYExpected_Total <> @nQTY+@nBeforeReceivedQTY_Total)
               BEGIN
                  SET @nErrNo = 149601
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvRecQTY
                  GOTO QUIT
               END
            END
            ELSE
            BEGIN
                IF ( @nQTY+@nBeforeReceivedQTY_Total>@nQTYExpected_Total)
                BEGIN
                  SET @nErrNo = 149603
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvRecQTY
                  GOTO QUIT
                END
            END
         END
      END

      IF @nStep = 8 -- Finalize ASN
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF (@cOption = 1)
            BEGIN
               SELECT
               @nQTYExpected_Total = ISNULL( SUM( QTYExpected), 0),
               @nBeforeReceivedQTY_Total = ISNULL( SUM( BeforeReceivedQTY), 0)
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND   ISNULL( UserDefine01, '') = ''
                          IF ( @nQTYExpected_Total <> @nBeforeReceivedQTY_Total)
               BEGIN
                  SET @nErrNo = 149602
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvRecQTY
                  GOTO QUIT
               END
            END
         END
      END
   END

Quit:


GO