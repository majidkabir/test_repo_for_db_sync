SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_607ExtVal03                                           */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Calc suggest location, booking, print label                       */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 02-09-2020   YeeKung   1.0   WMS-14478 Created                              */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_607ExtVal03]  
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
   @cReasonCode   NVARCHAR( 5),   
   @cSuggID       NVARCHAR( 18),   
   @cSuggLOC      NVARCHAR( 10),   
   @cID           NVARCHAR( 18),   
   @cLOC          NVARCHAR( 10),   
   @cReceiptLineNumber NVARCHAR( 5),   
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cBUSR1 NVARCHAR(20),
           @cOtherSKU NVARCHAR(20),
           @cOtherBUSR1 NVARCHAR(20),
           @cBrand NVARCHAR(20),
           @cOtherBrand  NVARCHAR(20)

   IF @nStep = 2 -- SKU 
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN
         SELECT @cBUSR1=busr1
         FROM sku (NOLOCK)
         where sku=@csku

         SELECT @cBrand=short
         FROM CODELKUP (NOLOCK)
         WHERE Code=@cBUSR1
         and storerkey=@cstorerkey
         and listname='CMGDIV'

         SELECT TOP 1 @cOtherSKU=sku
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE RECEIPTKEY=@creceiptkey

         IF @@ROWCOUNT >=1
         BEGIN
            SELECT @cOtherBUSR1=busr1
            FROM sku (NOLOCK)
            where sku=@cOtherSKU

            SELECT @cOtherBrand=short
            FROM CODELKUP (NOLOCK)
            WHERE Code=@cOtherBUSR1
            and storerkey=@cstorerkey
            and listname='CMGDIV'

            IF @cOtherBrand <>@cBrand
            BEGIN
               SET @nErrNo = 158601    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixBrand  
               GOTO Quit
            END

           
         END
      END
   END
  
Quit:  
  
END 

GO