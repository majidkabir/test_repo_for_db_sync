SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_638RcvCfm06                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-11-17 1.0  Ung     WMS-14691 Created                               */
/* 2021-01-27 1.1  James   WMS-16163 Add To Loc checking (james01)         */
/* 2021-04-09 1.2  James   WMS-16506 Change captureinfo update seq(james02)*/
/* 2021-05-06 1.3  James   WMS-16735 Add grade update to RDetail (james03) */
/* 2022-09-23 1.4  YeeKung WMS-20820 Extended refno length (yeekung01)     */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_638RcvCfm06](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @dArriveDate    DATETIME,
   @cReceiptKey    NVARCHAR( 10),
   @cRefNo         NVARCHAR( 60), --(yeekung01)
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
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
   @cData1         NVARCHAR( 60),
   @cData2         NVARCHAR( 60),
   @cData3         NVARCHAR( 60),
   @cData4         NVARCHAR( 60),
   @cData5         NVARCHAR( 60),
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @cSerialNo      NVARCHAR( 60),
   @nSerialQTY     INT,
   @tConfirmVar    VARIABLETABLE READONLY,
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT

) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nisValidLoc INT
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cGrade      NVARCHAR( 30)

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_638RcvCfm06

   -- Receive
   EXEC rdt.rdt_Receive_V7
      @nFunc         = @nFunc,
      @nMobile       = @nMobile,
      @cLangCode     = @cLangCode,
      @nErrNo        = @nErrNo  OUTPUT,
      @cErrMsg       = @cErrMsg OUTPUT,
      @cStorerKey    = @cStorerKey,
      @cFacility     = @cFacility,
      @cReceiptKey   = @cReceiptKey,
      @cPOKey        = 'NOPO',
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
      @cLottable03   = '', -- @cLottable03, Full set?
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
      @nNOPOFlag     = 1,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode,
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Stock arrive date
   IF @dArriveDate IS NOT NULL
   BEGIN
      IF EXISTS( SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptDate <> @dArriveDate)
      BEGIN
         UPDATE Receipt SET
            ReceiptDate = @dArriveDate,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
   END

   -- Actual courier name, tracking no
   IF @cData1 <> '' OR
      @cData2 <> ''
   BEGIN
      IF EXISTS( SELECT 1
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
            AND (UserDefine02 <> @cData2
             OR  UserDefine04 <> @cData1))
      BEGIN
         UPDATE ReceiptDetail SET
            UserDefine02 = @cData2,
            UserDefine04 = @cData1,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
   END

   IF (SELECT COUNT(1)
      FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
      LEFT JOIN dbo.SKUINFO SI WITH (NOLOCK) ON ( RD.STORERKEY = SI.STORERKEY AND RD.SKU = SI.SKU)
      LEFT JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON
         ( ISNULL( RD.Lottable01, '') = ISNULL( CLK.UDF01, '') AND ISNULL( SI.Extendedfield02, '') = ISNULL( CLK.UDF02, '') AND ISNULL( SI.Extendedfield03, '') = ISNULL( CLK.UDF03, ''))
      LEFT JOIN LOC LOC WITH (NOLOCK) ON ( RD.TOLOC = LOC.LOC AND LOC.PutawayZone = CLK.LONG AND LOC.LocationCategory = CLK.SHORT)
      WHERE RD.RECEIPTKEY = @cReceiptKey
      AND RD.BeforeReceivedQty <> 0
      AND RD.SKU = @cSKUCode
      AND RD.ReceiptLineNumber = @cReceiptLineNumber
      AND CLK.LISTNAME = 'NIKERecLoc'
      AND CLK.STORERKEY = @cStorerKey
      AND LOC.LOC= @cToLOC) =
      (SELECT COUNT(1) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE RECEIPTKEY = @cReceiptKey
         AND SKU = @cSKUCode
         AND ReceiptLineNumber = @cReceiptLineNumber
         AND BeforeReceivedQty <> 0)
   BEGIN
      SET @nisValidLoc = 1
   END
   ELSE
   BEGIN
      SET @nisValidLoc = 0
   END

   IF @nisValidLoc = 0
   BEGIN
      SET @nErrNo = 162501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TO LOC
      GOTO RollBackTran
   END

   IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   ReceiptLineNumber = @cReceiptLineNumber
               AND   ( ISNULL( UserDefine08, '') <> '' OR ISNULL( UserDefine09, '') <> ''))
   BEGIN
      SELECT @cGrade = V_String46,
             @cUserName = UserName
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF @cGrade = 'A'
      BEGIN
         UPDATE dbo.RECEIPTDETAIL SET
            UserDefine10 = CASE WHEN FinalizeFlag = 'N' THEN BeforeReceivedQty ELSE QtyReceived END,
            EditWho = @cUserName,
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '2', -- Receiving
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cReceiptKey   = @cReceiptKey,
      @cRefNo1       = @cRefNo,
      @cLocation     = @cToLOC,
      @cID           = @cToID,
      @cSKU          = @cSKUCode,
      @cUOM          = @cSKUUOM,
      @nQTY          = @nSKUQTY,
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = @dLottable05,
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
      @cSerialNo     = @cSerialNo

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_638RcvCfm06 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO