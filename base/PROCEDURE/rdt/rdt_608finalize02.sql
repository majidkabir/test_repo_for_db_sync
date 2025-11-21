SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_608Finalize02                                         */  
/* Copyright      : MAERSK                                                    */  
/*                                                                            */
/* Purpose        : QtyExpected = BeforeReceivedQty before able to finalize   */  
/*                                                                            */
/* Date       Rev  Author  Purposes                                           */  
/* 2023-10-23 1.0  James   WMS-23653 Created base on rdt_ECOMReturn_Finalize  */  
/******************************************************************************/  
CREATE   PROC [RDT].[rdt_608Finalize02](  
   @nFunc         INT,  
   @nMobile       INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cReceiptKey   NVARCHAR( 10),  
   @cRefNo        NVARCHAR( 20),  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount  INT  
  
   IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey 
               GROUP BY ReceiptKey
               HAVING ISNULL( SUM( QtyExpected), 0) <> ISNULL( SUM( BeforeReceivedQty), 0) ) 
   BEGIN
      SET @nErrNo = 207501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotAllQtyRcv'
      GOTO Fail
   END
   
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_608Finalize02 -- For rollback or commit only our own transaction  
  
   DECLARE @bSuccess INT  
   EXEC ispFinalizeReceipt  
      @c_ReceiptKey = @cReceiptKey,   
      @b_Success    = @bSuccess OUTPUT,   
      @n_err        = @nErrNo   OUTPUT,   
      @c_ErrMsg     = @cErrMsg  OUTPUT  
   IF @bSuccess = 0 OR @nErrNo <> 0  
   BEGIN  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
      GOTO RollBackTran  
   END  
     
   COMMIT TRAN rdt_608Finalize02  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN -- rdt_608Finalize02 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
Fail:
END  

GO