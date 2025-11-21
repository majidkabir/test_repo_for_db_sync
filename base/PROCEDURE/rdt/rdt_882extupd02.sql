SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_882ExtUpd02                                     */  
/*                                                                      */  
/* Purpose: Delete rdt.RdtPreReceiveSort                                */  
/*                                                                      */  
/* Called from: rdtfnc_ModifyUCCData                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2021-10-29  1.0  James      WMS18221. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_882ExtUpd02] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),   
   @cPalletID      NVARCHAR( 20),   
   @cUCC           NVARCHAR( 20),   
   @cLOT           NVARCHAR( 10),   
   @cLOC           NVARCHAR( 10),   
   @cID            NVARCHAR( 18),   
   @cSKU           NVARCHAR( 20),   
   @nQty           INT,             
   @cStatus        NVARCHAR( 1),                   
   @tExtUpdateVar  VariableTable READONLY,    
   @nErrNo         INT           OUTPUT,     
   @cErrMsg        NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @curPRL   CURSOR  
   DECLARE @nRowref  INT  
  
   -- Handling transaction  
   DECLARE @nTranCount  INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_882ExtUpd02 -- For rollback or commit only our own transaction  
  
   IF @nStep = 3  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN        
         IF @nQty > 0  
         BEGIN  
            SET @curPRL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT Rowref  
            FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   UCCNo = @cUCC  
            AND   SKU = @cSKU  
            AND   [Status] = '1'  
            OPEN @curPRL   
            FETCH NEXT FROM @curPRL INTO @nRowref   
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               UPDATE rdt.rdtPreReceiveSort SET   
                  Qty = @nQty,   
                  EditWho = SUSER_SNAME(),   
                  EditDate = GETDATE()    
               WHERE Rowref = @nRowref  
              
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 178201  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Update Sort Err'  
                  GOTO RollBackTran    
               END  
                 
               FETCH NEXT FROM @curPRL INTO @nRowref  
            END  
         END  
         ELSE  
         BEGIN  
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)    
                        WHERE StorerKey = @cStorerKey    
                        AND   UCCNo = @cUCC)     
                        --GROUP BY UCCNo  
                        --HAVING COUNT( DISTINCT SKU) > 1)   
                        AND @nQty = 0  
            BEGIN  
               SET @curPRL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT Rowref  
               FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
               AND   UCCNo = @cUCC  
               AND   SKU = @cSKU  
               AND   [Status] = '1'  
               OPEN @curPRL   
               FETCH NEXT FROM @curPRL INTO @nRowref   
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                  DELETE FROM rdt.rdtPreReceiveSort    
 WHERE Rowref = @nRowref  
              
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 178202  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Delete Sort Err'  
                     GOTO RollBackTran    
                  END  
                 
                  FETCH NEXT FROM @curPRL INTO @nRowref  
               END  
  
               DELETE FROM dbo.UCC  
               WHERE StorerKey = @cStorerKey  
               AND   UCCNo = @cUCC  
               AND   SKU = @cSKU  
               AND  [Status] IN ('0','1')  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 178203  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Delete UCC Err'  
                  GOTO RollBackTran    
               END  
            END  
         END  
      END  
   END  
     
   COMMIT TRAN rdt_882ExtUpd02  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_882ExtUpd02 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO