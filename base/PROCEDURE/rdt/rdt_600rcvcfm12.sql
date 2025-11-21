SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600RcvCfm12                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Receive using ucc                                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-10-14  Chermaine 1.0   WMS-18007 Created                              */
/* 2022-05-30  Ung       1.1   WMS-19757 case SSCC, update UDF03 = ToID       */
/* 2022-06-10  Yee Kung  1.2   WMS-19808 Default Lottable06                   */
/*                             change UCC.UDF03 to UDF04 = ToID               */
/* 29-08-2022  Ung       1.3   WMS-20644 Add SSCC pallet with multi lines     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600RcvCfm12] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,
   @cSerialNo      NVARCHAR( 30) = '',
   @nSerialQTY     INT = 0,
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount     INT
   DECLARE @nU_Qty         INT
   DECLARE @bSuccess       INT
   DECLARE @nRecByUcc      INT
   DECLARE @cUserDefine10  NVARCHAR( 30)
   DECLARE @cSSCCBarcode   NVARCHAR( 60)
   DECLARE @cSSCC          NVARCHAR( 18)
   DECLARE @curReceipt     CURSOR

   SELECT
      @cSSCCBarcode = V_String43
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nRecByUcc = 0
   SET @cSSCC = ''

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_600RcvCfm12 -- For rollback or commit only our own transaction

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      SELECT top 1 @cLottable06=lottable06  
      FROM receiptdetail (NOLOCK)  
      WHERE receiptkey=@cReceiptKey  
      AND SKU=@cSKUCode  
      AND ISNULL(duplicatefrom,'') =''  

   	-- Receive
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cSKUCode      = @cSKUCode,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = @nSKUQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      IF (@cSSCCBarcode LIKE '00%') OR (@cSSCCBarcode LIKE '95%')
      BEGIN
      	SET @cSSCC = SUBSTRING( @cSSCCBarcode,  3, 18)

      	--PalletSSCC (00)030244808343339608(93)
         IF @cSSCCBarcode LIKE '00%'
         BEGIN
         	DECLARE CUR_UCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT
      	      U.UccNo, U.Qty
            FROM receiptDetail RD WITH (NOLOCK)
            JOIN UCC U WITH (NOLOCK) ON (RD.StorerKey = U.Storerkey AND RD.ExternReceiptKey = U.ExternKey AND RD.Lottable09 = U.Userdefined03 AND  RD.SKU = U.SKU)
            WHERE RD.StorerKey = @cStorerKey
            AND RD.ReceiptKey = @cReceiptKey
            AND RD.Lottable09 = @cSSCC
            AND U.STATUS = '0'
            OPEN CUR_UCC
            FETCH NEXT FROM CUR_UCC INTO @cUCC,@nU_Qty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
            	UPDATE UCC WITH (ROWLOCK) SET
      	         Receiptkey = @cReceiptKey,
      	         ReceiptLineNumber = @cReceiptLineNumberOutput,
      	         STATUS = '1', 
      	         EditDate = GETDATE(), 
      	         EditWho = SUSER_NAME()
      	      WHERE UccNo = @cUCC
      	      AND Storerkey = @cStorerKey
      	      AND STATUS = 0

      	      IF @@ERROR <> 0
      	      BEGIN
      	   	   SET @nErrNo = 177601
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUccFail'
                  GOTO RollBackTran
      	      END

      	      SET @nSKUQTY = @nSKUQTY - @nU_Qty
      	      IF @nSKUQTY = 0
      	         BREAK

            	FETCH NEXT FROM CUR_UCC INTO @cUCC, @nU_Qty
            END

         END
         --CaseSSCC (95)030244893132694952
         ELSE IF @cSSCCBarcode LIKE '95%'
         BEGIN
      	   SELECT
      	      @cUCC = U.UccNo
      	   FROM UCC U WITH (NOLOCK)
      	   JOIN receiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = U.Storerkey AND RD.ExternReceiptKey = U.ExternKey AND RD.Lottable09 = U.Userdefined03 AND  RD.SKU = U.SKU)
            WHERE U.UccNo = @cSSCC
            AND U.storerKey = @cStorerKey
            AND RD.ReceiptKey = @cReceiptKey
            AND U.STATUS = '0'

            IF @cUCC = ''
            BEGIN
               INSERT INTO dbo.UCC
                  (UCCNo, StorerKey, SKU, QTY, Status, ExternKey, ReceiptKey, ReceiptLineNumber, UserDefined03)
               VALUES
                  (@cUCC, @cStorerKey, @cSKUCode, @nSKUQTY, '1', '', @cReceiptKey, @cReceiptLineNumberOutput, @cToID)
      	      IF @@ERROR <> 0
      	      BEGIN
      	   	   SET @nErrNo = 177602
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsUccFail'
                  GOTO RollBackTran
      	      END
            END
            ELSE
            BEGIN
         	   UPDATE UCC WITH (ROWLOCK) SET
      	         Receiptkey = @cReceiptKey,
      	         ReceiptLineNumber = @cReceiptLineNumberOutput,
      	         STATUS = '1', 
      	         UserDefined04 = @cToID, 
      	         EditDate = GETDATE(), 
      	         EditWho = SUSER_NAME()
      	      WHERE UccNo = @cUCC
      	      AND Storerkey = @cStorerKey
      	      AND STATUS = 0

      	      IF @@ERROR <> 0
      	      BEGIN
      	   	   SET @nErrNo = 177603
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUccFail'
                  GOTO RollBackTran
      	      END
      	   END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_600RcvCfm12
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO