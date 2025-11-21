SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638ExtUpd04                                     */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-06-09 1.0  James      WMS-16735 Created                         */
/* 2022-09-23 1.1  YeeKung    WMS-20820 Extended refno length (yeekung01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtUpd04] (
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
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT
   DECLARE @curRD                CURSOR
   DECLARE @cReceiptLineNumber   NVARCHAR( 5) = ''
   DECLARE @nReceived            INT = 0
   DECLARE @cIT69Label           NVARCHAR( 10)
   DECLARE @cCaseIDLabel         NVARCHAR( 10)

   SET @nErrNo = 0

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_638ExtUpd04

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep = 8 -- Finalize ASN
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT ReceiptLineNumber
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND  ( ISNULL( UserDefine08, '') <> '' OR ISNULL( UserDefine09, '') <> '')
            AND   FinalizeFlag = 'Y'
            OPEN @curRD
            FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.RECEIPTDETAIL SET
                  UserDefine10 = QtyReceived,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE ReceiptKey = @cReceiptKey
               AND   ReceiptLineNumber = @cReceiptLineNumber

               IF @@ERROR <> 0
                  GOTO RollBackTran

               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_638ExtUpd04 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN


END

GO