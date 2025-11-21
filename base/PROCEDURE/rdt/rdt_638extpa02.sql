SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638ExtPA02                                         */
/* Purpose: Validate TO ID                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-10-21 1.0  Ung        WMS-20982 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtPA02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 60), 
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
            IF @cSuggID = ''
            BEGIN
               DECLARE @bSuccess INT
               DECLARE @cAutoID NVARCHAR(4)
               
               SET @bSuccess = 0
               EXECUTE dbo.nspg_GetKey
                  'ECOMReturnTOID',
                  4 ,
                  @cAutoID    OUTPUT,
                  @bSuccess   OUTPUT,
                  @nErrNo     OUTPUT,
                  @cErrMsg    OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 193201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetAutoID Fail
                  GOTO Quit
               END
               
               IF @cAutoID <> ''
               BEGIN
                  SET @cSuggID = 
                     'LL' + 
                     RIGHT( CONVERT( NVARCHAR(6), GETDATE(), 12), 5) + --12 = YYMMDD 
                     @cAutoID
               END
            END
         END
      END
   END

Quit:


GO