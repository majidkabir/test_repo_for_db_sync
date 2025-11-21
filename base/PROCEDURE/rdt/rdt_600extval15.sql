SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal15                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Reject B2C type ASN           									   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 25-05-2023 1.0 yeekung     WMS-22369 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtVal15] (
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

   DECLARE @cMaxPallet           NVARCHAR( 10)
   DECLARE @nTTlUCC              INT

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
      		SELECT @cMaxPallet = Short
      		FROM dbo.CODELKUP WITH (NOLOCK)
      		WHERE LISTNAME = 'PltMaxCnt'
      		AND   Storerkey = @cStorerKey

            SELECT 
               @nTTlUCC = Count(*)
            FROM UCC WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND Storerkey = @cStorerKey
               AND Status = '1'
               AND ID = @cID
      		
            IF ( @nTTlUCC + 1) > CAST( @cMaxPallet AS INT)
            BEGIN
               SET @nErrNo = 201401   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MaxCtnPallet  
               GOTO Quit 
            END

      	END
      END

      IF @nStep = 6 -- Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cLottable02Label NVARCHAR( 20)

            -- Get SKU info
            SELECT @cLottable02Label = Lottable02Label
            FROM SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU


            -- Check 1 serial no SKU, 1 QTY
            IF @cLottable02Label <> '' AND @nQTY <> 1
            BEGIN
               SET @nErrNo = 201402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NOT ALLOW > 1
               GOTO Quit
            END

            IF EXISTS (SELECT 1     
                       FROM RECEIPTDetail (nolock) 
                       WHERE Receiptkey = @cReceiptKey
                        AND Storerkey = @CStorerkey
                        AND Lottable02 = @cLottable02
                        HAVING SUM(BeforeReceivedQty) + @nQTY >SUM(QTYExpected))
            BEGIN
               SET @nErrNo = 201403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OverReceipt
               GOTO Quit
            END

         END
      END
   END         

   Quit:


GO