SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638DecodeSP03                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Get SKU based on ReceiptDetail.UserDefine08                       */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 04-01-2023  Ung       1.0   WMS-21385 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_638DecodeSP03] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 60), 
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nUCCQTY      INT            OUTPUT,
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
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Get Receipt info
   IF @cRefNo <> ''
   BEGIN
      SELECT @cSKU = RD.SKU
      FROM dbo.Receipt R WITH (NOLOCK)
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         -- AND R.Facility = @cFacility
         AND R.Status <> '9'
         AND R.ASNStatus <> 'CANC'
         AND R.ReceiptGroup = 'ECOM'
         AND R.Userdefine02 = @cRefNo
         AND RD.Userdefine08 = @cBarcode
         AND RD.QTYExpected > RD.BeforeReceivedQTY
      ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
   END

END

GO