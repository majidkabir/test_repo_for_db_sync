SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_638RcvCfm01                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose        : UA                                                     */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-03-18 1.0  YeeKung WMS-12465 Created                               */
/* 2020-07-13 1.1  Ung     WMS-13555 Change params                         */
/* 2020-11-24 1.2  Ung     WMS-14691 Add serial no params                  */
/* 2022-09-23 1.3  YeeKung WMS-20820 Extended refno length (yeekung01)     */
/* 2023-01-04 1.4  Ung     WMS-21385 Update Receipt.Notes                  */
/* 2023-07-20 1.5  YeeKung WMS-23153 Add Eventlog (yeekung02)              */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_638RcvCfm01](
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
            @cPOKey                       NVARCHAR( 10),
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
            @nRTNFlag                     INT = 0

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_638RcvCfm01 -- For rollback or commit only our own transaction

   IF (@cLottable10 NOT IN ('107ZZZZZ','207ZZZZZ','307ZZZZZ'))
   BEGIN
      SET @nErrNo = 149651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOT10
      GOTO Quit
   END

   SET @cLottable10 = UPPER(@cLottable10)
   SET @cLottable11 = 'ZZ'

   SELECT @cDocType = DOCTYPE, @cRecType = RECType FROM RECEIPT WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
   IF @cDocType = 'R' AND @cRecType IN ('RTN','GRN')
   BEGIN
      SET @nRTNFlag = 1
      SET @cLottable01 = @cLottable10
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

   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cReceiptLineNumber
                  AND ISNULL(DuplicateFrom,'') <> '')
   BEGIN
      SELECT
         @cLottable01          = Lottable01         ,
         @cLottable03          = Lottable03         ,
         @cLottable07          = Lottable07         ,
         @cLottable08          = Lottable08         ,
         @cLottable12          = Lottable12         ,
         @cExternReceiptKey    = ExternReceiptKey   ,
         @cVesselKey           = VesselKey          ,
         @cVoyageKey           = VoyageKey          ,
         @cXdockKey            = XdockKey           ,
         @cContainerKey        = ContainerKey       ,
         @cExportStatus        = ExportStatus       ,
         @cLoadKey             = LoadKey            ,
         @cExternPoKey         = ExternPoKey        ,
         @cPOKey               = POKey              ,
         @cUserDefine01        = UserDefine01       ,
         @cUserDefine02        = UserDefine02       ,
         @cUserDefine03        = UserDefine03       ,
         @cUserDefine04        = UserDefine04       ,
         @cUserDefine05        = UserDefine05       ,
         @dtUserDefine06       = UserDefine06 ,
         @dtUserDefine07       = UserDefine07       ,
         @cUserDefine08        = UserDefine08       ,
         @cUserDefine09        = UserDefine09       ,
         @cUserDefine10        = UserDefine10       ,
         @cSKUUOM              = UOM                ,
         @cChannel             = Channel
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = (  SELECT Duplicatefrom FROM dbo.ReceiptDetail WITH (NOLOCK)
                                 WHERE StorerKey = @cStorerKey
                                    AND ReceiptKey = @cReceiptKey
                                    AND ReceiptLineNumber = @cReceiptLineNumber)

      UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
      SET
         Lottable01        = CASE WHEN @nRTNFlag <> 1 THEN ISNULL(@cLottable01,'') ELSE Lottable01 END,
         Lottable03        = ISNULL(@cLottable03,''),
         Lottable07        = ISNULL(@cLottable07,''),
         Lottable08        = ISNULL(@cLottable08,''),
         Lottable10        = ISNULL(@cLottable10,''),  --Added by L4L
         Lottable11        = ISNULL(@cLottable11,''),  --Added by L4L
         Lottable12        = ISNULL(@cLottable12,''),
         ExternReceiptKey  = ISNULL(@cExternReceiptKey,''),
         VesselKey         = ISNULL(@cVesselKey,''),
         VoyageKey         = ISNULL(@cVoyageKey,''),
         XdockKey          = ISNULL(@cXdockKey,''),
         ContainerKey      = ISNULL(@cContainerKey,''),
         ExportStatus      = ISNULL(@cExportStatus,''),
         LoadKey           = ISNULL(@cLoadKey,''),
         ExternPoKey       = ISNULL(@cExternPoKey,''),
         POKey             = ISNULL(@cPOKey,''),
         UserDefine01      = ISNULL(@cUserDefine01,''),
         UserDefine02      = ISNULL(@cUserDefine02,''),
         UserDefine03      = ISNULL(@cUserDefine03,''),
         UserDefine04      = ISNULL(@cUserDefine04,''),
         UserDefine05      = ISNULL(@cUserDefine05,''),
         UserDefine06      = ISNULL(@dtUserDefine06,''),
         UserDefine07      = ISNULL(@dtUserDefine07,''),
         UserDefine08      = ISNULL(@cUserDefine08,''),
         UserDefine09      = ISNULL(@cUserDefine09,''),
         UserDefine10      = ISNULL(@cUserDefine10,''),
         UOM               = ISNULL(@cSKUUOM,''),
         Channel           = ISNULL(@cChannel,'')
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 149652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRcptDetFail
         GOTO Quit
      END
   END
   
   IF @cData1 <> ''
   BEGIN
      UPDATE dbo.Receipt SET
         Notes = @cData1, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE ReceiptKey = @cReceiptKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 149653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Rcpt Fail
         GOTO Quit
      END
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

   COMMIT TRAN rdt_638RcvCfm01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_638RcvCfm01
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO