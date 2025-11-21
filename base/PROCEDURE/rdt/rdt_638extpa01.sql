SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_638ExtPA01                                         */
/* Purpose: Validate TO ID                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2021-07-02 1.0  James      WMS-17405 Created                            */
/* 2022-09-23 1.1  YeeKung    WMS-20820 Extended refno length (yeekung01)   */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtPA01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 60), --(yeekung01)
   @cID          NVARCHAR( 18),
   @cLOC         NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @cReceiptLineNumber NVARCHAR( 5),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @cSuggID      NVARCHAR( 18)  OUTPUT,
   @cSuggLOC     NVARCHAR( 10)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUDF02   NVARCHAR( 60)
   DECLARE @cUDF03   NVARCHAR( 60)
   DECLARE @cUDF04   NVARCHAR( 60)
   DECLARE @cUDF05   NVARCHAR( 60)
   DECLARE @cLong    NVARCHAR( 250)
   DECLARE @cUserDefine03  NVARCHAR( 30)

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep IN ( 3, 4) -- SKU/Lottable
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @cSuggLOC = ''

            SELECT @cUserDefine03 = UserDefine03
            FROM dbo.RECEIPT WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey

            SELECT @cUDF02 = Long
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'O2REASON'
            AND   Code = @cLottable02
            AND   Storerkey = @cStorerKey

            IF ISNULL( @cUDF02, '') = ''
               SET @cUDF02 = 'NON'

            SELECT @cLong = Long
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'NIKESOLDTO'
            AND   Notes = @cUserDefine03
            AND   Storerkey = @cStorerKey

            SELECT
               @cUDF03 = ExtendedField02,
               @cUDF04 = ExtendedField03,
               @cUDF05 = ExtendedField06
            FROM dbo.SkuInfo WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   Sku = @cSKU

            SELECT @cSuggLOC = CL.Short
            FROM dbo.CODELKUP CL WITH (NOLOCK)
            WHERE CL.LISTNAME = 'NIKESugLoc'
            AND   CL.Long = @cLong
            AND   CL.UDF01 = @cLottable01
            AND   CL.UDF02 = @cUDF02
            AND   CL.UDF03 = @cUDF03
            AND   CL.UDF04 = @cUDF04
            AND   CL.UDF05 = @cUDF05
            AND   Storerkey = @cStorerKey
         END
      END
   END

Quit:


GO