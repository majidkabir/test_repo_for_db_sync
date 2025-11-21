SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_535ExtUpdSP01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: ANF Update UCC Logic                                        */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-04-16  1.0  ChewKP   Created                                    */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_535ExtUpdSP01] (    
   @nMobile    INT,             
   @nFunc      INT,             
   @cLangCode  NVARCHAR( 3),    
   @nStep      INT,             
   @cStorerKey NVARCHAR( 15),   
   @cFromUCC   NVARCHAR( 20),   
   @cToUCc     NVARCHAR( 20),   
   @cSKU       NVARCHAR( 20),   
   @cQty       NVARCHAR( 5),    
   @nErrNo     INT OUTPUT,   
   @cErrMsg    NVARCHAR( 20) OUTPUT  
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE  @cUCC NVARCHAR(20)   
          , @cDropLoc NVARCHAR(10)  
          , @cLoadKey NVARCHAR(10)  
          , @nQTY     INT  
          , @nTranCount INT  
  
   SET @nQty = @cQty   
   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
  
   SET @nTranCount = @@TRANCOUNT  
      
   BEGIN TRAN  
   SAVE TRAN UCCUpdate  
     
   IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cToUCC AND StorerKey = @cStorerKey )   
   BEGIN  
      INSERT INTO UCC ([UCCNo]  
           ,[Storerkey]  
           ,[ExternKey]  
           ,[SKU]  
           ,[qty]  
           ,[Sourcekey]  
           ,[Sourcetype]  
           ,[Userdefined01]  
           ,[Userdefined02]  
           ,[Userdefined03]  
           ,[Status]  
           ,[AddDate]  
           ,[AddWho]  
           ,[EditDate]  
           ,[EditWho]  
           ,[Lot]  
           ,[Loc]  
           ,[Id]  
           ,[Receiptkey]  
           ,[ReceiptLineNumber]  
           ,[Orderkey]  
           ,[OrderLineNumber]  
           ,[WaveKey]  
           ,[PickDetailKey]  
           ,[Userdefined04]  
           ,[Userdefined05]  
           ,[Userdefined06]  
           ,[Userdefined07]  
           ,[Userdefined08]  
           ,[Userdefined09]  
           ,[Userdefined10] )   
      SELECT [UCCNo]  
           ,[Storerkey]  
           ,[ExternKey]  
           ,[SKU]  
           ,@nQty  
           ,[Sourcekey]  
           ,[Sourcetype]  
           ,[Userdefined01]  
           ,[Userdefined02]  
           ,[Userdefined03]  
           ,[Status]  
           ,[AddDate]  
           ,[AddWho]  
           ,[EditDate]  
           ,[EditWho]  
           ,[Lot]  
           ,[Loc]  
           ,[Id]  
           ,[Receiptkey]  
           ,[ReceiptLineNumber]  
           ,[Orderkey]  
           ,[OrderLineNumber]  
           ,[WaveKey]  
           ,[PickDetailKey]  
           ,[Userdefined04]  
           ,[Userdefined05]  
           ,[Userdefined06]  
           ,[Userdefined07]  
           ,[Userdefined08]  
           ,[Userdefined09]  
           ,[Userdefined10]  
      FROM dbo.UCC WITH (NOLOCK)   
      WHERE UCCNo = @cFromUCC   
      AND StorerKey = @cStorerKey  
      AND SKU = @cSKU  
        
      IF @@ERROR <> 0   
      BEGIN  
          SET @nErrNo = 87301  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'InsUCCFail'  
          GOTO RollBackTran  
      END  
   END  
   ELSE  
   BEGIN  
      UPDATE dbo.UCC WITH (ROWLOCK)  
      SET Qty = Qty + @nQty   
      WHERE UCCNo = @cToUCC  
      AND SKU = @cSKU  
      AND StorerKey = @cStorerKey  
        
      IF @@ERROR <> 0   
      BEGIN  
          SET @nErrNo = 87302  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdUCCFail'  
          GOTO RollBackTran  
      END  
   END  
     
   UPDATE dbo.UCC WITH (ROWLOCK)  
   SET Qty = Qty - @nQty   
   WHERE UCCNo = @cFromUCC  
   AND SKU = @cSKU  
   AND StorerKey = @cStorerKey  
     
   IF @@ERROR <> 0   
   BEGIN  
       SET @nErrNo = 87303  
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'UpdUCCFail'  
       GOTO RollBackTran  
   END  
     
   GOTO QUIT  
      
  
   RollBackTran:  
   ROLLBACK TRAN UCCUpdate  
      
   Quit:  
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
          COMMIT TRAN UCCUpdate  
Fail:    
END    

GO