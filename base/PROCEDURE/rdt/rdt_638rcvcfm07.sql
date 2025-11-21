SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/***************************************************************************/
/* Store procedure: rdt_638RcvCfm07                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose        : 03->07                                                 */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-02-02 1.0  YeeKung WMS-16294 Created                               */
/* 2022-09-23 1.1  YeeKung WMS-20820 Extended refno length (yeekung01)     */
/* 2023-07-20 1.2  YeeKung WMS-23153 Add Eventlog (yeekung02)              */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_638RcvCfm07](
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

   DECLARE @nTranCount           INT

   DECLARE  @cExternReceiptKey            NVARCHAR( 20),
            @cVesselKey                   NVARCHAR( 18),
            @cVoyageKey                   NVARCHAR( 18),
            @cXdockKey                    NVARCHAR( 18),
            @cContainerKey                NVARCHAR( 18),
            @cExportStatus                NVARCHAR(  1),
            @cLoadKey                     NVARCHAR( 10),
            @cExternPoKey                 NVARCHAR( 20),
            @cUserDefine01                NVARCHAR( 30),
            @cUserDefine02                NVARCHAR( 30),
            @cUserDefine03                NVARCHAR( 30),
            @cUserDefine04                NVARCHAR( 30),
            @cUserDefine05                NVARCHAR( 30),
            @dtUserDefine06               DATETIME,
            @dtUserDefine07               DATETIME,
            @cUserDefine08                NVARCHAR( 30),
            @cUserDefine09                NVARCHAR( 30),
            @cUserDefine10                NVARCHAR( 30),
            @cChannel                     NVARCHAR( 20),
            @cDocType                     NVARCHAR( 1),
            @cRecType                     NVARCHAR( 10),
            @nRTNFlag                     INT = 0,
            @cOrderkey                    NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_638RcvCfm07 -- For rollback or commit only our own transaction

      SELECT @cOrderkey=orderkey
      FROM receipt R (nolock) join orders o (NOLOCK)
      ON R.ExternReceiptkey=o.externorderkey
      WHERE ReceiptKey=@cReceiptKey
         AND R.storerkey=@cstorerkey


      IF EXISTS (SELECT 1 from receiptdetail (NOLOCK)
               WHERE ReceiptKey=@cReceiptKey
               AND storerkey=@cstorerkey
               AND SKU=@cSKUCode)
      BEGIN
         UPDATE ReceiptDetail WITH (ROWLOCK)
         SET QTYExpected=QTYExpected+1
         WHERE ReceiptKey=@cReceiptKey
            AND storerkey=@cstorerkey
            AND SKU=@cSKUCode

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo= 163201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Copy OrderDetail to ReceiptDetail
         INSERT INTO ReceiptDetail
            (ReceiptKey, ReceiptLineNumber,ExternLineNo,externreceiptkey,ConditionCode,
             Userdefine01, Userdefine02, Userdefine03, Lottable02,Lottable06,Lottable07,
             StorerKey, SKU, QTYExpected, Packkey, UOM, ToLOC,
             userdefine04, Lottable03)    --(cc01)
         SELECT
            @cReceiptKey, OD.OrderLineNumber,OD.externlineno,Od.externorderkey,'OK',    --(yeekung01)
            OD.Userdefine01, OD.Userdefine02, OD.Userdefine03, OD.Lottable02, LOT.Lottable06,
            Lot.Lottable07,OD.storerkey,OD.SKU, 1, OD.PackKey, OD.UOM, '',
            userdefine04, OD.lottable03 --(cc01)
         FROM OrderDetail OD WITH (NOLOCK)
         JOIN   Pickdetail   PD (NOLOCK)
            ON (OD.OrderKey=PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.SKU = PD.SKU) --INC1312311
         JOIN  LOTATTRIBUTE LOT (NOLOCK) ON (PD.Lot=LOT.Lot AND PD.SKU = LOT.SKU AND PD.STORERKEY = LOT.STORERKEY)
         WHERE OD.OrderKey = @cOrderKey
            AND OD.ShippedQty<>0
            AND OD.sku=@cSKUCode
         GROUP BY OD.OrderLineNumber,OD.externlineno,Od.externorderkey, --(yeekung01)
                  OD.Userdefine01, OD.Userdefine02, OD.Userdefine03, OD.Lottable02,
                  LOT.Lottable06,Lot.Lottable07,OD.storerkey,OD.SKU, OD.ShippedQty, OD.PackKey, OD.UOM ,
                  userdefine04, OD.lottable03 --(cc01)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo= 163202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

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
         @nNOPOFlag     = 1,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
      SET
         conditioncode='OK'
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber=@cReceiptLineNumber

      IF @@ERROR<>''
      BEGIN
         SET @nErrNo = 163203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRcptDetFail
         GOTO RollBackTran
      END

   -- EventLog (yeekung02)
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

   COMMIT TRAN rdt_638RcvCfm07
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_638RcvCfm07
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO