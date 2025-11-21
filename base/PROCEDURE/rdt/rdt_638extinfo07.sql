SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638ExtInfo07                                       */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Show ASN SKU level balance                                     */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-07-07 1.0  Ung        WMS-22911 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtInfo07] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT ,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
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
   @tExtInfoVar   VariableTable READONLY,
   @cExtendedInfo NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nAfterStep = 3 -- SKU
      BEGIN
         SET @cExtendedInfo = ''

         IF @cReceiptKey <> ''
         BEGIN
            IF EXISTS( SELECT 1
               FROM dbo.Receipt WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND DocType = 'R' 
                  AND ReceiptGroup = 'ECOM' 
                  AND UserDefine04 = N'underarmourΣ║¼Σ╕£Φç¬ΦÉÑσ║ù')
            BEGIN
               DECLARE @nQTYExpected INT = 0
               DECLARE @nQTYReceived INT = 0
               SELECT
                  @nQTYExpected = ISNULL( SUM( RD.QTYExpected), 0), 
                  @nQTYReceived = ISNULL( SUM( RD.BeforeReceivedQTY), 0)
               FROM dbo.Receipt R WITH (NOLOCK)  
                  JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)  
               WHERE R.Facility = @cFacility  
                  AND R.StorerKey = @cStorerKey  
                  AND R.Status <> '9'  
                  AND R.ASNStatus <> 'CANC'  
                  AND R.ReceiptGroup = 'ECOM'  
                  AND R.Userdefine02 = @cRefNo 
                  -- AND RD.SKU = @cSKU  
                  
               SET @cExtendedInfo = 'ASN SKU: ' + CAST( @nQTYReceived AS NVARCHAR(5)) + '/' + CAST( @nQTYExpected AS NVARCHAR(5))
            END
         END
      END
   END

Quit:


GO