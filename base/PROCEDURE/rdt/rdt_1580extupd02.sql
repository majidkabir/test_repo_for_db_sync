SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd02                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Update ReceiptDetail.UserDefine01 as serial no                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 17-05-2017  1.0  Ung         WMS-1817 Created                              */
/* 28-11-2017  1.1  Ung         WMS-3173 Check Receipt.UDF vs SerialNo.UDF    */
/* 20-12-2017  1.2  Ung         WMS-3508 Add hold serial no                   */
/* 18-07-2018  1.3  Ung         WMS-5723 Copy L01 (tracking no) to UDF04      */
/* 27-06-2019  1.4  Ung         Performance tuning                            */
/* 11-11-2019  1.5  Ung         Performance tuning (deadlock)                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtUpd02]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount INT
   DECLARE @cDocType    NVARCHAR( 1)
   DECLARE @cReceiptUDF NVARCHAR( 40)
   DECLARE @cReturnFrom NVARCHAR( 30)

   SET @nTranCount = @@TRANCOUNT

   -- Get ASN info
   SELECT 
      @cDocType = DocType, 
      @cReceiptUDF = ISNULL( UserDefine01, '') + ISNULL( UserDefine02, ''), 
      @cReturnFrom = ISNULL( UserDefine03, '')
   FROM Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey         
   
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      /* Checking in below is known will cause performance issue, and can be remove after some years. 
      IF @nStep = 1 -- ASN, POS
      BEGIN
         IF @cDocType = 'R' AND  -- Return
            @cReturnFrom = ''    -- Return from DYSON or non DYSON order. Blank = not yet determine
         BEGIN
            -- Check serial no sent out by us or others
            IF EXISTS( SELECT 1 
               FROM SerialNo WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND ISNULL( UserDefine01, '') + ISNULL( UserDefine02, '') = @cReceiptUDF)

               SET @cReturnFrom = @cStorerKey
            ELSE
               SET @cReturnFrom = 'NON ' + @cStorerKey
               
            -- Update return from 
            UPDATE Receipt SET
               UserDefine03 = @cReturnFrom, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE ReceiptKey = @cReceiptKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 109403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD RCPT Fail
               GOTO RollBackTran
            END
         END
      END
      */

      IF @nStep = 10 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get hold LOC
            DECLARE @cHoldLOC NVARCHAR( 10)
            SET @cHoldLOC = rdt.RDTGetConfig( @nFunc, 'HoldLOC', @cStorerKey)         
            
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_1580ExtUpd02 -- For rollback or commit only our own transaction

            -- Finalize pallet
            IF EXISTS( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey 
                  AND ToID = @cToID 
                  AND FinalizeFlag <> 'Y'
                  AND QTYReceived <> BeforeReceivedQTY)
            BEGIN
               DECLARE @cRD_LOC NVARCHAR( 10) 
               DECLARE @cRD_SKU NVARCHAR( 20)
               
               -- Loop ReceiptDetail of pallet
               DECLARE @cReceiptLineNumber NVARCHAR(5)
               DECLARE @curRD CURSOR
               SET @curRD = CURSOR FOR 
                  SELECT ReceiptLineNumber, ToLOC, SKU
                  FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     AND ToID = @cToID
                  ORDER BY SKU
               OPEN @curRD
               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cRD_LOC, @cRD_SKU
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Finalize ReceiptDetail
                  IF @cDocType = 'R'
                     UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                        FinalizeFlag = 'Y',
                        QTYReceived = BeforeReceivedQTY, 
                        UserDefine04 = Lottable01, 
                        Lottable01 = '', 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME() 
                     WHERE ReceiptKey = @cReceiptKey
                        AND ReceiptLineNumber = @cReceiptLineNumber
                  ELSE
                     UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                        FinalizeFlag = 'Y',
                        QTYReceived = BeforeReceivedQTY, 
                        Lottable01 = '', 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME() 
                     WHERE ReceiptKey = @cReceiptKey
                        AND ReceiptLineNumber = @cReceiptLineNumber

                  SET @nErrNo = @@ERROR
                  IF @nErrNo <> 0
                  BEGIN
                     -- SET @nErrNo = 109401
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                     GOTO RollBackTran
                  END

                  -- Hold LOC
                  IF @cRD_LOC = @cHoldLOC
                  BEGIN
                     -- Serial no
                     IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cRD_SKU AND SerialNoCapture = '1')
                     BEGIN
                        DECLARE @cSerialNo NVARCHAR( 30)
                        DECLARE @curSNO CURSOR
                        SET @curSNO = CURSOR FOR 
                           SELECT SerialNo
                           FROM dbo.ReceiptSerialNo WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                              AND ReceiptLineNumber = @cReceiptLineNumber
                        OPEN @curSNO
                        FETCH NEXT FROM @curSNO INTO @cSerialNo
                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                           DECLARE @cSerialNoKey NVARCHAR( 10)
                           DECLARE @cSNOStatus NVARCHAR( 10)
                           
                           -- Get SerialNo info
                           SET @cSerialNoKey = ''
                           SELECT 
                              @cSerialNoKey = SerialNoKey, 
                              @cSNOStatus = Status
                           FROM SerialNo WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey 
                              AND SKU = @cRD_SKU 
                              AND SerialNo = @cSerialNo
                           
                           -- Update SerialNo
                           IF @cSerialNoKey <> '' AND @cSNOStatus <> 'H'
                           BEGIN
                              UPDATE SerialNo SET
                                 Status = 'H', 
                                 EditDate = GETDATE(), 
                                 EditWho = SUSER_SNAME(), 
                                 TrafficCop = NULL
                              WHERE SerialNoKey = @cSerialNoKey
                              IF @@ERROR <> 0
                              BEGIN
                                 SET @nErrNo = 109404
                                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD SNO Fail
                                 GOTO RollBackTran
                              END
                           END
                           
                           FETCH NEXT FROM @curSNO INTO @cSerialNo
                        END
                     END
                  END
                  
                  FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cRD_LOC, @cRD_SKU
               END
            END
            ELSE 
            BEGIN
               SET @nErrNo = 109402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No RD Finalize
               GOTO RollBackTran
            END
            
            COMMIT TRAN rdt_1580ExtUpd02 -- Only commit change made here
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO