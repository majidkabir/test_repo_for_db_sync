SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898UCCExtVal05                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-08-06 1.0  James    WMS-17648. Created                             */
/***************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal05]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@nErrNo      INT           OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      DECLARE @cPO            NVARCHAR( 18) = ''
      DECLARE @cUCC_PO        NVARCHAR( 18) = ''
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey
                      AND   RECType = 'CASEPACK')
         GOTO Quit

      -- If pallet not receive before then no need further check
      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey
                      AND   ToId = @cToID
                      GROUP BY ReceiptKey
                      HAVING ISNULL( SUM( BeforeReceivedQty), 0) > 0)
         GOTO Quit

      SELECT TOP 1 @cPO = Lottable03
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   ToId = @cToID
      AND   BeforeReceivedQty > 0
      ORDER BY 1
      
      SELECT TOP 1 @cUCC_PO = Lottable03
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cUCC
      ORDER BY 1

      -- UCCs in One Pallet Id must have the same Po Number
      IF @cPO <> @cUCC_PO      
      BEGIN
       SET @nErrNo = 173101
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC PONO Diff
       GOTO Quit
      END
   END
   

Quit:

END

GO