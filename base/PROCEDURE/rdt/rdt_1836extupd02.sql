SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/ 
/* Store procedure: rdt_1836ExtUpd02                                    */  
/* Purpose: update task status 0->3                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2020-07-29   YeeKung   1.0   WMS-14059 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1836ExtUpd02]  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cTaskdetailKey  NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10),  
   @nErrNo          INT             OUTPUT,  
   @cErrMsg         NVARCHAR( 20)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount        INT  
   DECLARE @cTaskKey          NVARCHAR( 10)  
   DECLARE @cTaskType         NVARCHAR( 10)  
   DECLARE @cCaseID           NVARCHAR( 20)  
   DECLARE @cStorerKey        NVARCHAR( 15)  
   DECLARE @cPickDetailKey    NVARCHAR( 15)  
   DECLARE @cWaveKey          NVARCHAR( 10)  
   DECLARE @cFacility         NVARCHAR( 5)  
   DECLARE @cOrderKey         NVARCHAR( 10)  
   DECLARE @cLot              NVARCHAR( 10)  
   DECLARE @cLoc              NVARCHAR( 10)  
   DECLARE @cId               NVARCHAR( 10)  
   DECLARE @curTask           CURSOR  
   DECLARE @curPD             CURSOR 
   DECLARE @nQTY              INT 
   DECLARE @cToLoc            NVARCHAR( 20)
   DECLARE @cUserID           NVARCHAR( 20)
   DECLARE @cFromLoc          NVARCHAR( 20)
   DECLARE @cFromID           NVARCHAR( 20)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cAreaKey          NVARCHAR( 20)
     
   SET @nTranCount = @@TRANCOUNT  
  
   SELECT @cUserID  = username,
          @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  

   SELECT 
          @cFromLoc = fromloc,  
          @cFromID  = fromid,     
          @cSKU     = sku,    
          @nQTY     = Qty,
          @cToLoc   = toloc,
          @cstorerkey=storerkey
   FROM Taskdetail (Nolock)
   WHERE taskdetailkey=@ctaskdetailkey
  
   -- TM Replen From  
   IF @nFunc = 1836  
   BEGIN   

      IF @nStep = 0 -- Final Loc  
      BEGIN
         
         IF(@nInputKey='1')
         BEGIN
            BEGIN TRAN  
            SAVE TRAN rdt_1836ExtUpd02
         
            UPDATE taskdetail with (rowlock)
            set status='3',
               userkey =@cUserID,
               EditWho = SUSER_SNAME(),   
               EditDate = GETDATE(),  
               Trafficcop = NULL  
            where taskdetailkey=@ctaskdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 156001  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  
               GOTO RollBackTran  
            END

            EXEC rdt.rdt_Putaway_PendingMoveIn  
            @cUserName        = @cUserID,   
            @cType            = 'LOCK'    
            ,@cFromLoc        = @cFromLoc    
            ,@cFromID         = @cFromID    
            ,@cSuggestedLOC   = @cToLoc    
            ,@cStorerKey      = @cStorerKey    
            ,@nErrNo          = @nErrNo    OUTPUT    
            ,@cErrMsg         = @cErrMsg OUTPUT    
            ,@cSKU            = @cSKU    
            ,@nPutawayQTY     = @nQTY    
            ,@nFunc           = 1836 

            IF @nErrNo <>0
            BEGIN
               --SET @nErrNo = 156002  
               --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  
               GOTO RollBackTran  
            END

            GOTO QUIT
         END
      END

      IF @nStep = 1
      BEGIN
         IF @nInputkey=1
         BEGIN
         
            BEGIN TRAN  
            SAVE TRAN rdt_1836ExtUpd02

            DECLARE @c_taskdetailkey NVARCHAR(20),
                    @b_success       int,
                    @n_err           int, 
                    @c_errmsg        NVARCHAR(20)

            EXECUTE nspg_getkey      
            "TaskDetailKey"      
            , 10      
            , @c_taskdetailkey OUTPUT      
            , @b_success OUTPUT      
            , @n_err  OUTPUT      
            , @c_errmsg OUTPUT      
                   
            IF @b_success <> 1      
         BEGIN      
            SET @nErrNo = 156004  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetTDKeyFail  
            GOTO RollBackTran     
         END    

         SELECT TOP 1 @cAreakey=areakey
         from loc (NOLOCK) join areadetail a (nolock) 
         on loc.putawayzone=a.putawayzone
         where loc=@cFinalLOC
      
            INSERT TASKDETAIL      
          (      
            TaskDetailKey ,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc     
           ,FromID,ToLoc,LogicalToLoc,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority     
           ,Holdkey,UserKey,UserPosition,UserKeyOverRide,StartTime,EndTime            
           ,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber    
           ,ListKey,WaveKey,ReasonKey ,Message01,Message02  ,Message03          
           ,SystemQty,RefTaskKey,LoadKey ,AreaKey,DropID ,TransitCount ,TransitLOC         
            ,FinalLOC ,FinalID ,Groupkey ,QtyReplen ,PendingMoveIn            
          )      
         SELECT   
          @c_taskdetailkey ,'RPT',Storerkey,Sku,Lot,UOM,UOMQty,Qty,ToLoc,LogicalFromLoc     
           ,fromid,FinalLoc,LogicalToLoc,toid,Caseid,PickMethod,0,StatusMsg,Priority,SourcePriority     
           ,'','','1','',getdate(),getdate()           
           ,'ispRLREP05',@cTaskdetailKey,'',OrderKey,OrderLineNumber    
           ,listkey,WaveKey,ReasonKey ,Message01,Message02  ,Message03          
           ,SystemQty,RefTaskKey,LoadKey ,@cAreakey,DropID ,'2' ,TransitLOC         
            ,FinalLOC ,FinalID ,Groupkey ,QtyReplen ,PendingMoveIn        
         FROM TASKDETAIL (NOLOCK)  
         WHERE TASKDetailKEY=@cTaskDetailKey 
         
            IF @@ERROR <>0
            BEGIN
               SET @nErrNo = 156005 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTDFail  
               GOTO RollBackTran  
            END 
         END
         IF @nInputkey=0
         BEGIN
            BEGIN TRAN  
            SAVE TRAN rdt_1836ExtUpd02

            UPDATE taskdetail with (rowlock)
            set   status='0',
                  userkey ='',
                  EditWho = SUSER_SNAME(),   
                  EditDate = GETDATE(),  
                  Trafficcop = NULL  
            where taskdetailkey=@ctaskdetailkey

            IF @@ERROR <>0
            BEGIN
               SET @nErrNo = 156003  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  
               GOTO RollBackTran  
            END

            EXEC rdt.rdt_Putaway_PendingMoveIn  
            @cUserName        = @cUserID,   
            @cType            = 'UNLOCK'    
            ,@cFromLoc        = @cFromLoc    
            ,@cFromID         = @cFromID    
            ,@cSuggestedLOC   = @ctoloc    
            ,@cStorerKey      = @cStorerKey    
            ,@nErrNo          = @nErrNo    OUTPUT    
            ,@cErrMsg         = @cErrMsg OUTPUT    
            ,@cSKU            = @cSKU    
            ,@nPutawayQTY     = @nQTY    
            ,@nFunc           = 1836 

            IF @nErrNo <>0
            BEGIN
               --SET @nErrNo = 156002  
               --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  
               GOTO RollBackTran  
            END
         END

         GOTO QUIT
      END
        
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1836ExtUpd02 -- Only rollback change made here  
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO