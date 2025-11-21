SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_638ExtUpd01                                     */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-11-21 1.0  James      WMS-10952. Created                        */
/* 2020-07-13 1.1  Ung        WMS-13555 Change params                   */
/* 2020-10-08 1.2  James      WMS-15363 Update receiptdetail.toloc when */
/*                            finalize ASN (james01)                    */
/* 2022-09-23 1.3  YeeKung   WMS-20820 Extended refno length (yeekung02)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_638ExtUpd01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung02)
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
   DECLARE @cToLoc               NVARCHAR( 10)
   DECLARE @cNewLottable12       NVARCHAR( 30)
   
   SET @nErrNo = 0

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep = 8 -- Finalie ASN?
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_EcomReturn_FinalizeOpt
               
         IF @nInputKey = 1
         BEGIN
            -- (james01)
            IF @cOption = '1' -- Yes
            BEGIN
               -- Reverse receivedqty (beforereceivedqty)
               SET @curRD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ReceiptLineNumber, Lottable12
               FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   RD.FinalizeFlag = 'Y'
               AND   RD.QtyReceived > 0
               OPEN @curRD
               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cLottable12
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @cToLoc = ''
                  SELECT @cToLoc = LEFT( UDF02, 10)
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'ASNSUBRSN'
                  AND   Code = @cLottable12
                  AND   Storerkey = @cStorerKey
                  AND   UDF01 <> 'DEFAULT'
                  
                  IF @cToLoc = ''
                  BEGIN
                     SELECT @cToLoc = LEFT( UserDefine04, 10)
                     FROM dbo.FACILITY WITH (NOLOCK)
                     WHERE Facility = @cFacility
                  END
                  
                  IF @cToLoc = ''
                  BEGIN
                     SET @nErrNo = 146452
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- No ToLoc
                     GOTO RollBackTran
                  END
                  
                  IF @cLottable12 <> ''
                  BEGIN
                     UPDATE dbo.RECEIPTDETAIL SET 
                        ToLoc = @cToLoc,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE ReceiptKey = @cReceiptKey
                     AND   ReceiptLineNumber = @cReceiptLineNumber
                     SET @nErrNo = @@ERROR
                  END
                  ELSE
                  BEGIN
                     SET @cNewLottable12 = ''
                     SELECT @cNewLottable12 = Code
                     FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'ASNSUBRSN'
                     AND   Code = @cLottable12
                     AND   Storerkey = @cStorerKey
                     AND   UDF01 = 'DEFAULT'

                     UPDATE dbo.RECEIPTDETAIL SET 
                        ToLoc = @cToLoc, 
                        Lottable12 = @cNewLottable12,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE ReceiptKey = @cReceiptKey
                     AND   ReceiptLineNumber = @cReceiptLineNumber
                     SET @nErrNo = @@ERROR
                  END
                  
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cLottable12
               END               
            END
            
            IF @cOption = '9' -- No
            BEGIN
               -- If line finalized, cannot abort
               IF EXISTS ( SELECT 1 FROM RECEIPTDETAIL RD WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                           AND   RD.FinalizeFlag = 'Y')
               BEGIN
                  SET @nErrNo = 146451
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Line Finalized
                  GOTO Quit
               END

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
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END
            END
         END
         
         GOTO Commit_FinalizeOpt

         RollBackTran:
            ROLLBACK TRAN rdt_EcomReturn_FinalizeOpt -- Only rollback change made here

         Commit_FinalizeOpt:
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN rdt_EcomReturn_FinalizeOpt
      END
   END

Quit:


GO