SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_607ExtInfo04                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Show balance QTY                                            */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 23-08-2018  1.0  Ung          WMS-5956 Created                       */
/* 12-09-2022  1.1  yeekung      WMS-20372 add userdefine02 (yeekung01) */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_607ExtInfo04]
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
   @cRefNo        NVARCHAR( 20), 
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
   @cReasonCode   NVARCHAR( 10), 
   @cSuggToID     NVARCHAR( 18), 
   @cSuggToLOC    NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
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

   IF @nFunc = 607 -- Return V7
   BEGIN
      IF @nAfterStep = 3 -- QTY
      BEGIN
         DECLARE @nTotalQTYExp INT 
         DECLARE @nTotalQTYRcv INT 
         DECLARE @cUserdefine02 NVARCHAR(20)

         -- Get statistic
         SELECT 
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0), 
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0),
            @cUserdefine02 = userdefine02
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN '' ELSE @cPOKey END
            AND SKU = @cSKU
         GROUP BY userdefine02
            
         SET @cExtendedInfo = N'BAL QTY: ' 
         
         IF @nTotalQTYExp > @nTotalQTYRcv
            SET @cExtendedInfo = @cExtendedInfo + CAST( @nTotalQTYExp - @nTotalQTYRcv AS NVARCHAR(10)) + Left(@cUserdefine02,5) 
         ELSE
            SET @cExtendedInfo = @cExtendedInfo + '0' + Left(@cUserdefine02,5) 
      END

      IF @nAfterStep = 5 -- Suggest ID, LOC
      BEGIN
         DECLARE @cSignatory NVARCHAR( 18)
         DECLARE @cBrand NVARCHAR( 250)

         -- Get receipt info
         SELECT @cSignatory = ISNULL( Signatory, '')
         FROM Receipt WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey

         -- Get SKU info
         SET @cBrand = ''
         SELECT @cBrand = ISNULL( Long, '')
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'ITEMCLASS' 
            AND StorerKey = @cStorerKey 
            AND Code = @cSignatory
         
         IF @cBrand = 'CPD'
            SELECT @cExtendedInfo = LEFT( ExtendedField05, 20)
            FROM SKUInfo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU         
      END
   END
   
Quit:
   
END

GO