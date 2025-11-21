SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580DecodeSP03                                        */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode label                                                      */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-06-28  James     1.0   WMS-22739. Created                             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1580DecodeSP03] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cBarcode            NVARCHAR( 120),
   @cSKU                NVARCHAR( 20)     OUTPUT,
   @nQTY                INT               OUTPUT,
   @cLottable01         NVARCHAR( 18)     OUTPUT,
   @cLottable02         NVARCHAR( 18)     OUTPUT,
   @cLottable03         NVARCHAR( 18)     OUTPUT,
   @dLottable04         DATETIME          OUTPUT,
   @cSerialNoCapture    NVARCHAR(1) = 0   OUTPUT,
   @nErrNo              INT               OUTPUT,
   @cErrMsg             NVARCHAR( 20)     OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRcvQty     INT = 0
   DECLARE @nExpQty     INT = 0
   
   IF @nStep = 5 -- SKU/QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cBarcode <> ''
         BEGIN
         	IF CHARINDEX( ':', @cBarcode) = 0
         	BEGIN
         		SET @cSKU = @cBarcode
         		SET @cLottable01 = ''
         	END
         	ELSE
         	BEGIN
         	   SET @cSKU = SUBSTRING( @cBarcode, 1, CHARINDEX( ':', @cBarcode) - 1)
         	   SET @cLottable01 = SUBSTRING( @cBarcode,  CHARINDEX( ':', @cBarcode) + 1, LEN( @cBarcode))
         	END
         	
            IF NOT EXISTS ( SELECT 1 
                            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                            WHERE ReceiptKey = @cReceiptKey
                            AND   SKU = @cSKU
                            AND   Lottable01 = @cLottable01
                            AND   FinalizeFlag <> 'Y')
            BEGIN
               SET @nErrNo = 203251  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In ASN  
               GOTO Quit              	
            END

            SELECT 
               @nRcvQty = ISNULL( SUM( BeforeReceivedQty), 0), 
               @nExpQty = ISNULL( SUM( QtyExpected), 0)
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   SKU = @cSKU
            AND   Lottable01 = @cLottable01
            AND   FinalizeFlag <> 'Y'
            
            IF ( @nRcvQty + 1) > @nExpQty
            BEGIN
               SET @nErrNo = 203252  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Over Rcv  
               GOTO Quit              	
            END
            
            SET @cLottable01 = CASE WHEN @cLottable01 = '' THEN 'DUMMY' ELSE @cLottable01 END
         END
      END
   END

Quit:

END

GO