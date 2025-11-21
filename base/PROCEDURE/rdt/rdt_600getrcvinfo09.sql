SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600GetRcvInfo09                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Retrieve SKU based on lottable                                    */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2022-08-29  Ung       1.0   WMS-20644 Created                              */
/* 2022-10-28  Ung       1.1   WMS-20760 Add pallet with non SSCC SKU         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600GetRcvInfo09] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 5 -- Lottable
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cBarcode    NVARCHAR( 60)
            DECLARE @cPalleSSCC  NVARCHAR( 20)
            DECLARE @cChkSKU     NVARCHAR( 20)
            
            -- Get session info
            SELECT @cBarcode = V_String43 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

            -- Pallet SSCC
            IF left( @cBarcode,2) = '00'
            BEGIN
               IF SUBSTRING( @cBarcode, 21, 2) = '93'
               BEGIN
                  SET @cPalleSSCC = SUBSTRING( @cBarcode,  3, 18)

                  -- Pallet with SSCC SKU
                  SELECT TOP 1
                     @cChkSKU = RD.SKU
                  FROM receiptDetail RD WITH (NOLOCK)
                     JOIN UCC WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU AND RD.ExternReceiptKey = UCC.ExternKey AND RD.Lottable09 = UCC.Userdefined03)
                  WHERE RD.StorerKey = @cStorerKey
                     AND RD.ReceiptKey = @cReceiptKey
                     AND RD.FinalizeFlag <> 'Y'
                     AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
                     AND RD.Lottable01 = @cLottable01
                     AND RD.Lottable02 = @cLottable02
                     AND RD.Lottable03 = @cLottable03
                     AND RD.Lottable09 = @cPalleSSCC
                  ORDER BY RD.ReceiptLineNumber

      		      IF @@ROWCOUNT = 0
      		      BEGIN
               	   -- Pallet with non SSCC SKU
               	   SELECT TOP 1
               	      @cChkSKU = RD.SKU
         		      FROM receiptDetail RD WITH (NOLOCK)
         		      WHERE RD.StorerKey = @cStorerKey
            		      AND RD.ReceiptKey = @cReceiptKey
                        AND RD.FinalizeFlag <> 'Y'
                        AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
                        AND RD.Lottable01 = @cLottable01
                        AND RD.Lottable02 = @cLottable02
                        AND RD.Lottable03 = @cLottable03
                        AND RD.Lottable09 = @cPalleSSCC
                     ORDER BY RD.ReceiptLineNumber
               
                     -- Check lottable valid
                     IF @@ROWCOUNT = 0
                     BEGIN
                        SET @nErrNo = 190501
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Bad Lottables
                        GOTO Quit
                     END
                  END
                  
                  -- Return SKU
                  SET @cSKU = @cChkSKU
               END
            END
         END
      END
   END

Quit:

END

GO