SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638ExtInfo03                                       */
/* Purpose: Validate TO ID                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-02-07 1.0  Ung        WMS-21385 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtInfo03] (
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

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @nTtl_ASN       INT
   DECLARE @nTtl_Qty       INT

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nAfterStep = 3 -- SKU
      BEGIN
         DECLARE @cTrackingNo   NVARCHAR( 40)
         DECLARE @cUserdefine09 NVARCHAR( 30)
         DECLARE @cUserdefine02 NVARCHAR( 30)
         
         SELECT 
            @cTrackingNo   = @cTrackingNo, 
            @cUserdefine09 = @cUserdefine09, 
            @cUserdefine02 = @cUserdefine02
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         
         IF @cUserdefine02 = @cRefNo
         BEGIN
            DECLARE @nQTYExpected INT
            DECLARE @nBeforeReceivedQTY INT
            SELECT 
               @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
               @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
            FROM dbo.Receipt R WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
            WHERE R.Facility = @cFacility
               AND R.StorerKey = @cStorerKey
               AND R.Status <> '9'
               AND R.ASNStatus <> 'CANC'
               AND R.ReceiptGroup = 'ECOM'
               AND R.Userdefine02 = @cRefNo
         
            DECLARE @cMsg NVARCHAR( 20)
            SET @cMsg = rdt.rdtgetmessage( 196201, @cLangCode, 'DSP') --REF QTY:
            
            SET @cExtendedInfo = 
               RTRIM( @cMsg) + ' ' + 
               CAST( @nBeforeReceivedQTY AS NVARCHAR(5)) + '/' + 
               CAST( @nQTYExpected AS NVARCHAR(5))
         END
         ELSE
            SET @cExtendedInfo = ''
      END
   END

Quit:


GO