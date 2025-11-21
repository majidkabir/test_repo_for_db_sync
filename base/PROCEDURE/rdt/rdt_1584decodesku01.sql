SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1584DecodeSKU01                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SSCC and retrieve its content                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-03-03  Ung       1.0   WMS-21709 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1584DecodeSKU01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cPalletSSCC  NVARCHAR( 30)  OUTPUT,
   @cCaseSSCC    NVARCHAR( 30)  OUTPUT,
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
   
   DECLARE @nRowCount INT
   DECLARE @bSuccess  INT

   /*
      Pallet SSCC:
         Format is: (00)18 digits(93)*
            Prefix = (00) 
            SSCC = 18 digits, fix length
            Surfix = (93)
            
            For e.g. "(00)123456789012345678(93)VMF"
            Prefix = (00)
            SSCC = 123456789012345678
            Surfix = (93). Ignore everything after surfix
            
         Pallet SSCC is mapped to ReceiptDetail.Lottable09
            For SSCC SKU, it is also mapped to UCC.Userdefined03 
            Non SSCC SKU, don't have UCC
            
         Pallet SSCC can contain single SKU or multi SKU
            For SSCC SKU, 1 UCC only 1 SKU
      
      Case SSCC:
         Format is: (95)18digits
            Prefix = (95)
            SSCC = 18 digits, fixed length
            
            For e.g. "(95)123456789012345678"
            Prefix = (95)
            SSCC = 123456789012345678
            
         Case SSCC is mapped to UCC.UCCNo
         Case SSCC is always single SKU
   */

   DECLARE @cUPC NVARCHAR( 30)
   
   SET @cUPC = LEFT( @cBarcode, 30)
   
   -- Check SKU
   DECLARE @nSKUCnt INT = 0
   EXEC RDT.rdt_GetSKUCNT
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cUPC
      ,@nSKUCnt     = @nSKUCnt   OUTPUT
      ,@bSuccess    = @bSuccess  OUTPUT
      ,@nErr        = @nErrNo    OUTPUT
      ,@cErrMsg     = @cErrMsg   OUTPUT
      ,@cSKUStatus  = 'ACTIVE'
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 197251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      GOTO Quit
   END
   
   IF @cPalletSSCC <> ''
   BEGIN
	   -- Get pallet info
	   SELECT 
	      @nSKUCnt = COUNT( DISTINCT RD.SKU), 
	      @cSKU = MIN( RD.SKU)
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.Storerkey AND RD.SKU = SKU.SKU)   
      WHERE RD.ReceiptKey = @cReceiptKey
	      AND RD.Lottable09 = @cPalletSSCC
	      AND @cUPC IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU)

      IF @nSKUCnt = 0
      BEGIN
   	   SET @nErrNo = 197252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInPallet
         GOTO Quit
      END
      
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 197253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Quit
      END
      
	   -- Pallet with SSCC SKU
	   SELECT TOP 1
	      @cLottable01 = RD.Lottable01, 
	      @cLottable02 = RD.Lottable02, 
	      @cLottable03 = RD.Lottable03, 
	      @cLottable09 = RD.Lottable09
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.UCC WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU AND RD.ExternReceiptKey = UCC.ExternKey AND RD.Lottable09 = UCC.UserDefined03)
      WHERE RD.ReceiptKey = @cReceiptKey
	      AND RD.Lottable09 = @cPalletSSCC
	      AND RD.SKU = @cSKU
         AND RD.FinalizeFlag <> 'Y'
         AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
      ORDER BY RD.ReceiptLineNumber

      IF @@ROWCOUNT = 0
      BEGIN
   	   -- Pallet with non SSCC SKU
   	   SELECT TOP 1
   	      @cLottable01 = Lottable01, 
   	      @cLottable02 = Lottable02, 
   	      @cLottable03 = Lottable03, 
   	      @cLottable09 = Lottable09
	      FROM dbo.ReceiptDetail WITH (NOLOCK)
	      WHERE ReceiptKey = @cReceiptKey
		      AND Lottable09 = @cPalletSSCC
	         AND SKU = @cSKU
            AND FinalizeFlag <> 'Y'
            AND QTYExpected > BeforeReceivedQTY -- line with balance
         ORDER BY ReceiptLineNumber
      
         IF @@ROWCOUNT = 0
         BEGIN
      	   SET @nErrNo = 197254
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Received
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet SSCC
            GOTO Quit
         END
      END
   END

   
   ELSE IF @cCaseSSCC <> ''
   BEGIN
      DECLARE @cChkSKU NVARCHAR( 10) = ''

	   -- Get case info
	   SELECT @cChkSKU = SKU
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cCaseSSCC
	      AND StorerKey = @cStorerKey
	      
      -- Check diff SKU
      IF @cChkSKU <> @cSKU
      BEGIN
   	   SET @nErrNo = 197255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Case diff SKU
         GOTO Quit
      END
   END 
   
Quit:
   
END

GO