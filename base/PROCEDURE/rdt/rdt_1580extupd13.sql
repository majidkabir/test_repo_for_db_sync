SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd13                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Finalize by ID                                                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 20-05-2022  1.0  yeekung     WMS-19640 Created                             */
/******************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1580ExtUpd13]
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
   DECLARE @b_Success INT
   DECLARE @cReceiptLineNumber NVARCHAR(20)
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN 
   SAVE TRAN rdt_1580ExtUpd13

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nStep = 10 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cToID <> ''
            BEGIN

               IF EXISTS (SELECT 1 FROM DROPID (NOLOCK)
                           WHERE STATUS = 0
                           and dropid=@ctoID)
               BEGIN
                  UPDATE DROPID WITH (ROWLOCK)
                  SET status=9
                  WHERE STATUS = 0
                     and dropid=@ctoID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrno=186752 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollbackTran
                  END   
               END
               ELSE 
               BEGIN 
                  INSERT INTO DROPID( dropid,droploc,status)
                  VALUES(@cToID,@cToLOC,'9')

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrno=186751 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollbackTran
                  END
               END

               IF @cToLOC='RBSTG'
               BEGIN
                  -- Insert transmitlog2 here
                  EXEC ispGenTransmitLog2 
                     @c_TableName      = 'WOLRCPCFMGK', 
                     @c_Key1           = @cReceiptkey,
                     @c_Key2           = @cToID, 
                     @c_Key3           = @cStorerkey, 
                     @c_TransmitBatch  = '', 
                     @b_Success        = @b_Success   OUTPUT,
                     @n_err            = @nErrNo      OUTPUT,
                     @c_errmsg         = @cErrMsg     OUTPUT    
      
                  IF @b_Success <> 1 
                     GOTO RollBackTran
               END
 
               -- Loop ReceiptDetail of pallet
               DECLARE @curRD CURSOR
               SET @curRD = CURSOR FOR 
                 
                  SELECT RD.ReceiptLineNumber--, RD.ToLOC, RD.SKU
                  FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                  INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey 
                  WHERE RD.ToID = @cToID 
                     AND RD.FinalizeFlag <> 'Y'
                     AND RD.BeforeReceivedQty > 0 
                     AND R.StorerKey = @cStorerKey
                     AND R.ReceiptKey = @cReceiptKey 
                  ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
               OPEN @curRD
               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
               WHILE @@FETCH_STATUS = 0
               BEGIN
                 
                  EXEC dbo.ispFinalizeReceipt    
                  @c_ReceiptKey        = @cReceiptKey    
                  ,@b_Success           = @b_Success  OUTPUT    
                  ,@n_err               = @nErrNo     OUTPUT    
                  ,@c_ErrMsg            = @cErrMsg    OUTPUT    
                  ,@c_ReceiptLineNumber = @cReceiptLineNumber    
            
                  IF @nErrNo <> 0
                  BEGIN
                     -- SET @nErrNo = 109401
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                     GOTO RollBackTran
                  END


                  FETCH NEXT FROM @curRD INTO  @cReceiptLineNumber
               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd13 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO