SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1836ConfirmSP03                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2020-03-24   James     1.0   WMS-15659 Created                             */
/* 2021-08-03   James     1.1   Fix full case pick error (james01)            */
/* 2022-02-23   YeeKung   1.2   WMS-18969 add wave.userdefine01(yeekung01)    */
/******************************************************************************/

CREATE    PROCEDURE [RDT].[rdt_1836ConfirmSP03]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLOC NVARCHAR( 10)
   DECLARE @cFromID  NVARCHAR( 18)
   DECLARE @cFromLot NVARCHAR( 10)
   DECLARE @cSKU     NVARCHAR( 20)
   DECLARE @cCaseID  NVARCHAR( 20)
   DECLARE @cDropID  NVARCHAR( 20)
   DECLARE @nQTY     INT
   DECLARE @nQtyAlloc      INT
   DECLARE @nQTYPick       INT
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYPick   NVARCHAR( 1)
   DECLARE @cNewTaskdetailKey NVARCHAR( 10)
   DECLARE @cWavekey       NVARCHAR( 10)
   DECLARE @cOrderkey      NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cMessage03     NVARCHAR( 20)
   DECLARE @cPriority      NVARCHAR( 10)
   DECLARE @cAreaKey       NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cUOM           NVARCHAR( 10)
   DECLARE @cSourceKey     NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10) = ''
   DECLARE @cLogicalFromLoc   NVARCHAR( 10)
   DECLARE @b_success      INT
   DECLARE @cToLoc         NVARCHAR( 10)
   DECLARE @cUserDefine02  NVARCHAR( 20)
   DECLARE @cOriTaskDetailKey NVARCHAR( 10)
   DECLARE @nToLocIsLoseID INT = 0
   DECLARE @nIsFromYogaMat INT = 0
   DECLARE @cWCSKey        NVARCHAR( 10) = ''
   DECLARE @nLLI_QtyAlloc  INT
   DECLARE @nLLI_QtyPick   INT
   DECLARE @cSourceType    NVARCHAR( 30)
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cSuggestedLoc  NVARCHAR( 10)
   DECLARE @cOrdType       NVARCHAR( 10)
   DECLARE @nIsUCC         INT = 0
   DECLARE @ccurPD         CURSOR
   DECLARE @nPickDtl_Qty   INT
   DECLARE @nChkQty        INT
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @nPD_QtyAlloc   INT
   DECLARE @ccurTD         CURSOR
   DECLARE @cListKey       NVARCHAR( 10)
   
   DECLARE @tLOT TABLE
   (
      Seq       INT IDENTITY(1,1) NOT NULL,
      Lot       NVARCHAR( 10) NOT NULL
   )
      
   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cDropID = ''
   SET @nQtyAlloc = 0
   SET @nQTYPick = 0

   -- Get task info
   SELECT 
      @cFromLOC = FromLOC, 
      @cFromID = FromID, 
      @cSKU = Sku,
      @cFromLot = Lot,
      @cCaseID = Caseid,
      @nQTY = Qty, 
      @cWavekey = WaveKey,
      @cSourceKey = SourceKey, 
      @cSourceType = SourceType,
      @cSuggestedLoc = ToLoc,
      @cListKey = ListKey
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @cSourceType LIKE '%805%'
      SET @cType = 'PTS'
   ELSE
      SET @cType = 'RPF'

   IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   UCCNo = @cCaseID
               AND   [Status] = '6')
      SET @nIsUCC = 1

   IF @cFromLot = ''
   BEGIN
      -- Retrieve lot from origin RPF task
      SELECT @cFromLot = Lot
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE TaskDetailKey = @cSourceKey
   END
   
   IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
               WHERE Facility = @cFacility
               AND   Loc = @cFinalLOC
               AND   LoseId = '1')
      SET @nToLocIsLoseID = 1

   IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
               WHERE TD.TaskDetailKey = @cSourceKey
               AND   TD.TaskType = 'RPF'
               AND   TD.[Status] = '9'
               AND   LOC.PutawayZone = 'LULUCP'
               AND   LOC.Facility = @cFacility)
      SET @nIsFromYogaMat = 1

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1836ConfirmSP03 -- For rollback or commit only our own transaction

   IF @nIsFromYogaMat = 1
      SET @cDropID = ''

   -- Move residual qty from PTS to dedicated loc
   IF @cType = 'PTS'
   BEGIN
      SET @cDropID = ''
      SET @nQTYPick = 0
   END

   IF @cType = 'RPF'
   BEGIN
      IF @nIsUCC = 1
      BEGIN
         IF @cMoveQTYAlloc = '1'
         BEGIN
            --SELECT @nLLI_QtyAlloc = ISNULL( SUM( QtyAllocated), 0)
            --FROM dbo.LOTxLOCxID WITH (NOLOCK)
            --WHERE Lot = @cFromLot 
            --AND   Loc = @cFromLOC
            --AND   Id = @cFromID

            SELECT @nPD_QtyAlloc = ISNULL( SUM( QTY), 0)  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND LOC = @cFromLOC  
            AND ID  = @cFromID   
            AND LOT = @cFromLOT  
            AND Status BETWEEN '0' AND '3'  
            AND QTY > 0  
            AND DropID = @cCaseID
            
            IF @nQty < @nPD_QtyAlloc
               SET @nQTYAlloc = @nQty
            ELSE
               SET @nQTYAlloc = @nPD_QtyAlloc

            SET @cDropID = @cCaseID
         END
         ELSE
            SET @nQTYAlloc = 0
            --IF SUSER_SNAME() = 'JAMESWONG'
            --SELECT @cFromLOC '@cFromLOC', @cFromID '@cFromID', @cSKU '@cSKU', @nQty '@nQty', @cFromLot '@cFromLot', @nQtyAlloc '@nQtyAlloc', @nQtyPick '@nQtyPick', @cDropID '@cDropID'

         -- Move by UCC
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT,
            @cSourceType = 'rdt_1836ConfirmSP03', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cFromLOC, 
            @cFromID     = @cFromID,  
            @cToLOC      = @cFinalLoc, 
            @cToID       = NULL,  -- NULL means not changing ID
            @cSKU        = @cSKU,
            @nQTY        = @nQty,
            @nFunc       = @nFunc, 
            @cFromLot    = @cFromLot,
            @nQTYAlloc   = @nQtyAlloc, 
            @nQTYPick    = @nQtyPick,
            @cDropID     = @cDropID
      
         IF @nErrNo <> 0
            GOTO RollbackTran

         IF NOT EXISTS ( SELECT 1 FROM @tLOT WHERE LOT = @cFromLot)
            INSERT INTO @tLOT (Lot) VALUES (@cFromLot)
      END
      ELSE
      BEGIN
         SET @ccurTD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SourceKey, Qty
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE ListKey = @cListKey
         AND   TaskType = 'ASTRPT'
         AND   Caseid = @cCaseID
         AND   [Status] = '0'
         AND   ToLoc = @cSuggestedLoc
         AND   Sku = @cSKU
         OPEN @ccurTD
         FETCH NEXT FROM @ccurTD INTO @cOriTaskDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @nChkQty = @nQTY
            SET @ccurPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Lot, SUM( Qty)
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE TaskDetailKey = @cOriTaskDetailKey
            GROUP BY Lot
            OPEN @ccurPD
            FETCH NEXT FROM @ccurPD INTO @cFromLot, @nPickDtl_Qty
            WHILE @@FETCH_STATUS = 0
            BEGIN   
               IF @cMoveQTYAlloc = '1'
               BEGIN
                  SELECT @nLLI_QtyAlloc = ISNULL( SUM( QtyAllocated), 0)
                  FROM dbo.LOTxLOCxID WITH (NOLOCK)
                  WHERE Lot = @cFromLot 
                  AND   Loc = @cFromLOC
                  AND   Id = @cFromID

                  IF @nPickDtl_Qty < @nLLI_QtyAlloc
                     SET @nQTYAlloc = @nPickDtl_Qty
                  ELSE
                     SET @nQTYAlloc = @nLLI_QtyAlloc

                  SET @cDropID = @cCaseID
               END
               ELSE
                  SET @nQTYAlloc = 0
               --IF SUSER_SNAME() = 'JAMESWONG'
               --SELECT @cFromLOC '@cFromLOC', @cFromID '@cFromID', @cSKU '@cSKU', @nPickDtl_Qty '@nPickDtl_Qty', @cFromLot '@cFromLot', @nQtyAlloc '@nQtyAlloc', @nQtyPick '@nQtyPick', @cDropID '@cDropID'
               -- Move by UCC
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode, 
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT,
                  @cSourceType = 'rdt_1836ConfirmSP03', 
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility, 
                  @cFromLOC    = @cFromLOC, 
                  @cFromID     = @cFromID,  
                  @cToLOC      = @cFinalLoc, 
                  @cToID       = NULL,  -- NULL means not changing ID
                  @cSKU        = @cSKU,
                  @nQTY        = @nPickDtl_Qty,
                  @nFunc       = @nFunc, 
                  @cFromLot    = @cFromLot,
                  @nQTYAlloc   = @nQtyAlloc, 
                  @nQTYPick    = @nQtyPick,
                  @cTaskDetailKey = @cOriTaskDetailKey
      
               IF @nErrNo <> 0
                  GOTO RollbackTran
         
               --SELECT @nChkQty '@nChkQty', @nPickDtl_Qty '@nPickDtl_Qty'
               SET @nChkQty = @nChkQty - @nPickDtl_Qty

               IF NOT EXISTS ( SELECT 1 FROM @tLOT WHERE LOT = @cFromLot)
                  INSERT INTO @tLOT (Lot) VALUES (@cFromLot)

               FETCH NEXT FROM @ccurPD INTO @cFromLot, @nPickDtl_Qty
            END

            -- Double check qty already offset error
            IF @nChkQty > 0
            BEGIN
               SET @nErrNo = 166309
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset Error
               GOTO RollBackTran
            END
         
            FETCH NEXT FROM @ccurTD INTO @cOriTaskDetailKey, @nQTY
         END
         CLOSE @ccurTD
         DEALLOCATE @ccurTD
      END
   END
   ELSE
   BEGIN
      -- Move by UCC
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT,
         @cSourceType = 'rdt_1836ConfirmSP03', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cFromLOC, 
         @cFromID     = @cFromID,  
         @cToLOC      = @cFinalLoc, 
         @cToID       = NULL,  -- NULL means not changing ID
         @cSKU        = @cSKU,
         @nQTY        = @nQTY,
         @nFunc       = @nFunc, 
         @cFromLot    = @cFromLot,
         @nQTYAlloc   = @nQtyAlloc, 
         @nQTYPick    = @nQtyPick,
         @cDropID     = @cDropID
      
      IF @nErrNo <> 0
         GOTO RollbackTran
   END
   
   -- Unlock by ASTRPT task  
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
      ,@cFromLOC --FromLOC  
      ,'' --FromID  
      ,@cFinalLoc --SuggLOC  
      ,@cStorerKey --Storer  
      ,@nErrNo  OUTPUT  
      ,@cErrMsg OUTPUT  
 
   IF @nErrNo <> 0
      GOTO RollbackTran

   IF @cSuggestedLoc <> @cFinalLOC
   BEGIN
      -- Unlock by ASTRPT task (if user overwrite suggested toloc)  
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
         ,@cFromLOC --FromLOC  
         ,'' --FromID  
         ,@cSuggestedLoc --SuggLOC  
         ,@cStorerKey --Storer  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
 
      IF @nErrNo <> 0
         GOTO RollbackTran
   END
   
   IF @cType = 'RPF'
   BEGIN
      IF @nToLocIsLoseID = 1
         SET @cFromID = ''

      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
                  JOIN @tLOT LOT ON PD.Lot = LOT.Lot
                  WHERE PD.Storerkey = @cStorerKey
                  AND   PD.Loc = @cFinalLoc
                  AND   PD.Id = @cFromID
                  --AND   PD.Lot = @cFromLot
                  --AND   (( @nIsFromYogaMat = 0 AND PD.DropID = @cCaseID) OR ( PD.DropID = PD.DropID))
                  AND  PD.DropID = @cCaseID
                  AND   PD.[Status] IN ( '0', '3')
                  AND   O.[Type] = 'LULUECOM'
                  AND   O.UserDefine09 = @cWavekey)
      BEGIN
         SET @cTaskType = 'PK'
      END
      ELSE
      BEGIN
         SET @cTaskType = 'SPK'
         --SET @cCaseID = ''
      END
   
      DECLARE @ccurPK   CURSOR
      SET @ccurPK = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.Orderkey, PD.Lot, UOM, ISNULL( SUM( PD.Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
      JOIN @tLOT LOT ON PD.Lot = LOT.Lot
      WHERE PD.Storerkey = @cStorerKey
      AND   PD.Loc = @cFinalLoc
      AND   PD.Id = @cFromID
      --AND   (( @nIsFromYogaMat = 0 AND PD.DropID = @cCaseID) OR ( PD.DropID = PD.DropID))
      AND   PD.DropID = @cCaseID
      AND   PD.[Status] IN ( '0', '3') 
      AND   O.UserDefine09 = @cWavekey
      GROUP BY PD.OrderKey, PD.Lot, PD.UOM
      OPEN @ccurPK
      FETCH NEXT FROM @ccurPK INTO @cOrderkey, @cFromLot, @cUOM, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @b_success = 1        
         EXECUTE dbo.nspg_getkey        
            @KeyName       = 'TaskDetailKey',        
            @fieldlength   = 10,        
            @keystring     = @cNewTaskdetailKey OUTPUT,        
            @b_Success     = @b_success       OUTPUT,        
            @n_err         = @nErrNo           OUTPUT,        
            @c_errmsg      = @cErrMsg       OUTPUT
                    
         IF NOT @b_success = 1        
            GOTO RollBackTran

         -- 1 orders 1 pickmethod, check if this orders 
         -- already has pick task released earlier
         SET @cPickMethod = ''
         SELECT TOP 1 @cPickMethod = PickMethod 
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskType IN ('SPK', 'PK')
         AND   OrderKey = @cOrderkey
         AND   Storerkey = @cStorerKey
         AND   [Status] <> 'X'
         ORDER BY 1

         IF ISNULL( @cPickMethod, '') = ''
         BEGIN
            SELECT @cOrdType = [Type]
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderkey
            
            IF @cOrdType = 'LULUECOM'
            BEGIN
               IF EXISTS ( SELECT 1 FROM pickdetail WITH (NOLOCK) 
                           WHERE OrderKey = @cOrderkey
                           GROUP BY OrderKey 
                           HAVING SUM( Qty) > 1)
                  SET @cPickMethod = 'MULTIS'
               ELSE
                     SET @cPickMethod = 'SINGLES'
            END
            ELSE
               SET @cPickMethod = 'PP'
         END
             
         IF @cPickMethod = 'MULTIS'  
         BEGIN  
            SET @cMessage03 = @cOrderkey  
            SET @cPriority = '5'  
         END  
         ELSE IF @cPickMethod = 'SINGLES'
         BEGIN  
            SET @cMessage03 = @cWavekey  
            SET @cPriority = '4'  
         END  
         ELSE
         BEGIN
            SET @cMessage03 = @cOrderkey  
            SET @cPriority = '5'  
         END
         
         SELECT TOP 1 
            @cAreaKey = AreaKey,      
            @cLogicalFromLoc = LogicalLocation      
         FROM dbo.LOC LOC WITH (NOLOCK)      
         JOIN dbo.AreaDetail AD WITH (NOLOCK) ON ( LOC.PutawayZone = AD.PutawayZone)      
         WHERE LOC.Loc = @cFinalLoc
         AND   LOC.Facility = @cFacility   
         ORDER BY 1
         
         SELECT TOP 1 @cLoadKey = LoadKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderkey
         ORDER BY 1
         
         IF @cTaskType = 'SPK' 
         BEGIN
            SET @cPickMethod = 'PP'
            
            SELECT TOP 1 @cToLoc = LOC
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE OrderKey = @cOrderkey
            AND   WaveKey = @cWavekey
            AND   StorerKey = @cStorerKey
            ORDER BY 1
            
            IF @@ROWCOUNT = 0
               SELECT TOP 1 @cToLoc = LOC
               FROM rdt.rdtPTLStationLogQueue WITH (NOLOCK)
               WHERE OrderKey = @cOrderkey
               AND   WaveKey = @cWavekey
               AND   StorerKey = @cStorerKey
               ORDER BY 1

            IF EXISTS(SELECT 1               --(yeekung01)
                      FROM wave (NOLOCK)
                      where wavekey=@cWavekey
                      --and storerkey=@cStorerKey
                      and userdefine01<>'')
            BEGIN
               SET @cToLoc='LULUGRS'
            END
         END
         ELSE  -- @cTaskType = 'PK'
         BEGIN
            SELECT @cUserDefine02 = UserDefine02
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderkey
            
            SELECT @cToLoc = Long
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'WCSSTATION'
            AND   Code = @cUserDefine02
            AND   Storerkey = @cStorerKey
         END

         INSERT INTO dbo.TASKDETAIL        
         ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot, FromLoc, FromID, ToLoc, ToID, 
            SourceType, SourceKey, Priority, SourcePriority, Status, LogicalFromLoc, LogicalToLoc, PickMethod, Wavekey, 
            Listkey, Areakey, Message03, CaseID, LoadKey, OrderKey)        
         VALUES        
         ( @cNewTaskdetailKey, @cTaskType, @cStorerKey, @cSKU, @cUOM, 0, @nQty, @nQty, @cFromLot, @cFinalLoc, @cFromID, @cToLoc, '', 
            'rdt_1836ConfirmSP03', @cWavekey, @cPriority, '9', 'N', @cLogicalFromLoc, @cLogicalFromLoc, @cPickMethod, @cWavekey, 
            '', @cAreakey, @cMessage03, '', @cLoadKey, @cOrderkey)      
         
         IF @@ERROR <> 0
            GOTO RollBackTran

         UPDATE dbo.PickDetail SET 
            TaskDetailKey = @cNewTaskdetailKey, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE TaskDetailKey = @cSourceKey
         AND   OrderKey = @cOrderkey
         AND   Lot = @cFromLot

         IF @@ERROR <> 0
            GOTO RollBackTran
         
         FETCH NEXT FROM @ccurPK INTO @cOrderkey, @cFromLot, @cUOM, @nQTY
      END
   END
   
   -- For case coming from PTS area need update routing status
   SELECT @cWCSKey = WCSKey 
   FROM dbo.WCSRouting WITH (NOLOCK)
   WHERE ToteNo = @cCaseID
   AND   TaskType = 'PTS'
   AND   [Status] = '0'
   
   IF @cWCSKey <> ''
   BEGIN
      -- Update WCSRouting , WCSRoutingDetail  
      UPDATE dbo.WCSRoutingDetail  
      SET Status = '9'  
      WHERE WCSKey = @cWCSKey   
                  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 166626    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRODetErr'     
         GOTO RollBackTran    
      END  
                  
      UPDATE dbo.WCSRouting  
      SET Status = '9'  
      WHERE WCSKey = @cWCSKey  
                 
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 166627    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSROErr'     
         GOTO RollBackTran    
      END      
   END

   SET @ccurTD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT TaskDetailKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   AND   TaskType = 'ASTRPT'
   AND   Caseid = @cCaseID
   AND   [Status] = '0'
   AND   ToLoc = @cSuggestedLoc
   AND   Sku = @cSKU
   OPEN @ccurTD
   FETCH NEXT FROM @ccurTD INTO @cOriTaskDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update task
      UPDATE dbo.TaskDetail SET
         Status = '9',
         ToLOC = @cFinalLoc,
         UserKey = SUSER_SNAME(),
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE(), 
         Trafficcop = NULL
      WHERE TaskDetailKey = @cOriTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 145051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
         GOTO RollbackTran
      END

      FETCH NEXT FROM @ccurTD INTO @cOriTaskDetailKey
   END
   
   COMMIT TRAN rdt_1836ConfirmSP03 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1836ConfirmSP03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO