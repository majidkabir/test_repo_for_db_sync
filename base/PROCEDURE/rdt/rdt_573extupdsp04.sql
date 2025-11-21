SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtUpdSP04                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: When QtyExpected = Beforereceivedqty then finalize ASN      */
/*                                                                      */
/* Called from: rdtfnc_UCCInboundReceive                                */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-11-01  1.0  James    WMS-11006 Created                          */
/* 2022-01-24  1.1  Ung      WMS-18776 Add CartonType and VariableTable */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtUpdSP04] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR(3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR(15),
   @cFacility     NVARCHAR(5),
   @cReceiptKey1  NVARCHAR(20),
   @cReceiptKey2  NVARCHAR(20),
   @cReceiptKey3  NVARCHAR(20),
   @cReceiptKey4  NVARCHAR(20),
   @cReceiptKey5  NVARCHAR(20),
   @cLoc          NVARCHAR(20),
   @cID           NVARCHAR(18),
   @cUCC          NVARCHAR(20),
   @cCartonType   NVARCHAR(10),
   @tExtUpdate    VariableTable READONLY,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR(1024) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptLineNumber NVARCHAR( 5)
          ,@cReceiptKey        NVARCHAR( 10)
          ,@cFinalizeReceipt   NVARCHAR( 1)
          ,@nTranCount         INT
          ,@bSuccess           INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_573ExtUpdSP04   
   
          
   IF @nStep = 4  
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check variance
         IF NOT EXISTS( SELECT 1 
            FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
            WHERE RD.QTYExpected <> BeforeReceivedQTY
            AND   EXISTS ( SELECT 1 FROM rdt.rdtConReceiveLog CRL WITH (NOLOCK) 
                           WHERE CRL.ReceiptKey = RD.ReceiptKey
                           AND   CRL.Mobile = @nMobile))
         BEGIN
            SET @cFinalizeReceipt = rdt.RDTGetConfig( @nFunc, 'FinalizeReceipt', @cStorerKey)
            
            IF @cFinalizeReceipt NOT IN ( '', '0')
            BEGIN
               -- Finalize ASN by line if no more variance
               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ReceiptKey, ReceiptLineNumber 
               FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
               WHERE RD.QTYExpected = RD.BeforeReceivedQTY
               AND   RD.FinalizeFlag <> 'Y'
               AND   EXISTS ( SELECT 1 FROM rdt.rdtConReceiveLog CRL WITH (NOLOCK) 
                              WHERE CRL.ReceiptKey = RD.ReceiptKey
                              AND   CRL.Mobile = @nMobile)            
               OPEN CUR_UPD
               FETCH NEXT FROM CUR_UPD INTO @cReceiptKey, @cReceiptLineNumber
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @cFinalizeReceipt = '1'
                  BEGIN
                     UPDATE dbo.ReceiptDetail SET
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
                        CLOSE CUR_UPD
                        DEALLOCATE CUR_UPD
                        GOTO RollBackTran
                     END
                  END
                  ELSE IF @cFinalizeReceipt = '2' 
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
                        CLOSE CUR_UPD
                        DEALLOCATE CUR_UPD                        
                        GOTO RollBackTran
                     END
                  END
         
                  FETCH NEXT FROM CUR_UPD INTO @cReceiptKey, @cReceiptLineNumber
               END
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
            END
         END
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_573ExtUpdSP04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO