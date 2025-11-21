SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd12                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Finalize by ID                                                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 2020-12-02   1.0  YeeKung    WMS-15666 Created                             */
/******************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1580ExtUpd12]
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
   DECLARE @cReceiptLineNumber NVARCHAR(20),
           @bsuccess INT 
   SET @nTranCount = @@TRANCOUNT
   
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nStep = 10 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN

            BEGIN TRAN    
            SAVE TRAN rdt_1580ExtUpd12  

             -- Auto finalize upon receive
            DECLARE @cFinalizeRD NVARCHAR(1)
            SET @cFinalizeRD = rdt.RDTGetConfig( @nFunc, 'FinalizeReceiptDetails', @cStorerKey)
            IF @cFinalizeRD IN ('', '0')
               SET @cFinalizeRD = '1' -- Default = 1

            DECLARE @nbeforereceivedqty INT,@nQtyExpected INT

            SELECT @nBeforereceivedqty =SUM(beforereceivedqty)
                  ,@nQtyExpected=SUM(qtyexpected)
            FROM dbo.RECEIPTDETAIL (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND sku=@cSKU
            AND toid=@cToID
            AND storerkey=@cStorerKey

            IF (@nbeforereceivedqty=@nQtyExpected)
            BEGIN
               -- Finalize ASN by line if no more variance
               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ReceiptLineNumber 
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   FinalizeFlag <> 'Y'
               AND   BeforeReceivedQty=QtyExpected
               AND   sku=@cSKU

               OPEN CUR_UPD
               FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @cFinalizeRD = '1'
                  BEGIN
                     -- Bulk update (so that trigger fire only once, compare with row update that fire trigger each time)
                     UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
                     SET
                        QTYReceived = RD.BeforeReceivedQTY,
                        FinalizeFlag = 'Y', 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     FROM dbo.ReceiptDetail RD
                     WHERE ReceiptKey = @cReceiptKey
                        AND ReceiptLineNumber = @cReceiptLineNumber
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0
            BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollBackTran
                     END
                  END

                  IF @cFinalizeRD = '2'
                  BEGIN
                     EXEC dbo.ispFinalizeReceipt
                         @c_ReceiptKey        = @cReceiptKey
                        ,@b_Success           = @bSuccess   OUTPUT
                        ,@n_err               = @nErrNo     OUTPUT
                        ,@c_ErrMsg            = @cErrMsg    OUTPUT
                        ,@c_ReceiptLineNumber = @cReceiptLineNumber
                     IF @nErrNo <> 0 OR @bSuccess = 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollBackTran
                     END
                  END

                  FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber
               END
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD    
   
               IF rdt.RDTGetConfig( @nFunc, 'CloseASNUponFinalize', @cStorerKey) = '1'
                  AND @cFinalizeRD > 0
                  AND NOT EXISTS ( SELECT 1 
                                   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                                   WHERE ReceiptKey = @cReceiptKey
                                   AND   FinalizeFlag = 'N')
               BEGIN
                  -- Close Status and ASNStatus here. If turn on config at WMS side then all ASN will be affected,
                  -- no matter doctype. This only need for ecom ASN only. So use rdt config to control
                  UPDATE dbo.RECEIPT SET  
                     ASNStatus = '9',    
                     -- Status    = '9',  -- Should not overule Exceed trigger logic
                     ReceiptDate = GETDATE(),
                     FinalizeDate = GETDATE(),
                     EditDate = GETDATE(),    
                     EditWho = SUSER_SNAME()     
                  WHERE ReceiptKey = @cReceiptKey    
                  SET @nErrNo = @@ERROR
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END   
               END
            END 
               
            COMMIT TRAN rdt_1580ExtUpd12
            GOTO Quit
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd12 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO