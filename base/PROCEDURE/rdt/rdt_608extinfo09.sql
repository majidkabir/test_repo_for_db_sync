SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_608ExtInfo09                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Show TTL qty                                                */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-09-17  1.0  YeeKung  WMS-14415. Created                         */
/* 2022-09-08  1.1  Ung      WMS-20348 Expand RefNo to 60 chars         */
/************************************************************************/    

CREATE   PROC [RDT].[rdt_608ExtInfo09] (    
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
  @cRefNo        NVARCHAR( 60), 
  @cID           NVARCHAR( 18), 
  @cLOC          NVARCHAR( 10), 
  @cMethod       NVARCHAR( 1),  
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
  @cRDLineNo     NVARCHAR( 10), 
  @cExtendedInfo NVARCHAR(20)  OUTPUT, 
  @nErrNo        INT           OUTPUT, 
  @cErrMsg       NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @cUnmatched_SKU       NVARCHAR( 20),
           @cText2Display        NVARCHAR( 20),
           @nCount               INT,
           @nQtyExpected         INT,
           @nBeforeReceivedQty   INT,
           @fUnitPrice           FLOAT

   DECLARE  @cErrMsg01    NVARCHAR( 20), 
            @cErrMsg02    NVARCHAR( 20),
            @cErrMsg03    NVARCHAR( 20), 
            @cErrMsg04    NVARCHAR( 20),
            @cErrMsg05    NVARCHAR( 20),
            @cErrMsg06    NVARCHAR( 20),
            @cErrMsg07    NVARCHAR( 20), 
            @cErrMsg08    NVARCHAR( 20),
            @cErrMsg09    NVARCHAR( 20),
            @cErrMsg10    NVARCHAR( 20)

   DECLARE @cNotes      NVARCHAR( 4000)

   SELECT @cErrMsg01 = '', @cErrMsg02 = '', @cErrMsg03 = '', @cErrMsg04 = '', @cErrMsg05 = ''
   SELECT @cErrMsg06 = '', @cErrMsg07 = '', @cErrMsg08 = '', @cErrMsg09 = '', @cErrMsg10 = ''
   SELECT @nQtyExpected = 0, @nBeforeReceivedQty = 0

   IF @nStep IN(3,4)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SELECT @nBeforeReceivedQty=SUM(beforereceivedqty)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         and beforereceivedqty<>0

         SET @cExtendedInfo = 'TTL QTY: ' +CAST(@nBeforeReceivedQty AS NVARCHAR(5)) +'/'+ CAST( @nQtyExpected AS NVARCHAR( 5))
      END
   END
END     

GO