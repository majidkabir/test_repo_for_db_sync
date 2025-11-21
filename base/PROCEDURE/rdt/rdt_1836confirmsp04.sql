SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/****************************************************************************/  
/* Store procedure: rdt_1836ConfirmSP04                                        */  
/* Copyright      : Maersk                                                  */    
/* Client         : Levis USA                                               */    
/* Purpose        : update location                                         */
/*                  once location override happened and confirm             */  
/*                                                                          */  
/* Modifications log:                                                       */  
/*                                                                          */  
/* Date         Author    Ver.    Purposes                                  */  
/* 2024-12-04   YYS027    1.0.0   FCR-1489 Created,Configkey=ConfirmSP      */  
/****************************************************************************/  

CREATE   PROCEDURE [RDT].[rdt_1836ConfirmSP04]  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
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

   DECLARE @cFromID           NVARCHAR(18)
   DECLARE @nTranCount        INT
   DECLARE @cTaskKey          NVARCHAR( 10)
   DECLARE @cTaskType         NVARCHAR( 10)
   DECLARE @cCaseID           NVARCHAR( 20)
   --DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cPickDetailKey    NVARCHAR( 15)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cTDWaveKey        NVARCHAR( 10)
   --DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cLoc              NVARCHAR( 10)
   DECLARE @cId               NVARCHAR( 10)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @nQty              INT
   DECLARE @nPDQty            INT
   DECLARE @nBalQty           INT
   DECLARE @curTask           CURSOR
   DECLARE @curPD             CURSOR
   DECLARE @curCPK            CURSOR
   DECLARE @cAreakey          NVARCHAR(20)
   DECLARE @cFromLOC          NVARCHAR( 10)
   DECLARE @cSuggToLOC        NVARCHAR( 10)
   DECLARE @cSuggFinalLoc     NVARCHAR( 10)
   DECLARE @cRefTaskKey       NVARCHAR( 10)
   DECLARE @cUCCNo            NVARCHAR( 20)
   DECLARE @cpTaskdetailKey   NVARCHAR( 10)
   DECLARE @cpCaseID          NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT

   IF @nFUNC = 1836
   BEGIN
      IF @nStep = 1
      BEGIN
         IF (@nInputKey = 1)
         BEGIN
            -- Get task info
            SELECT
               @cTaskType     = TaskType,
               @cStorerKey    = Storerkey,
               @cWaveKey      = WaveKey,
               @cAreakey      = Areakey,
               @cCaseID       = CaseID,    
               @cFromLOC      = FromLOC,    
               @cSuggToLOC    = ToLOC,
               @cSuggFinalLoc = finalloc,
               @cSKU          = Sku,
               @cLot          = Lot,
               @nQty          = Qty,   
               @cRefTaskKey   = RefTaskKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskdetailKey = @cTaskdetailKey

            SET @cUCCNo = NULL
            IF EXISTS(SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cCaseID AND StorerKey = @cStorerKey)
               SELECT @cUCCNo = @cCaseID

            IF @nTranCount<=0
               BEGIN TRAN
            SAVE TRAN rdt_1836ConfirmSP04

            IF @cFinalLOC <> @cSuggToLOC           --location is overridden
            BEGIN
               --Object 2 : reduce PendingMoveIN of LotxLocxID
               --UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET PendingMoveIN=CASE WHEN PendingMoveIN >=@nQty THEN  PendingMoveIN - @nQty ELSE 0 END
               --   WHERE Lot=@cLot AND	Loc=@cSuggToLOC AND	Id=@cCaseID AND StorerKey=@cStorerKey AND	Sku=cSKU
               -- Unlock by ASTRPT task
               SELECT @cUCCNo=ISNULL(@cUCCNo,'')
               SELECT @cpTaskDetailKey = CASE WHEN ISNULL(@cUCCNo,'')<>'' THEN '' ELSE @cTaskdetailKey END
               EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
                  ,'' --FromLOC  
                  ,'' --FromID  
                  ,'' --SuggLOC  
                  ,@cStorerKey --Storer  
                  ,@nErrNo  OUTPUT  
                  ,@cErrMsg OUTPUT  
                  ,@cUCCNo           = @cUCCNo
                  ,@cTaskDetailKey   = @cpTaskDetailKey
               --unlock can be success and the record will be zero and record of RFputaway will be removed also
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 230052   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Fail UNLOCK
                  GOTO RollbackTran
               END
               --to void issue of FK 
               INSERT INTO dbo.LotxLocxID(Lot,Loc,Id,StorerKey,Sku,Qty,PendingMoveIN)
                  SELECT td.lot,@cFinalLOC,td.FromID,td.StorerKey,td.Sku,0,0
                  FROM
                     dbo.TaskDetail td WITH (NOLOCK) 
                     LEFT JOIN dbo.LotxLocxID inv WITH (NOLOCK) ON inv.Lot=td.Lot AND inv.ID=td.FromID AND  inv.Loc=@cFinalLOC
                  WHERE td.StorerKey=@cStorerKey AND td.RefTaskKey=@cRefTaskKey AND td.TaskType='ASTCPK' AND inv.Loc IS NULL

               INSERT INTO dbo.LotxLocxID(Lot,Loc,Id,StorerKey,Sku,Qty,PendingMoveIN)
                  SELECT pd.lot,@cFinalLOC,pd.ID,td.StorerKey,pd.Sku,0,0
                  FROM
                     dbo.pickdetail pd WITH (NOLOCK)
                     INNER JOIN dbo.TaskDetail td WITH (NOLOCK) ON pd.PickDetailKey=td.PickDetailKey
                     LEFT JOIN dbo.LotxLocxID inv WITH (NOLOCK) ON inv.Lot=pd.Lot AND inv.ID=pd.ID AND  inv.Loc=@cFinalLOC
                  WHERE td.StorerKey=@cStorerKey AND td.RefTaskKey=@cRefTaskKey AND td.TaskType='ASTCPK' AND inv.Loc IS NULL


               --Object 2: Update the pickdetail.Loc with the new ÃŸoverridden location where Taskdetail.PickDetailKey for ASTCPK task will hold Pickdetail.PickDetailKey.
               UPDATE dbo.pickdetail WITH (ROWLOCK) SET Loc=@cFinalLOC 
                  FROM dbo.pickdetail pd WITH (ROWLOCK) INNER JOIN dbo.TaskDetail td WITH (ROWLOCK) on pd.PickDetailKey=td.PickDetailKey
                  WHERE td.StorerKey=@cStorerKey AND td.RefTaskKey=@cRefTaskKey AND td.TaskType='ASTCPK'
                  
               --object 2: Update the Taskdetail.FromLoc for the ASTCPK task and TaskDetail.ToLoc for the ASTRPT task.
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET FromLoc = @cFinalLOC, LogicalFromLoc =@cFinalLOC  WHERE StorerKey=@cStorerKey AND  RefTaskKey=@cRefTaskKey AND TaskType = 'ASTCPK'

