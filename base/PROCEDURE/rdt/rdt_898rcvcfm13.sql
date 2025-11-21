SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898RcvCfm13                                        */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2024-10-14 1.0  CYU027  FCR-759 Created.                                */
/***************************************************************************/
CREATE PROC [RDT].[rdt_898RcvCfm13](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
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
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10)
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine08           NVARCHAR(30)
   DECLARE @cUserDefine09           NVARCHAR(30)
   DECLARE @nRowCount               INT
   DECLARE @nTranCount              INT
   DECLARE @cUCCReceiptLineNumber   NVARCHAR( 5)


   SELECT   @cUserDefine08 = V_String38,
            @cUserDefine09 = V_String39
   FROM   RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile


   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_898RcvCfm13 -- For rollback or commit only our own transaction

   -- UCC Found in db
   IF EXISTS ( SELECT 1
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                 AND UCCNo = @cUCC)
   BEGIN

      -- USE lottables in RECEIPTDETAIL
      SELECT TOP 1
         @cLottable01 = RD.Lottable01,
         @cLottable02 = RD.Lottable02,
         @cLottable03 = RD.Lottable03,
         @dLottable04 = RD.Lottable04
      FROM RECEIPTDETAIL RD (NOLOCK )
         JOIN UCC U (NOLOCK )
            ON U.ExternKey = RD.ExternReceiptKey
               AND U.SKU = RD.SKU
               AND U.Userdefined07 = RD.ExternLineNo
      WHERE RD.ReceiptKey = @cReceiptKey
        AND U.Storerkey = @cStorerKey
        AND U.UCCNO = @cUCC
      ORDER BY RD.ReceiptLineNumber
   END


   DECLARE
      @cLottable06    NVARCHAR( 30),
      @cLottable07    NVARCHAR( 30),
      @cLottable08    NVARCHAR( 30),
      @cLottable09    NVARCHAR( 30),
      @cLottable10    NVARCHAR( 30),
      @cLottable11    NVARCHAR( 30),
      @cLottable12    NVARCHAR( 30),
      @dLottable13    DATETIME,
      @dLottable14    DATETIME,
      @dLottable15    DATETIME

   SET @nErrNo = 0
   EXEC rdt.rdt_Receive_V7
        @nFunc          = @nFunc,
        @nMobile        = @nMobile,
        @cLangCode      = @cLangCode,
        @nErrNo         = @nErrNo  OUTPUT,
        @cErrMsg        = @cErrMsg OUTPUT,
        @cStorerKey     = @cStorerKey,
        @cFacility      = @cFacility,
        @cReceiptKey    = @cReceiptKey,
        @cPOKey         = @cPOKey,
        @cToLOC         = @cToLOC,
        @cToID          = @cToID,
        @cSKUCode       = @cSKUCode,
        @cSKUUOM        = @cSKUUOM,
        @nSKUQTY        = @nSKUQTY,
        @cUCC           = @cUCC,
        @cUCCSKU        = @cUCCSKU,
        @nUCCQTY        = @nUCCQTY,
        @cCreateUCC     = @cCreateUCC,
        @cLottable01    = @cLottable01,
        @cLottable02    = @cLottable02,
        @cLottable03    = @cLottable03,
        @dLottable04    = @dLottable04,
        @dLottable05    = NULL,
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
        @nNOPOFlag      = @nNOPOFlag,
        @cConditionCode = @cConditionCode,
        @cSubreasonCode = @cSubreasonCode
   IF @nErrNo <> 0
      GOTO RollBackTran

   SELECT @cUCCReceiptLineNumber = ReceiptLineNumber
      FROM UCC WITH (ROWLOCK)
   WHERE StorerKey = @cStorerKey
     AND UCCNo = @cUCC
     AND SKU = @cUCCSKU

   SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
   IF @nErrNo <> 0 OR @nRowCount <> 1
      GOTO RollBackTran

   --Update the UCC table userdefined01 from the RECEIPTDETAIL.UserDefine09.
   UPDATE dbo.UCC WITH (ROWLOCK) SET
      Userdefined09 = @cUserDefine09,
      EditDate = GETDATE(),
      EditWho = SUSER_SNAME()
   WHERE StorerKey = @cStorerKey
     AND UCCNo = @cUCC
     AND SKU = @cUCCSKU
     AND ReceiptLineNumber = @cUCCReceiptLineNumber

   SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
   IF @nErrNo <> 0
      GOTO RollBackTran

   --Update the ID.UserDefined01 from the RECEIPTDETAIL.UserDefine08.
   UPDATE dbo.ID WITH (ROWLOCK) SET
                                    Userdefine01 = @cUserDefine08,
                                    EditDate = GETDATE(),
                                    EditWho = SUSER_SNAME()
   WHERE Id= @cToID

   SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
   IF @nErrNo <> 0
      GOTO RollBackTran

-- Update the ID table userdefined01 from the RECEIPTDETAIL.UserDefine08.
   UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
       UserDefine08 = @cUserDefine08,
       UserDefine09 = @cUserDefine09,
       EditDate = GETDATE(),
       EditWho = SUSER_SNAME()
   FROM dbo.ReceiptDetail
   WHERE ReceiptKey = @cReceiptKey
     AND ReceiptLineNumber = @cUCCReceiptLineNumber

   SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
   IF @nErrNo <> 0 OR @nRowCount <> 1
      GOTO RollBackTran

   GOTO Quit


   RollBackTran:
   IF @nErrNo = 0
      SET @nErrNo = 226803
--    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
   ROLLBACK TRAN rdt_898RcvCfm13

   Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO