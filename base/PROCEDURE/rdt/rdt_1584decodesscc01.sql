SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1584DecodeSSCC01                                      */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SSCC and retrieve its content                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-03-03  Ung       1.0   WMS-21709 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1584DecodeSSCC01] (
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

   IF @cPalletSSCC <> ''
   BEGIN
      -- Decode pallet SSCC
      SET @cPalletSSCC = SUBSTRING( @cPalletSSCC,  3, 18)

	   -- Check pallet valid
	   IF NOT EXISTS( SELECT 1
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND Lottable09 = @cPalletSSCC)
      BEGIN
   	   SET @nErrNo = 197451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotInASN
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet SSCC
         GOTO Quit
      END
      
      -- Pallet with multi SKU
      IF EXISTS( SELECT 1
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND Lottable09 = @cPalletSSCC
         HAVING COUNT( DISTINCT SKU) > 1)
      BEGIN
         -- Let operator decide the SKU to receive, at SKU screen
         GOTO Quit
      END

	   -- Pallet with single SKU
	   -- SSCC SKU
	   SELECT TOP 1
	      @cSKU = RD.SKU,
	      @cLottable01 = RD.Lottable01, 
	      @cLottable02 = RD.Lottable02, 
	      @cLottable03 = RD.Lottable03, 
	      @cLottable09 = RD.Lottable09
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.UCC WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU AND RD.ExternReceiptKey = UCC.ExternKey AND RD.Lottable09 = UCC.UserDefined03)
      WHERE RD.ReceiptKey = @cReceiptKey
	      AND RD.Lottable09 = @cPalletSSCC
         AND RD.FinalizeFlag <> 'Y'
         AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
      ORDER BY RD.ReceiptLineNumber

      IF @@ROWCOUNT = 0
      BEGIN
   	   -- Non SSCC SKU
   	   SELECT TOP 1
   	      @cSKU = SKU,
   	      @cLottable01 = Lottable01, 
   	      @cLottable02 = Lottable02, 
   	      @cLottable03 = Lottable03, 
   	      @cLottable09 = Lottable09
	      FROM dbo.ReceiptDetail WITH (NOLOCK)
	      WHERE ReceiptKey = @cReceiptKey
		      AND Lottable09 = @cPalletSSCC
            AND FinalizeFlag <> 'Y'
            AND QTYExpected > BeforeReceivedQTY -- line with balance
         ORDER BY ReceiptLineNumber
         
         IF @@ROWCOUNT = 0
         BEGIN
      	   SET @nErrNo = 197452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletReceived
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet SSCC
            GOTO Quit
         END
      END
   END
   
   ELSE IF @cCaseSSCC <> ''
   BEGIN
      -- Decode case SSCC
      SET @cCaseSSCC = SUBSTRING( @cCaseSSCC,  3, 18)
      
	   -- Check if existing case
	   DECLARE @cChkStatus NVARCHAR( 10) = ''
	   SELECT
	      @cSKU = UCC.SKU,
	      @nQTY = UCC.QTY, 
	      @cChkStatus = UCC.Status
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.UCC WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU AND RD.Lottable02 = UCC.UserDefined01 AND RD.Lottable09 = UCC.UserDefined03)
      WHERE RD.ReceiptKey = @cReceiptKey
	      AND UCC.UCCNo = @cCaseSSCC

      SET @nRowCount = @@ROWCOUNT

	   -- Check case in ASN
	   IF @nRowCount = 0
      BEGIN
   	   SET @nErrNo = 197453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Case NotInASN
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Case SSCC
         GOTO Quit
      END

      -- Check case received
      IF @cChkStatus > '0'
      BEGIN
   	   SET @nErrNo = 197454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Case received
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Case SSCC
         GOTO Quit
      END
      
      -- Get case info
	   SELECT TOP 1
	      @cSKU = RD.SKU,
	      @cLottable01 = RD.Lottable01, 
	      @cLottable02 = RD.Lottable02, 
	      @cLottable03 = RD.Lottable03, 
	      @cLottable09 = RD.Lottable09
	   FROM dbo.UCC WITH (NOLOCK)
	      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey  
	         AND RD.SKU = UCC.SKU  
	         AND UCC.UserDefined01 = RD.Lottable02  
	         AND UCC.UserDefined03 = RD.Lottable09)
      WHERE UCC.UCCNo = @cCaseSSCC
         AND RD.ReceiptKey = @cReceiptKey
         AND ISNULL( RD.DuplicateFrom, '') = '' -- Original line
   END


Quit:
   
END

GO