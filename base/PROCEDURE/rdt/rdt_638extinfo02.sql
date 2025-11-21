SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_638ExtInfo02                                       */
/* Purpose: Validate TO ID                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2021-07-02 1.0  James      WMS-17405 Created                            */
/* 2022-09-23 1.1   YeeKung   WMS-20820 Extended refno length (yeekung01)   */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtInfo02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT ,
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
      IF @nAfterStep = 5 -- ToLoc
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM dbo.RECEIPT R WITH (NOLOCK)
                        WHERE R.ReceiptKey = @cReceiptKey
                        AND   EXISTS ( SELECT 1 FROM DBO.CODELKUP CL WITH (NOLOCK)
                                       WHERE CL.LISTNAME = 'NIKESOLDTO'
                                       AND   CL.Long = 'OUTLET'
                                       AND   R.StorerKey = CL.Storerkey
                                       AND   R.Userdefine03 = CL.Notes))
            BEGIN
               SET @cExtendedInfo = SUBSTRING( rdt.rdtgetmessage( 170001, @cLangCode, 'DSP'), 8, 13) --OUTLET ORDERS
               GOTO Quit
            END
         END
      END
   END

Quit:


GO