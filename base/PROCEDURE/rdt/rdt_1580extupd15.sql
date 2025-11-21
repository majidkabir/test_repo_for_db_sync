SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd15                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Update ReceiptDetail.UserDefine01 as serial no                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 13-04-2023 1.0  yeekung      WMS-22166 Created                              */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580ExtUpd15]
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
   DECLARE @cRD_LOC NVARCHAR( 10) 
   DECLARE @cRD_SKU NVARCHAR( 20)
   DECLARE @cReceiptLineNumber NVARCHAR(5)
          ,@cOrderKey          NVARCHAR(10) 
          ,@bSuccess           INT
       
   

   SET @nTranCount = @@TRANCOUNT

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1580ExtUpd15 -- For rollback or commit only our own transaction
   
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
       

      IF @nStep = 10 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
              
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
                 ,@b_Success           = @bSuccess  OUTPUT    
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
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd15 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1580ExtUpd15

END

GO