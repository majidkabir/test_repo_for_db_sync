SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638ExtInfo05                                       */
/* Purpose: Display VAS info                                               */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-04-14 1.0  Ung        WMS-22302 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtInfo05] (
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
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU info
            DECLARE @cNotes2 NVARCHAR( MAX)         
            SELECT @cNotes2 = ISNULL( Notes2, '')
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
            
            -- Show the VAS info
            IF @cNotes2 <> ''
            BEGIN
               DECLARE @cMsg1 NVARCHAR( 20)
               DECLARE @cMsg2 NVARCHAR( 20)
               DECLARE @cMsg3 NVARCHAR( 20)
               DECLARE @cMsg4 NVARCHAR( 20)
               DECLARE @cMsg5 NVARCHAR( 20)
               
               SET @cMsg1 = rdt.rdtFormatString( @cNotes2, 1, 20)
               SET @cMsg2 = rdt.rdtFormatString( @cNotes2, 21, 20)
               SET @cMsg3 = rdt.rdtFormatString( @cNotes2, 41, 20)
               SET @cMsg4 = rdt.rdtFormatString( @cNotes2, 61, 20)
               SET @cMsg5 = rdt.rdtFormatString( @cNotes2, 81, 20)
                                    
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5
            END
         END
      END
   END

Quit:


GO