--due confirmation will be called immediately ('Create a record for (scanned loc)  in lotxloxlocid' is also removed in technical solution section of confluence), 
--      so lock-operation can be ignored. 
----use this block to update  LotxLocxID.PendingMoveIn            
               --Change location, and No PendingMoveIn will be changed in to LotxLocxID via trigger
               --UPDATE dbo.TaskDetail WITH (ROWLOCK) SET ToLoc = @cFinalLOC,PendingMoveIn=0 WHERE TaskdetailKey = @cTaskdetailKey
               --Change PendingMoveIn, and PendingMoveIn will be updated into LotxLocxID via trigger
               --UPDATE dbo.TaskDetail WITH (ROWLOCK) SET PendingMoveIn=@nQty WHERE TaskdetailKey = @cTaskdetailKey
               -- for update dbo.TaskDetail, database will updated the LotxLocxID.PendingMoveIn, but the pre-condition is to exist the record in LotxLocxID
----or use following block to update  LotxLocxID.PendingMoveIn 
               --Change location, and No PendingMoveIn will be changed in to LotxLocxID via trigger
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET ToLoc = @cFinalLOC, LogicalToLoc = @cFinalLOC WHERE TaskdetailKey = @cTaskdetailKey
               --Object 2 : Create a record for (scanned loc)  in lotxloxlocid.
               --EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               --   ,@cFromLOC      = @cFromLOC  
               --   ,@FromID        = @cCaseID
               --   ,@cSuggestedLOC = @cFinalLOC
               --   ,@cStorerKey    = @cStorerKey
               --   ,@nErrNo        = @nErrNo OUTPUT  
               --   ,@cErrMsg       = @cErrMsg OUTPUT 
               --   ,@cSKU          = @cSKU
               --   ,@nPutawayQTY   = @nQty 
               --   --,@cUCCNo        = @cCaseID
               --   ,@cFromLOT      = @cLot
               --   ,@cTaskDetailKey   = @cTaskdetailKey
               --   ,@cMoveQTYAlloc = '1'
               ----for rdt_Putaway_PendingMoveIn can be success to update, the pre-condition is to exist the record in LotxLocxID, so insert a record is required.
               --IF @nErrNo <> 0
               --BEGIN
               --   SET @nErrNo = 230053   
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Fail LOCK
               --   GOTO RollbackTran
               --END
