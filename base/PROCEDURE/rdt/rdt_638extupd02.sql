SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638ExtUpd02                                     */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-04-11 1.0  YeeKung    WMS-12488 Created  (yeekung01)            */
/* 2020-07-13 1.1  Ung        WMS-13555 Change params                   */
/* 2020-08-26 1.2  Ung        WMS-13962 Fix option changed              */
/* 2022-09-23 1.3  YeeKung    WMS-20820 Extended refno length (yeekung02)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtUpd02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung01)
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cData1        NVARCHAR( 60),
   @cData2        NVARCHAR( 60),
   @cData3        NVARCHAR( 60),
   @cData4        NVARCHAR( 60),
   @cData5        NVARCHAR( 60),
   @cOption       NVARCHAR( 1),
   @dArriveDate   DATETIME,
   @tExtUpdateVar VariableTable READONLY,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT
   DECLARE @curRD                CURSOR
   DECLARE @cReceiptLineNumber   NVARCHAR( 5) = ''
   DECLARE @nReceived            INT = 0
   DECLARE @cEcomLabel NVARCHAR( 10)

   SET @nErrNo = 0

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep = 1 -- RefNo, ASN
      BEGIN
         IF @nInputKey = 1
         BEGIN

            SET @cEcomLabel = rdt.rdtGetConfig( @nFunc, 'EcomLabel', @cStorerKey)
            IF @cEcomLabel = '0'
               SET @cEcomLabel = ''
            IF (@cEcomLabel<>'')
            BEGIN
               DECLARE @cLabelPrinter NVARCHAR(10)
               SELECT @cLabelPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

               -- Common params
               DECLARE @tIT69 AS VariableTable

               DECLARE @cCursor_ReceiptLineNo NVARCHAR(20),
                       @nCursor_Qty INT


               DECLARE Receipt_cursor CURSOR FOR
               SELECT RECEIPTLINENUMBER,QtyExpected
               FROM RECEIPTDETAIL (NOLOCK)
               WHERE receiptkey=@cReceiptKey

               OPEN Receipt_cursor;
               FETCH NEXT FROM Receipt_cursor
               INTO @cCursor_ReceiptLineNo,@nCursor_Qty;
               WHILE @@FETCH_STATUS = 0
               BEGIN

                  INSERT INTO  @tIT69 (Variable, Value) VALUES ( '@cParam1', @cReceiptKey)
                  INSERT INTO  @tIT69 (Variable, Value) VALUES ( '@cParam2', @cCursor_ReceiptLineNo)
                  INSERT INTO  @tIT69 (Variable, Value) VALUES ( '@cParam3', '')
                  INSERT INTO  @tIT69 (Variable, Value) VALUES ( '@cParam4',CASE WHEN ISNULL(@nCursor_Qty,'')='' THEN 0 ELSE @nCursor_Qty END )
                  INSERT INTO  @tIT69 (Variable, Value) VALUES ( '@cParam5', '1')

                  -- Print label
                  EXEC RDT.rdt_Print
                        @nMobile      = @nMobile
                     , @nFunc         = @nFunc
                     , @cLangCode     = @cLangCode
                     , @nStep         = 0
                     , @nInputKey     = 1
                     , @cFacility     = @cFacility
                     , @cStorerKey    = @cStorerKey
                     , @cLabelPrinter = @cLabelPrinter
                     , @cPaperPrinter = ''
                     , @cReportType   = @cEcomLabel
                     , @tReportParam  = @tIT69
                     , @cSourceType   = 'rdt_638ExtUpd02'
                     , @nErrNo        = @nErrNo  OUTPUT
                     , @cErrMsg       = @cErrMsg OUTPUT

                  IF (@nErrNo <>'')
                  BEGIN
                     CLOSE Receipt_cursor;
                     DEALLOCATE Receipt_cursor;
                     GOTO Quit
                  END

                  DELETE @tIT69

                  FETCH NEXT FROM Receipt_cursor
                  INTO @cCursor_ReceiptLineNo,@nCursor_Qty;
               END

               CLOSE Receipt_cursor;
               DEALLOCATE Receipt_cursor;
            END

         END
      END

      IF @nStep = 8 -- Finalize ASN?
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOption = '9' -- Abort ASN
            BEGIN
               -- If line finalized, cannot abort
               IF EXISTS ( SELECT 1 FROM RECEIPTDETAIL RD WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                           AND   RD.FinalizeFlag = 'Y')
               BEGIN
                  SET @nErrNo = 154801
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Line Finalized
                  GOTO Quit
               END

               SET @nTranCount = @@TRANCOUNT

               BEGIN TRAN
               SAVE TRAN rdt_EcomReturn_FinalizeOpt2

               -- Reverse receivedqty (beforereceivedqty)
               SET @curRD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ReceiptLineNumber
               FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   RD.FinalizeFlag <> 'Y'
               AND   RD.BeforeReceivedQty > 0
               OPEN @curRD
               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  UPDATE dbo.RECEIPTDETAIL SET
                     BeforeReceivedQty = 0,
                     ToID = '',
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE ReceiptKey = @cReceiptKey
                  AND   ReceiptLineNumber = @cReceiptLineNumber
                  SET @nErrNo = @@ERROR
                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 154802
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
               END

               IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL AS rd WITH (NOLOCK)
                           WHERE rd.ReceiptKey = @cReceiptKey
                           AND   (( rd.FinalizeFlag = 'Y' AND rd.QtyReceived > 0) OR ( rd.FinalizeFlag <> 'Y' AND rd.BeforeReceivedQty > 0)))
                  SET @nReceived = 1

               UPDATE dbo.Receipt SET
                  Status = '0',
                  ASNStatus = CASE WHEN @nReceived = 1 THEN ASNStatus ELSE '0' END,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE ReceiptKey = @cReceiptKey
               SET @nErrNo = @@ERROR
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 154803
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END

               GOTO Commit_FinalizeOpt2

               RollBackTran:
                  ROLLBACK TRAN rdt_EcomReturn_FinalizeOpt2 -- Only rollback change made here

               Commit_FinalizeOpt2:
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN rdt_EcomReturn_FinalizeOpt2
            END
         END
      END
   END

Quit:


GO