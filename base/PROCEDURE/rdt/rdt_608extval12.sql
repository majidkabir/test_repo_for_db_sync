SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/************************************************************************/  
/* Store procedure: rdt_608ExtVal12                                     */  
/* Copyright      : LF logistics                                        */  
/*                                                                      */  
/* Purpose: Doctype = R cannot over receive                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author      Purposes                                */  
/* 2022-01-06  1.0  James       WMS-18649. Created                      */  
/* 2022-04-25  1.1  YeeKung     WMS-19543 Add New Validation toloc      */
/*                               (yeekung01)                            */
/* 2022-09-08  1.2  Ung         WMS-20348 Expand RefNo to 60 chars      */
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608ExtVal12]  
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
  
   DECLARE @cDocType             NVARCHAR( 1)  
   DECLARE @nTtl_ExpectedQty     INT  
   DECLARE @nTtl_B4ReceivedQty   INT  
   DECLARE @cReceiptGroup        NVARCHAR( 20) 
   DECLARE @cHostwhcode          NVARCHAR(20)
     
   IF @nFunc = 608 -- Piece return   
   BEGIN  
      IF @nStep = 2 -- SKU, QTY  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            SELECT @cReceiptGroup = ReceiptGroup  
            FROM dbo.RECEIPT WITH (NOLOCK)  
            WHERE ReceiptKey = @cReceiptKey  
           
            IF @cReceiptGroup='acommerce' 
            BEGIN  
               IF EXISTS (SELECT 1 FROM LOC (NOLOCK)
                          WHERE LOC=@cLOC
                          AND Hostwhcode<>'aQI')
               BEGIN  
                  SET @nErrNo = 180552  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receive  
                  GOTO Quit  
               END 
            END  
            ELSE
            BEGIN
               SELECT @cHostwhcode=Hostwhcode 
               FROM LOC (NOLOCK)
               WHERE LOC=@cLOC

               IF NOT EXISTS (SELECT 1 FROM Codelkup (NOLOCK)    
                           WHERE LISTNAME='ADSTKSTS'    
                           AND Storerkey=@cStorerkey    
                           AND long='I'    
                           AND code=@cHostwhcode)    
               BEGIN  
                  SET @nErrNo = 180553  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receive  
                  GOTO Quit  
               END 
            END
         END  
      END  
      IF @nStep = 4 -- SKU, QTY  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            SELECT @cDocType = DocType  
            FROM dbo.RECEIPT WITH (NOLOCK)  
            WHERE ReceiptKey = @cReceiptKey  
           
            IF @cDocType = 'R'  
            BEGIN  
               SELECT @nTtl_ExpectedQty = SUM( QtyExpected),   
                      @nTtl_B4ReceivedQty = SUM( BeforeReceivedQty)  
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
               WHERE ReceiptKey = @cReceiptKey  
               AND   Sku = @cSKU  
              
               IF ( @nTtl_B4ReceivedQty + @nQTY) > @nTtl_ExpectedQty  
               BEGIN  
                  SET @nErrNo = 180551  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receive  
                  GOTO Quit  
               END  
            END  
         END  
      END  
  
   END  
     
Quit:  
  
END  

GO