----end of block
            END

   /***********************************************************************************************
                    Standard confirm: come from rdt_TM_Assist_ReplenTo_Confirm
   ***********************************************************************************************/            
            --DECLARE @cFromLOC NVARCHAR(10)  
            --DECLARE @cFromID  NVARCHAR(18)  
            --DECLARE @cCaseID  NVARCHAR(20)  

            -- Get task info
            SELECT 
               @cFromLOC = FromLOC, 
               @cFromID = FromID, 
               @cCaseID = CaseID
            FROM TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey
            
            -- Handling transaction
            --BEGIN TRAN  -- Begin our own transaction
            --SAVE TRAN rdt_TM_Assist_ReplenTo_Confirm -- For rollback or commit only our own transaction
            SELECT @cUCCNo=NULL where ISNULL(@cUCCNo,'')=''
            SELECT @cpCaseID = CASE WHEN ISNULL(@cUCCNo,'')<>'' THEN '' ELSE @cCaseID END
            -- Move by UCC
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT,
               @cSourceType = 'rdt_TM_Assist_ReplenTo_Confirm', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cFromLOC, 
               @cFromID     = @cFromID,  
               @cToLOC      = @cFinalLoc, 
               @cUCC        = @cUCCNo, 
               @cCaseID     = @cpCaseID,            --for ucc case, pass parameter will be same with standard.
               @cToID       = NULL,  -- NULL means not changing ID
               @nFunc       = @nFunc 
            IF @nErrNo <> 0
               GOTO RollbackTran

            SELECT @cUCCNo=ISNULL(@cUCCNo,'')
            SELECT @cpTaskDetailKey = CASE WHEN ISNULL(@cUCCNo,'')<>'' THEN '' ELSE @cTaskdetailKey END
            -- Unlock by ASTRPT task  
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,@cStorerKey --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cUCCNo           = @cUCCNo
               ,@cTaskDetailKey   = @cpTaskDetailKey
            IF @nErrNo <> 0
               GOTO RollbackTran
            
            -- Update task
            UPDATE dbo.TaskDetail SET
               Status = '9',
               ToLOC = @cFinalLoc,
               UserKey = SUSER_SNAME(),
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(), 
               Trafficcop = NULL
            WHERE TaskDetailKey = @cTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 143001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
               GOTO RollbackTran
            END

            COMMIT TRAN rdt_1836ConfirmSP04 -- Only commit change made here
         END
      END
   END
  
   GOTO Quit
RollBackTran:
   ROLLBACK TRAN rdt_1836ConfirmSP04 -- Only rollback change made here  
QUIT:
   WHILE(@@TRANCOUNT > @nTranCount)  -- Commit until the level we started
      COMMIT TRAN 
END  

GO