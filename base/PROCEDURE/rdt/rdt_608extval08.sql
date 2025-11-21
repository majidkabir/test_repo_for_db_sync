SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
/******************************************************************************/          
/* Store procedure: rdt_608ExtVal08                                           */          
/* Copyright      : LF Logistics                                              */          
/*                                                                            */          
/* Purpose: Validate not allow over receipt                                   */          
/*                                                                            */          
/* Date         Author    Ver.  Purposes                                      */          
/* 2020-07-10   YeeKung   1.0   WMS-14415. Created                            */    
/* 2022-09-08   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */    
/******************************************************************************/          
          
CREATE   PROCEDURE [RDT].[rdt_608ExtVal08]            
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3),          
   @nStep         INT,          
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
   @nErrNo        INT           OUTPUT,          
   @cErrMsg       NVARCHAR( 20) OUTPUT          
AS          
BEGIN          
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
          
   DECLARE @nQTYExpected_Total         INT          
   DECLARE @nBeforeReceivedQTY_Total   INT          
   DECLARE @cErrMsg1                   NVARCHAR(20)          
   DECLARE @cErrMsg2                   NVARCHAR(20)          
          
   DECLARE @cRecType    NVARCHAR( 10)          

   SET @nErrNo = 0

   IF @nFunc = 608 -- Piece return          
   BEGIN          
      IF @nStep = 4 -- SKU, QTY          
      BEGIN          
         IF @nInputKey = 1 -- ESC          
         BEGIN  
            IF NOT EXISTS( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)        
                        WHERE ReceiptKey = @cReceiptKey              
                        AND   Storerkey = @cStorerKey      
                        AND   SKU = @cSKU    
                        and   lottable03=@cLottable03    
                        )             
            BEGIN        
               SET @nErrNo = 159652            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receipt          
               GOTO Quit          
            END   
                 
            IF EXISTS( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)        
                       WHERE ReceiptKey = @cReceiptKey              
                       AND   Storerkey = @cStorerKey      
                       AND   SKU = @cSKU    
                       and   lottable03=@cLottable03    
                       GROUP BY ReceiptKey, SKU  
                       HAVING SUM( QTYExpected) < ( SUM( BeforeReceivedQTY) + @nQty))             
            BEGIN        
               SET @nErrNo = 159651             
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receipt          
               GOTO Quit          
            END         
         END          
      END          
   END          
          
Quit:          
          
END          

GO