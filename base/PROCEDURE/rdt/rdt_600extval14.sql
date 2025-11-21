SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal14                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Reject B2C type ASN                                         */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-04-27 1.0  yeekung   WMS-22265 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtVal14] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
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
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine02        NVARCHAR( 30) 
   DECLARE @cMaxPallet           NVARCHAR( 10)
   DECLARE @nSKUCnt              INT = 0
   DECLARE @nNewSku              INT = 0
   DECLARE @nQtyExpected         INT = 0
   DECLARE @nBeforeReceivedQty   INT = 0
   
   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
      		SELECT @cMaxPallet = Short
      		FROM dbo.CODELKUP WITH (NOLOCK)
      		WHERE LISTNAME = 'CUSTPARAM'
      		AND   Code = 'MAXSKUPAL'
      		AND   Storerkey = @cStorerKey
      		
      		SELECT @nSKUCnt = COUNT( DISTINCT Sku)
      		FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      		WHERE StorerKey = @cStorerKey
      		AND   ReceiptKey = @cReceiptKey
      		AND   ToId = @cID
      		AND   BeforeReceivedQty > 0
      		
      		IF NOT EXISTS ( SELECT 1 
      		                FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      		                WHERE StorerKey = @cStorerKey
      		                AND   ReceiptKey = @cReceiptKey
                            AND   ToId = @cID
      		                AND   BeforeReceivedQty > 0
      		                AND   Sku = @cSKU)
            SET @nNewSku = 1
            
            IF ( @nSKUCnt + @nNewSku) > CAST( @cMaxPallet AS INT)
            BEGIN
               SET @nErrNo = 200251   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over MaxPallet  
               GOTO Quit 
            END

      	END
      END
   END         

   Quit:


GO