SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_607ExtPA09                                            */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Extended putaway with two method                                  */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 01-04-2020   YeeKung   1.0   WMS14478 - Created                            */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_607ExtPA09]  
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cStorerKey   NVARCHAR( 15),   
   @cReceiptKey  NVARCHAR( 10),   
   @cPOKey       NVARCHAR( 10),   
   @cRefNo       NVARCHAR( 20),   
   @cSKU         NVARCHAR( 20),   
   @nQTY         INT,             
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
   @cReasonCode  NVARCHAR( 10),   
   @cID          NVARCHAR( 18),   
   @cLOC         NVARCHAR( 10),   
   @cReceiptLineNumber NVARCHAR( 10),   
   @cSuggID      NVARCHAR( 18)  OUTPUT,   
   @cSuggLOC     NVARCHAR( 10)  OUTPUT,   
   @nErrNo       INT            OUTPUT,   
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
        
   IF @nFunc = 607 -- Return v7  
   BEGIN  

      DECLARE @cPAmethod NVARCHAR(1)
      DECLARE @cLocAisle NVARCHAR(20)

      SET @cPAmethod = rdt.RDTGetConfig( @nFunc, 'PAMethod', @cStorerKey)

      IF @cPAmethod ='1'
      BEGIN
         IF EXISTS(SELECT 1 FROM receiptdetail (NOLOCK) 
                     where receiptkey=@cReceiptKey 
                        AND sku=@cSKU 
                        AND toid<>''   
                        AND storerkey=@cStorerKey)
         BEGIN
            SELECT Top 1 @cSuggID=toid,@cSuggLOC=Toloc FROM receiptdetail (NOLOCK) 
            where receiptkey=@cReceiptKey 
               AND sku=@cSKU 
               AND toid<>''
         END
      END
      IF @cPAmethod ='2'
      BEGIN
         
         IF EXISTS(SELECT 1 FROM receiptdetail (NOLOCK) 
            where receiptkey=@cReceiptKey 
               AND sku=@cSKU 
               AND toid<>''   
               AND storerkey=@cStorerKey)
         BEGIN
            SELECT Top 1 @cSuggID=toid,@cSuggLOC=Toloc FROM receiptdetail (NOLOCK) 
            where receiptkey=@cReceiptKey 
               AND sku=@cSKU 
               AND toid<>''
         END
         ELSE
         BEGIN


            SELECT @cLocAisle=L.LocAisle FROM 
            LOTXLOCXID  LLI(NOLOCK)  JOIN LOC L (NOLOCK)           
            ON LLI.LOC=L.LOC
            where lli.sku=@cSKU
            AND L.LocAisle IN (SELECT LO.LocAisle FROM 
                                 LOTXLOCXID  LLI(NOLOCK)  JOIN LOC LO (NOLOCK)           
                                 ON LLI.LOC=LO.LOC
                                 JOIN receiptdetail RD (NOLOCK) 
                                 ON RD.SKU=LLI.SKU
                                 where RD.receiptkey=@cReceiptKey
                                 AND RD.TOID<>''
                                 )
            and l.locationtype='pick'

 
            IF (ISNULL(@cLocAisle,'')<>'' )
            BEGIN
               SELECT TOP 1 @cSuggID=RD.toid,@cSuggLOC=Toloc 
               FROM LOTXLOCXID LLI JOIN LOC L (NOLOCK)   
               ON LLI.LOC=L.LOC
               JOIN receiptdetail RD
               ON RD.SKU=LLI.SKU
               where RD.receiptkey=@cReceiptKey
                   AND L.LocAisle =@cLocAisle
                   AND rd.toid<>''

            END
                  
         END

      END
   END  
Quit:  
  
END  

GO