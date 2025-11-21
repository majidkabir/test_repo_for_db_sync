SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 15-Apr-2015  Ung       1.0   SOS335126 Created                             */
/* 16-Apr-2018  Ung       1.1   WMS-4668 Add message                          */
/* 05-Jul-2021  James     1.2   WMS-17419 Add display Mark( style) (james01)  */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_600ExtInfo01]
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
         DECLARE @nPackQtyIndicator INT
         DECLARE @fLength FLOAT
         DECLARE @fWidth FLOAT
         DECLARE @fHeight FLOAT
         DECLARE @cNewSKU NVARCHAR(1)
         DECLARE @cStyle  NVARCHAR( 20)
         
         -- Get SKU info
         SELECT 
            @nPackQtyIndicator = PackQtyIndicator, 
            @fLength = Length,
            @fWidth = Width,
            @fHeight = Height,
            @cStyle = Style
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         
         -- Check new SKU
         SET @cNewSKU = 'N'
         IF @fLength = 0 OR @fWidth = 0 OR @fHeight = 0
            SET @cNewSKU = 'Y'

         -- Get balance QTY
         DECLARE @nBal INT
         SELECT @nBal = ISNULL( SUM( QTYExpected - BeforeReceivedQTY), 0)
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cSKU
         
         -- Over received
         IF @nBal < 0
            SET @nBal = 0

         -- (james01)
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'SKUDANGER' AND Code = LEFT(@cStyle, 1) AND Storerkey = @cStorerKey)
            SET @cStyle = '(' + LEFT(@cStyle, 3) + ')'
         ELSE
            SET @cStyle = ''

         -- Balance
         SET @cExtendedInfo = 
            RTRIM( rdt.rdtgetmessage( 122851, @cLangCode, 'DSP')) + -- OPN:
               CAST( @nBal AS NVARCHAR(5)) + SPACE(1) + 
            RTRIM( rdt.rdtgetmessage( 122852, @cLangCode, 'DSP')) + -- PKQ:
               CAST( @nPackQtyIndicator AS NVARCHAR(5)) + 
               CASE 
                  WHEN @cNewSKU = 'Y' 
                  THEN RTRIM( rdt.rdtgetmessage( 122853, @cLangCode, 'DSP')) --(NEW)
                  ELSE '' 
               END + 
               @cStyle  -- (james01)
      END
   END
END

GO