SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_647ExtInfo01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Show received pallet/total pallet                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2021-04-07  1.0  James    WMS-16636. Created                         */
/************************************************************************/    

CREATE PROC [RDT].[rdt_647ExtInfo01] (    
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
   @cRefNo        NVARCHAR( 30),
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
   @cExtendedInfo NVARCHAR(20)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @nPallet     INT
   DECLARE @nSum_BeforeReceivedQty     INT
   DECLARE @nSum_QtyExpected           INT
   
   IF @nAfterStep = 5 OR @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nSum_BeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
                @nSum_QtyExpected = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   Sku = @cSKU
         
         SELECT @nPallet = P.Pallet
         FROM dbo.SKU S WITH (NOLOCK)
         JOIN dbo.PACK P WITH (NOLOCK) ON S.PACKKey = P.PackKey
         WHERE S.StorerKey = @cStorerKey
         AND   S.Sku = @cSKU
         
         SET @cExtendedInfo = 'REC P/ACT P: ' + 
                              CAST( @nSum_BeforeReceivedQty/@nPallet AS NVARCHAR( 3)) + 
                              '/' + 
                              CAST( @nSum_QtyExpected/@nPallet AS NVARCHAR( 3))
      END
   END 
END     

GO