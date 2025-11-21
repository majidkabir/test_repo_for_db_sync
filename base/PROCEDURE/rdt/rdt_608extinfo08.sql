SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_608ExtInfo08                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Show SKU with unmatched qty                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author    Purposes                                  */    
/* 2020-12-09  1.0  Chermaine WMS-15615 Created                         */
/* 2022-09-08  1.1  Ung      WMS-20348 Expand RefNo to 60 chars         */
/************************************************************************/    

CREATE   PROC [RDT].[rdt_608ExtInfo08] (    
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
           @nBeforeReceivedQty   INT

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

   SELECT @cSKU = I_field03 FROM rdt.RDTMOBREC (NOLOCK) WHERE mobile = @nMobile
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SET @cExtendedInfo = 'TTL EXP QTY: ' + CAST( @nQtyExpected AS NVARCHAR( 5))
      END
   END

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 0
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                           AND   FinalizeFlag = 'N')
         BEGIN
            SET @cErrMsg01 = rdt.rdtgetmessage( 123401, @cLangCode, 'DSP') --RETURN FINALIZED
            SET @cErrMsg02 = rdt.rdtgetmessage( 123402, @cLangCode, 'DSP') --SUCESSFULLY

            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg01, @cErrMsg02

            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg01 = ''
               SET @cErrMsg02 = ''
               SET @nErrNo = 0
            END
         END
      END
   END

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cNotes = Notes
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SET @cExtendedInfo = SUBSTRING( @cNotes, 1, 20)
      END
   END
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cNotes = price
         FROM dbo.SKU WITH (NOLOCK)
         WHERE SKU = @cSKU

         SET @cExtendedInfo = 'PRICE:' + SUBSTRING( @cNotes, 1, 20)
      END
   END

   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cNotes = Notes
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SET @cExtendedInfo = SUBSTRING( @cNotes, 1, 20)
      END
   END
       
END     

GO