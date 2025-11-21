SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638RcvCfm02                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose        : KR HM                                                  */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-03-18 1.0  YeeKung WMS-12465 Created                               */
/* 2020-07-22 1.1  Ung     WMS-13555 Change params                         */
/* 2020-11-24 1.2  Ung     WMS-14691 Add serial no params                  */
/* 2020-03-18 1.3  YeeKung WMS-12488 Add On update lot11,lot07(yeekung01)  */
/* 2022-09-23 1.4  YeeKung WMS-20820 Extended refno length (yeekung01)     */
/* 2023-07-20 1.5  YeeKung WMS-23153 Add Eventlog (yeekung02)              */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_638RcvCfm02](
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
            @cLottable11value             NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT

   SELECT @cSubreasonCode=subreasoncode
   from receiptdetail (nolock)
   where ReceiptKey=@cReceiptKey
      AND sku=@cSKUCode

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_638RcvCfm02 -- For rollback or commit only our own transaction

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

   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ReceiptKey = @cReceiptKey
               AND ISNULL(DuplicateFrom,'')<>'')
   BEGIN
      SELECT
         @cLottable01          = Lottable01         ,
         @cLottable03          = Lottable03         ,
         @dLottable04          = Lottable04         ,
         @dLottable05          = Lottable05
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = (  SELECT Duplicatefrom FROM dbo.ReceiptDetail WITH (NOLOCK)
                                 WHERE StorerKey = @cStorerKey
                                    AND ReceiptKey = @cReceiptKey
                                    AND ReceiptLineNumber=@cReceiptLineNumber)

      UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
      SET
         Lottable01        = ISNULL(@cLottable01,''),
         Lottable03        = ISNULL(@cLottable03,''),
         Lottable04        = ISNULL(@dLottable04,''),
         Lottable05        = ISNULL(@dLottable05,'')
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber=@cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 154301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRcptDetFail
         GOTO Quit
      END

   END
   ELSE
   BEGIN   --(yeekung01)

       SELECT   
        @dLottable04          =  lottable04 
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      and ReceiptLineNumber=@cReceiptLineNumber

      SET @cLottable11value =  CASE WHEN ISDATE(@dLottable04)=0 THEN '' ELSE CAST(@dLottable04 AS nvarchar(20)) END 

      UPDATE  dbo.ReceiptDetail with (rowlock)
      SET   Lottable11        = @cLottable11value , 
            Lottable13        = @dLottable04, 
            SubReasonCode     = ISNULL(@cSubreasonCode,'')  
      WHERE StorerKey = @cStorerKey          
      AND ReceiptKey = @cReceiptKey 
      and ReceiptLineNumber=@cReceiptLineNumber
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

   COMMIT TRAN rdt_638RcvCfm02
   GOTO Quit

RollBackTran:

   ROLLBACK TRAN rdt_638RcvCfm02
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO