SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_ToteIDSKU03                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Close working batch                                               */
/*                                                                            */
/* Date       Rev Author      Purposes                                        */
/* 20-02-2018 1.0 ChewKP      WMS-3962 Created                                */
/* 07-10-2019 1.1 chermaine   WMS-10753 Add Event Log (cc01)                  */
/* 12-10-2020 1.2 YeeKung     Bug Fix (Change Alter to Create)                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Confirm_ToteIDSKU03] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) -- ID=confirm ID, CLOSECARTON/SHORTCARTON = confirm carton
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cScanID      NVARCHAR( 20) 
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cCartonID    NVARCHAR( 20) = '' 
   ,@nCartonQTY   INT           = 0
   ,@cNewCartonID NVARCHAR( 20) = ''   -- For close carton with balance
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActCartonID   NVARCHAR( 20)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT
   DECLARE @cPackDetailDropID NVARCHAR(20)
   DECLARE @cTrackNo       NVARCHAR( 20)
   DECLARE @cNotes         NVARCHAR( 30)
   DECLARE @cUserDefine03  NVARCHAR( 20)
          ,@cPairStation   NVARCHAR( 10) 
          ,@cStyle         NVARCHAR(20) 
          ,@cGroupKey      NVARCHAR(10) 
          ,@cLoc           NVARCHAR(10)
          ,@cStagingLoc    NVARCHAR(10) 
          ,@cPackStationLoc   NVARCHAR(10) 
          ,@cNewTaskDetailKey NVARCHAR(10) 
          ,@cTaskDetailKey    NVARCHAR(10) 
          ,@cPDLoc            NVARCHAR(10)
          ,@cPDID             NVARCHAR(18) 
          ,@cPDLot            NVARCHAR(10)
          ,@cPTLLoc           NVARCHAR(10) 
          ,@cPutawayZone      NVARCHAR(10) 
          ,@nCount            INT
          ,@nMultiOrder       INT
          ,@cFromLoc          NVARCHAR(10)
          ,@cAreaKey          NVARCHAR(10)
          ,@cSKUEndPosition   NVARCHAR(20)
          ,@cLight            NVARCHAR(1)
          ,@cTowerPosition    NVARCHAR(20)
          
   
   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR
   DECLARE @curPickTD CURSOR
   DECLARE @curTemp CURSOR

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   DECLARE @cUpdateTrackNo    NVARCHAR(1)
   DECLARE @cUpdatePackDetailDropID NVARCHAR(1)
          ,@cWaveKey          NVARCHAR(10) 
          ,@nPDQty            INT

   DECLARE @tTaskDetailKeyList TABLE (TaskDetailKey NVARCHAR(10) )      
   DECLARE @curTD CURSOR

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction

   IF EXISTS ( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) 
               WHERE Mobile = @nMobile 
               AND Func = @nFunc
               AND DeviceID <> '' )
   BEGIN
      SET @cLight = '1' -- Use light
   END
   ELSE
   BEGIN
      SET @cLight = '0' -- Not use
   END
      
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   --SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   --SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   --SET @cUpdateTrackNo = rdt.rdtGetConfig( @nFunc, 'UpdateTrackNo', @cStorerKey)
   --SET @cUpdatePackDetailDropID = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetailDropID', @cStorerKey)

   
   /***********************************************************************************************

                                                CONFIRM ID 

   ***********************************************************************************************/
   IF @cType = 'ID' 
   BEGIN
      -- Confirm entire ID
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, IPAddress, DevicePosition, ExpectedQTY
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND DropID = @cScanID
            AND SKU = @cSKU
            AND Status <> '9'
      OPEN @curPTL
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get carton
         SELECT 
            @cActCartonID = CartonID, 
            @cWaveKey = WaveKey,
            --@nGroupKey = RowRef, 
            @cStyle = UserDefine01,
            @cPTLLoc = Loc 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND IPAddress = @cIPAddress
            AND Position = @cPosition
         
         SET @nCount = 0 
         SET @nMultiOrder = 0 
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND WaveKey = @cWaveKey 
                  AND DropID = @cScanID
                  AND SKU = @cSKU 
                  AND UOM = '6' ) 
         BEGIN 
            SET @nCount = 2 -- SET as MultiOrder
         END
         ELSE
         BEGIN
            SELECT @nCount = Count(1)  OVER ()
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
                 AND WaveKey = @cWaveKey 
                 AND DropID = @cScanID
                 AND SKU = @cSKU 
            GROUP BY OrderKey 
         END
         --PRINT @nCount
         
         --SET @nCount = @@ROWCount 
         

         IF @nCount > 1 
         BEGIN
            SET @nMultiOrder = 1 
         END
         ELSE  
         BEGIN
            SET @nMultiOrder = 0 
         END
        -- Transaction at order level
         --SET @nTranCount = @@TRANCOUNT
         --BEGIN TRAN  -- Begin our own transaction
         --SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction
         
         -- Confirm PTLTran
         UPDATE PTL.PTLTran SET
            Status = '9', 
            QTY = ExpectedQTY, 
            CaseID = @cActCartonID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 119751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END
         
         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE PD.WaveKey = @cWaveKey
               AND PD.DropID = @cScanID
               AND PD.SKU = @cSKU
               AND PD.Status <= '5'
               AND PD.Status <> '4'
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 119752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Qty, Loc
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.WaveKey = @cWaveKey
                  AND PD.DropID = @cScanID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.Status <> '4'
                  AND PD.CaseID = ''
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPDQty, @cPDLoc 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               
               -- Confirm PickDetail
               UPDATE PickDetail SET
                  --Status = '5', 
                  CaseID = CASE WHEN @nMultiOrder = 1 THEN 'SORTED' ELSE 'FULLCASE' END,
                  DropID = CASE WHEN @nMultiOrder = 1 THEN @cActCartonID ELSE DropID END, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END

               --SELECT * FROM pickdetail WITH (NOLOCK) WHERE PickDetailKEy = @cPickDetailKey

               --IF @nMultiOrder = 0
               --   SET @cActCartonID = @cScanID

               --SET @cPDLoc = ''
               --SET @cPDID = ''
               --SET @cPDLot = '' 
               --SET @cPutawayZone = ''
               --SET @cPTLLoc = ''
               
               --SELECT @cPTLLoc '@cPTLLoc' , @nPDQty '@nPDQty' , @nCartonQTY '@nCartonQTY' , @nMultiOrder '@nMultiOrder' , @cPDLoc '@cPDLoc' , @cPDID '@cPDID' , @cPDLot '@cPDLot' , @cCartonID '@cCartonID' , @cSKU '@cSKU' , @cCartonID '@cCartonID' , @cScanID '@cScanID', @cActCartonID '@cActCartonID'

               --SELECT @cPDLoc '@cPDLoc' , @cPDID '@cPDID' , @cPDLot '@cPDLot' , @cPTLLoc 'cPTLLoc' , @cPutawayZone '@cPutawayZone' , @nExpectedQTY '@nExpectedQTY', @cSKU '@cSKU'
               --select * from pickdetail (nolocK) where wavekey = '0000006558' and caseid = 'SORTED' 
         
               IF @nMultiOrder = 1
               BEGIN
                  EXECUTE rdt.rdt_Move  
                  @nMobile     = @nMobile,  
                  @cLangCode   = @cLangCode,  
                  @nErrNo      = @nErrNo  OUTPUT,  
                  @cErrMsg     = @cErrMsg OUTPUT,  
                  @cSourceType = 'rdt_PTLStation_Confirm_ToteIDSKU03',  
                  @cStorerKey  = @cStorerKey,  
                  @cFacility   = @cFacility,  
                  @cFromLOC    = @cPDLoc,  
                  @cToLOC      = @cPTLLoc, -- Final LOC  
                  @cFromID     = @cPDID,  
                  @cToID       = '',  
                  @cSKU        = @cSKU,  
                  @nQty        = @nPDQty,--@nExpectedQTY,  
                  @nQTYAlloc   = @nPDQty,--@nExpectedQTY,  
                  @cDropID     = @cActCartonID,
                  --@cFromLOT    = @cPDLot,
                  @nFunc       = 805
           
                  IF @nErrNo <> 0  
                  GOTO RollBackTran  
               END

               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPDQty, @cPDLoc 
            END
         END
         
         
                  
         
         -- Commit order level
         --COMMIT TRAN rdt_PTLStation_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_PTLStation_Confirm
         
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
      END
      
      
      -- Generate Task and Light Up Tower Light
--      SELECT 
--         @nGroupKey = RowRef, 
--         --@cOrderKey = OrderKey
--         @cWaveKey = WaveKey, 
--         --@cCartonID = CartonID,
--         @cStyle = UserDefine02
--      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
--      WHERE Station = @cStation
--         AND IPAddress = @cIPAddress
--         AND Position = @cPosition
      
      

      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU ) 
                     WHERE PD.StorerKey = @cStorerKey
                     AND PD.WaveKey = @cWaveKey
                     AND SKU.Style = @cStyle
                     AND CaseID = ''
                     AND Status = '3' )     
      BEGIN
         
         DELETE @tTaskDetailKeyList

         -- Generate TaskDetail

         SET @curTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.OrderKey, PD.SKU, SUM(PD.QTY), PD.Loc 
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.WaveKey =  O.UserDefine09)
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU AND PD.OrderKey = O.OrderKey ) 
               WHERE PD.WaveKey = @cWaveKey
                  --AND SKU = @cSKU
                  --AND DropID = @cDropID
                  AND PD.Status = '3'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
                  AND SKU.Style = @cStyle
                  AND PD.CaseID = 'SORTED'
               GROUP BY PD.OrderKey, PD.SKU, PD.Loc  
                  
            OPEN @curTD
            FETCH NEXT FROM @curTD INTO @cOrderKey, @cSKU, @nPDQty, @cFromLoc 
         WHILE @@FETCH_STATUS = 0
         BEGIN
            
            

            IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND Message01 = @cStyle
                           AND OrderKey = @cOrderKey
                           AND TaskType = 'FCP'
                           AND Status = 'H' )
            BEGIN  
                          
               SET @cGroupKey = ''
               SET @bSuccess = 1
               EXECUTE dbo.nspg_getkey
         	      'TRIPLEGKey'
         	      , 10
         	      , @cGroupKey         OUTPUT
         	      , @bSuccess          OUTPUT
         	      , @nErrNo            OUTPUT
         	      , @cErrMsg           OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 119754
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cGroupKey = GroupKey
               FROM dbo.TaskDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND Message01 = @cStyle
               AND OrderKey = @cOrderKey
               AND TaskType = 'FCP'
               AND Status = 'H'
            END
            
            --SET @cLoc = 'TRIPICK001'
            
            SELECT @cFacility = Facility
            FROM dbo.Loc WITH (NOLOCK)
            WHERE Loc = @cFromLoc  
            
            SELECT TOP 1  @cStagingLoc = PZ.InLoc
                        , @cPackStationLoc = PZ.OutLoc
            FROM dbo.PutawayZone PZ WITH (NOLOCK)
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON Loc.PutawayZone = PZ.PutawayZone
            WHERE Loc.Loc = @cFromLoc 
            AND Loc.Facility = @cFacility
            
            
            SET @cNewTaskDetailKey = ''
            SET @bSuccess = 1
            EXECUTE dbo.nspg_getkey
            	'TASKDETAILKEY'
            	, 10
            	, @cNewTaskDetailKey OUTPUT
            	, @bSuccess          OUTPUT
            	, @nErrNo            OUTPUT
            	, @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 119755
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
               GOTO RollBackTran
            END
            
            INSERT INTO @tTaskDetailKeyList VALUES ( @cNewTaskDetailKey)

            SELECT TOP 1 @cAreaKey = A.AreaKey
            FROM dbo.AreaDetail A WITH (NOLOCK) 
            INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON P.PutawayZone = A.PutawayZone
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
            WHERE Loc.Facility = @cFacility
            AND Loc.Loc = @cFromLoc
            
            --Hold the Task with Status = 'H'
            INSERT INTO dbo.TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, SKU, Qty, AreaKey, SystemQty, 
               PickMethod, StorerKey, Message01, Message02, OrderKey, WaveKey, SourceType, GroupKey, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'FCP', 'H', '', @cFromLoc, '', @cPackStationLoc, '', @cSKU, @nPDQty, ISNULL(@cAreaKey,''), @nPDQty,
               'PP', @cStorerKey, @cStyle, '', @cOrderKey, @cWaveKey, 'PTLStation_Confirm_ToteIDSKU03', @cOrderKey, '9', '9', NULL)
            
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 119756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END
               
               

            -- Update PickDetail to new TaskDetailKey 

            SET @curPickTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetailKey
            FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.WaveKey =  O.UserDefine09 AND PD.OrderKey = O.OrderKey)
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU ) 
                  WHERE PD.WaveKey = @cWaveKey
                  AND PD.SKU = @cSKU
                  AND O.OrderKey = @cOrderKey 
                  --AND DropID = @cDropID
                  AND PD.Status = '3'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
                  AND SKU.Style = @cStyle
                  AND PD.CaseID = 'SORTED'
                  AND PD.Loc    = @cFromLoc
                  
            OPEN @curPickTD
            FETCH NEXT FROM @curPickTD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               
                  
               -- Confirm PickDetail
               UPDATE PickDetail SET
                  TaskDetailKey = @cNewTaskDetailKey,
                  --CaseID = @cCartonID,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  TrafficCop = NULL 
                  
               WHERE PickDetailKey = @cPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119757
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM @curPickTD INTO @cPickDetailKey
            
            END
            
            SELECT @cSKUEndPosition = DevicePosition 
            FROM dbo.DeviceProfile WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND Loc = @cFromLoc
            AND LogicalName = 'PTL'
            
            IF @cLight  = '1' 
            BEGIN
               -- LIGHT UP LOCATION to 'EnD'
               EXEC PTL.isp_PTL_LightUpLoc  
                  @n_Func           = @nFunc  
                 ,@n_PTLKey         = 0  
                 ,@c_DisplayValue   = 'EnD'  
                 ,@b_Success        = @bSuccess    OUTPUT      
                 ,@n_Err            = @nErrNo      OUTPUT    
                 ,@c_ErrMsg         = @cErrMsg     OUTPUT  
                 ,@c_DeviceID       = @cStation1  
                 ,@c_DevicePos      = @cSKUEndPosition  
                 ,@c_DeviceIP       = @cIPAddress    
                 ,@c_LModMode       = '16'  
            END
            
            FETCH NEXT FROM @curTD INTO @cOrderKey, @cSKU, @nPDQty, @cFromLoc 
            
            
         END
         
         -- Release Task 
         SET @curTemp = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TaskDetailKey 
         FROM @tTaskDetailKeyList 
               
         OPEN @curTemp
         FETCH NEXT FROM @curTemp INTO @cTaskDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
                        
            -- Confirm PickDetail
            UPDATE dbo.TaskDetail SET
               Status = '0',
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(),
               TrafficCop = NULL 
            WHERE TaskDetailKey = @cTaskDetailKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 119758
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TaskDet Fail
               GOTO RollBackTran
            END
            
            FETCH NEXT FROM @curTemp INTO @cTaskDetailKey
         
         END
      
--         SELECT  @cPutawayZone = PutawayZone  
--                 --, @cFacility    = Facility  
--         FROM dbo.Loc WITH (NOLOCK)   
--         WHERE Loc = @cLoc  
           
   --      SELECT @cTowerLightLoc = Loc  
   --      FROM dbo.Loc WITH (NOLOCK)  
   --      WHERE PutawayZone = @cPutawayZone  
   --      AND Facility = @cFacility   
           
           
         SELECT @cTowerPosition = DevicePosition   
         FROM dbo.DeviceProfile WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND Loc = @cStation1  
         AND IPAddress = @cIPAddress 
     
         --SELECT @cTowerPosition '@cTowerPosition'   
         IF @cLight = '1'
         BEGIN 
            IF ISNULL(@cTowerPosition,'')  <> ''         
            BEGIN  
               -- Light Up Tower Light  
               EXEC PTL.isp_PTL_LightUpTowerLight  
                  @c_StorerKey     = @cStorerKEy  
                 ,@n_Func          = @nFunc  
                 ,@c_DeviceID      = @cStation1  
                 ,@c_LightAddress  = @cTowerPosition  
                 ,@c_ActionType    = 'ON'  
                 ,@c_DeviceIP      = @cIPAddress
                 ,@b_Success       = @bSuccess    OUTPUT   
                 ,@n_Err           = @nErrNo      OUTPUT  
                 ,@c_ErrMsg        = @cErrMsg     OUTPUT  
        
      --         EXEC PTL.isp_PTL_LightUpLoc  
      --            @n_Func           = @nFunc  
      --           ,@n_PTLKey         = 0  
      --           ,@c_DisplayValue   = '9999'  
      --           ,@b_Success        = @bSuccess    OUTPUT      
      --           ,@n_Err            = @nErrNo      OUTPUT    
      --           ,@c_ErrMsg         = @cErrMsg     OUTPUT  
      --           ,@c_DeviceID       = @cStation  
      --           ,@c_DevicePos      = @cTowerPosition  
      --           ,@c_DeviceIP       = @cIPAddress    
      --           ,@c_LModMode       = '16'  
            END  
         END 
         
      END
    
      -- EventLog - (cc01)
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', 
        @cUserID     = '',
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cOrderKey   = @cOrderKey,
        @cSKU        = @cSKU,
        @nQty        = @nQTY_PD
      
   END


   /***********************************************************************************************

                                              CONFIRM CARTON 

   ***********************************************************************************************/
   -- Confirm carton
   IF @cType <> 'ID'
   BEGIN
      -- Handling transaction
      --SET @nTranCount = @@TRANCOUNT
      --BEGIN TRAN  -- Begin our own transaction
      --SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction

      
      
      -- Close with QTY or short 
      IF (@cType = 'CLOSECARTON' AND @nCartonQTY > 0) OR
         (@cType = 'SHORTCARTON')
      BEGIN
         

         --SELECT  TOP 1 @cIPAddress = IPAddress, 
         --              @cPosition = DevicePosition, 
         --              @cWaveKey = SourceKey 
         --FROM PTL.PTLTran WITH (NOLOCK) 
         --WHERE StorerKey = @cStorerKey
         --AND CaseID = @cCartonID
         ----AND DropID = @cScanID 
         ----AND SKU = @cSKU 
         --ORDER BY Editdate Desc

         SELECT 
            --@cCartonID = CartonID,
            --@cWaveKey = WaveKey,
            --@nGroupKey = RowRef, 
            @cIPAddress = IPAddress, 
            @cPosition = Position, 
            @cWaveKey = WaveKey,
            @cStyle = UserDefine01,
            @cPTLLoc = Loc 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = @cCartonID
            AND StorerKey = @cStorerKey 
            --AND Position = @cPosition
            
         SET @nCount = 0 
         SET @nMultiOrder = 0 
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND WaveKey = @cWaveKey 
                  AND DropID = @cScanID
                  AND SKU = @cSKU 
                  AND UOM = '6' ) 
         BEGIN 
            SET @nCount = 2 -- SET as MultiOrder
         END
         ELSE
         BEGIN
            SELECT @nCount = Count(1)  OVER ()
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
                 AND WaveKey = @cWaveKey 
                 AND DropID = @cScanID
                 AND SKU = @cSKU 
            GROUP BY OrderKey 
         END
         --PRINT @nCount
         
         --SET @nCount = @@ROWCount 
         

         IF @nCount > 1 
         BEGIN
            SET @nMultiOrder = 1 
         END
         ELSE  
         BEGIN
            SET @nMultiOrder = 0 
         END
         
         -- Get carton info
         --SELECT 
         --   @cIPAddress = IPAddress, 
         --   @cPosition = Position, 
         --   @cWaveKey = WaveKey
         --FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         --WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         --   AND CartonID = @cCartonID
         
         SET @nExpectedQTY = NULL
         SET @nQTY_Bal = @nCartonQTY    
         
         --SELECT @nQTY_Bal '@nQTY_Bal' 

         -- PTLTran
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, ExpectedQTY            
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE IPAddress = @cIPAddress 
               AND DevicePosition = @cPosition
               AND DropID = @cScanID
               AND SKU = @cSKU
               AND Status <> '9'    
         OPEN @curPTL
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         WHILE @@FETCH_STATUS = 0
         BEGIN
            

            --SELECT @nQTY_PTL '@nQTY_PTL' , @nQTY_Bal '@nQTY_Bal' 
            
            IF @nExpectedQTY IS NULL
               SET @nExpectedQTY = @nQTY_PTL
            
            -- Exact match
            IF @nQTY_PTL = @nQTY_Bal
            BEGIN
               -- Confirm PTLTran
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                  Status = '9', 
                  QTY = ExpectedQTY, 
                  CaseID = @cCartonID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119760
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
                             
      
               SET @nQTY_Bal = 0 -- Reduce balance
            END
            
            -- PTLTran have less
      		ELSE IF @nQTY_PTL < @nQTY_Bal
            BEGIN
               -- Confirm PickDetail
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                  Status = '9',
                  QTY = ExpectedQTY, 
                  CaseID = @cCartonID, 
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119761
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
      
               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PTL -- Reduce balance
            END
            
            -- PTLTran have more
      		ELSE IF @nQTY_PTL > @nQTY_Bal
            BEGIN
               -- Short pick
               IF @cType = 'SHORTCARTON' AND @nQTY_Bal = 0 -- Don't need to split
               BEGIN
                  -- Confirm PTLTran
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     QTY = 0, 
                     CaseID = @cCartonID, 
                     TrafficCop = NULL, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 119762
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN -- Have balance, need to split
                   -- Create new a PTLTran to hold the balance
                  INSERT INTO PTL.PTLTran (
                     ExpectedQty, QTY, TrafficCop, 
                     IPAddress, DeviceID, DevicePosition, Status, LightUp, LightMode, LightSequence, PTLType, SourceKey, DropID, CaseID, RefPTLKey, 
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, SourceType, ArchiveCop)
                  SELECT 
                     @nQTY_PTL - @nQTY_Bal, 0, NULL, 
                     IPAddress, DeviceID, DevicePosition, Status, LightUp, LightMode, LightSequence, PTLType, SourceKey, DropID, CaseID, RefPTLKey, 
                     Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'PTLStation_Confirm_ToteIDSKU03', ArchiveCop
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 119763
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PTL Fail
                     GOTO RollBackTran
                  END
         
                  -- Confirm orginal PTLTran with exact QTY
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     ExpectedQty = @nQTY_Bal, 
                     QTY = @nQTY_Bal, 
                     CaseID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME(), 
                     Trafficcop = NULL
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 119764
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END
            
            -- Exit condition
            IF @cType = 'CLOSECARTON' AND @nQTY_Bal = 0
               BREAK
            
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         END
               
         

         -- PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN            
            
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE PD.WaveKey = @cWaveKey
               AND PD.DropID = @cScanID
               AND PD.SKU = @cSKU
               AND PD.Status <= '5'
               AND PD.Status <> '4'
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            --SELECT @nQTY_PD '@nQTY_PD' , @nExpectedQTY '@nExpectedQTY', @cScanID '@cScanID' , @cSKU '@cSKU' , @cWaveKey '@cWaveKey' 

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 119759
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            
            -- For calculation
            SET @nQTY_Bal = @nCartonQTY

            
         
            -- Get PickDetail candidate
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT PickDetailKey, QTY, Loc
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.WaveKey = @cWaveKey
                  AND PD.DropID = @cScanID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.Status <> '4'
                  AND PD.CaseID = ''
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cFromLoc 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               
               -- Exact match
               IF @nQTY_PD = @nQTY_Bal
               BEGIN
                  

                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     --Status = '5',
                     CaseID = CASE WHEN @nMultiOrder = 1 THEN 'SORTED' ELSE 'FULLCASE' END, --'SORTED', 
                     --DropID = @cCartonID, 
                     DropID = CASE WHEN @nMultiOrder = 1 THEN @cCartonID ELSE DropID END, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 119765
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
               
               -- PickDetail have less
         		ELSE IF @nQTY_PD < @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     --Status = '5',
                     CaseID = 'SORTED', 
                     --DropID = @cCartonID, 
                     DropID = CASE WHEN @nMultiOrder = 1 THEN @cCartonID ELSE DropID END, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 119766
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
               END
               
               -- PickDetail have more
         		ELSE IF @nQTY_PD > @nQTY_Bal
               BEGIN
                  -- Short pick
                  IF @cType = 'SHORTCARTON' AND @nQTY_Bal = 0 -- Don't need to split
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '4',
                        CaseID = '', 
                        --DropID = @cCartonID, 
                        --DropID = CASE WHEN @nMultiOrder = 1 THEN @cCartonID ELSE DropID END, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME()
                        --TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 119767
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                  END
                  ELSE
                  BEGIN -- Have balance, need to split
         
                     -- Get new PickDetailkey
                     DECLARE @cNewPickDetailKey NVARCHAR( 10)
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY', 
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 119768
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey
                        GOTO RollBackTran
                     END
            
                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                        PickDetailKey, 
                        QTY, 
                        TrafficCop,
                        OptimizeCop)
                     SELECT 
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                        @cNewPickDetailKey, 
                        @nQTY_PD - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK) 
            			WHERE PickDetailKey = @cPickDetailKey			            
                     IF @@ERROR <> 0
                     BEGIN
            				SET @nErrNo = 119769
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Get PickDetail info
                     DECLARE @cOrderLineNumber NVARCHAR( 5)
                     DECLARE @cLoadkey NVARCHAR( 10)
                     SELECT 
                        @cOrderLineNumber = OD.OrderLineNumber, 
                        @cLoadkey = OD.Loadkey
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                        INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
                     WHERE PD.PickDetailkey = @cPickDetailKey
                     
                     -- Get PickSlipNo
                     SET @cPickSlipNo = ''
                     SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
                     IF @cPickSlipNo = ''
                        SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
                     
                     -- Insert into 
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 119770
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                        GOTO RollBackTran
                     END
                     
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        QTY = @nQTY_Bal, 
                        CaseID = 'SORTED', 
                        --DropID = @cCartonID, 
                        DropID = CASE WHEN @nMultiOrder = 1 THEN @cCartonID ELSE DropID END, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(), 
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey 
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 119771
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Confirm orginal PickDetail with exact QTY
--                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
--                        Status = '5',
--                        EditDate = GETDATE(), 
--                        EditWho  = SUSER_SNAME() 
--                     WHERE PickDetailKey = @cPickDetailKey
--                     IF @@ERROR <> 0
--                     BEGIN
--                        SET @nErrNo = 119772
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
--                        GOTO RollBackTran
--                     END
            
                     SET @nQTY_Bal = 0 -- Reduce balance
                  END
               END
               
           
               -- Exit condition
               IF @cType = 'CLOSECARTON' AND @nQTY_Bal = 0
                  BREAK
         
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cFromLoc 
            END 
         END
         
         -- Perform Move -- 
         -- Move Total Qty 
         --SELECT TOP 1 
         --         @cPDLoc = PD.Loc
         --       , @cPDID  = PD.ID
         --       , @cPDLot = PD.Lot   
         --FROM dbo.PickDetail WITH (NOLOCK)
         --INNER JOIN 
         --WHERE StorerKey = @cStorerKey
         --AND DropID = @cCartonID
         --AND SKU = @cSKU
         --AND CASEID = 'SORTED'


            IF @nMultiOrder = 0
               SET @cCartonID = @cScanID

            SET @cPDLoc = ''
            SET @cPDID = ''
            SET @cPDLot = '' 
            SET @cPutawayZone = ''
            --SET @cPTLLoc = ''

            SELECT TOP 1   
                  @cPDLoc = PD.Loc  
                , @cPDID  = PD.ID  
                , @cPDLot = PD.Lot     
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            INNER JOIN dbo.Loc WITH (NOLOCK) ON Loc.Loc = PD.Loc   
            WHERE PD.StorerKey = @cStorerKey  
            AND PD.DropID = CASE WHEN @nMultiOrder = 1 THEN @cCartonID ELSE DropID END--, @cCartonID  
            AND PD.SKU = @cSKU  
            AND PD.CASEID = 'SORTED'  
            AND Loc.Facility = @cFacility  
            AND Loc.LocationCategory = 'INDUCTION'  

            --SELECT @cPDLoc '@cPDLoc' , @cPDID '@cPDID' , @cPDLot '@cPDLot' , @cCartonID '@cCartonID' , @cSKU '@cSKU' , @nMultiOrder '@nMultiOrder' 

            SELECT @cPutawayZone = PutawayZone 
            FROM dbo.Loc WITH (NOLOCK) 
            WHERE Loc = @cPDLoc
            AND Facility = @cFacility

            IF @nMultiOrder = 0 
            BEGIN
               SET @cPTLLoc = ''
               SELECT @cPTLLoc = OutLoc 
               FROM dbo.PutawayZone WITH (NOLOCK) 
               WHERE PutawayZone = @cPutawayZone 
            END

            --SELECT @cPDLoc '@cPDLoc' , @cPDID '@cPDID' , @cPDLot '@cPDLot' , @cPTLLoc 'cPTLLoc' , @cPutawayZone '@cPutawayZone' , @nExpectedQTY '@nExpectedQTY', @cSKU '@cSKU', @nCartonQTY '@nCartonQTY'
            --select * from pickdetail (nolocK) where wavekey = '0000006558' and caseid = 'SORTED' 
         
            IF ISNULL(@cPDLoc,'')  <> '' AND ISNULL(@cPDLot,'')  <> ''  --AND @cType <> 'SHORTCARTON'
            BEGIN
               EXECUTE rdt.rdt_Move  
               @nMobile     = @nMobile,  
               @cLangCode   = @cLangCode,  
               @nErrNo      = @nErrNo  OUTPUT,  
               @cErrMsg     = @cErrMsg OUTPUT,  
               @cSourceType = 'rdt_PTLStation_Confirm_ToteIDSKU03',  
               @cStorerKey  = @cStorerKey,  
               @cFacility   = @cFacility,  
               @cFromLOC    = @cPDLoc,  
               @cToLOC      = @cPTLLoc, -- Final LOC  
               @cFromID     = @cPDID,  
               @cToID       = '',  
               @cSKU        = @cSKU,  
               @nQty        = @nCartonQTY,--@nExpectedQTY,  
               @nQTYAlloc   = @nCartonQTY,--@nExpectedQTY,  
               @cDropID     = @cCartonID,
               --@cFromLOT    = @cPDLot,
               @nFunc       = 805
           
               IF @nErrNo <> 0  
               GOTO RollBackTran  
            END
         
         

                     
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                        INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU ) 
                        WHERE PD.StorerKey = @cStorerKey
                        AND PD.WaveKey = @cWaveKey
                        AND SKU.Style = @cStyle
                        AND CaseID = ''
                        AND Status = '3' )     
         BEGIN
            

            DELETE @tTaskDetailKeyList

            -- Generate TaskDetail

            --select @cStyle '@cStyle' , @cWaveKey '@cWaveKey' 



           
            SET @curTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.OrderKey, PD.SKU, SUM(PD.QTY), PD.Loc 
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.WaveKey =  O.UserDefine09)
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU AND PD.OrderKey = O.OrderKey ) 
               WHERE PD.WaveKey = @cWaveKey
                  --AND SKU = @cSKU
                  --AND DropID = @cDropID
                  AND PD.Status = '3'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
                  AND SKU.Style = @cStyle
                  AND PD.CaseID = 'SORTED'
               GROUP BY PD.OrderKey, PD.SKU, PD.Loc  
                  
            OPEN @curTD
            FETCH NEXT FROM @curTD INTO @cOrderKey, @cSKU, @nPDQty, @cFromLoc 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               
               
               
               IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerKey
                              AND Message01 = @cStyle
                              AND OrderKey = @cOrderKey
                              AND TaskType = 'FCP'
                              AND Status = 'H' )
               BEGIN  
                             
                  SET @cGroupKey = ''
                  SET @bSuccess = 1
                  EXECUTE dbo.nspg_getkey
            	      'TRIPLEGKey'
            	      , 10
            	      , @cGroupKey         OUTPUT
            	      , @bSuccess          OUTPUT
            	      , @nErrNo            OUTPUT
            	      , @cErrMsg           OUTPUT
                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 119754
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  SELECT TOP 1 @cGroupKey = GroupKey
                  FROM dbo.TaskDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND Message01 = @cStyle
                  AND OrderKey = @cOrderKey
                  AND TaskType = 'FCP'
                  AND Status = 'H'
               END
               
               --SET @cLoc = 'TRIPICK001'

               
               SELECT @cFacility = Facility
               FROM dbo.Loc WITH (NOLOCK)
               WHERE Loc = @cFromLoc 
               
               SELECT TOP 1  @cStagingLoc = PZ.InLoc
                           , @cPackStationLoc = PZ.OutLoc
               FROM dbo.PutawayZone PZ WITH (NOLOCK)
               INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON Loc.PutawayZone = PZ.PutawayZone
               WHERE Loc.Loc = @cFromLoc
               AND Loc.Facility = @cFacility
               
               
               SET @cNewTaskDetailKey = ''
               SET @bSuccess = 1
               EXECUTE dbo.nspg_getkey
               	'TASKDETAILKEY'
               	, 10
               	, @cNewTaskDetailKey OUTPUT
               	, @bSuccess          OUTPUT
               	, @nErrNo            OUTPUT
               	, @cErrMsg           OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 119755
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                  GOTO RollBackTran
               END
               
               INSERT INTO @tTaskDetailKeyList VALUES ( @cNewTaskDetailKey)
               
               SELECT TOP 1 @cAreaKey = A.AreaKey
               FROM dbo.AreaDetail A WITH (NOLOCK) 
               INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON P.PutawayZone = A.PutawayZone
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
               WHERE Loc.Facility = @cFacility
               AND Loc.Loc = @cFromLoc
            
               --Hold the Task with Status = 'H'
               INSERT INTO dbo.TaskDetail (
                  TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, SKU, Qty, AreaKey,
                  PickMethod, StorerKey, Message01, Message02, OrderKey, WaveKey, SourceType, GroupKey, Priority, SourcePriority, TrafficCop)
               VALUES (
                  @cNewTaskDetailKey, 'FCP', 'H', '', @cFromLoc, '', @cPackStationLoc, '', @cSKU, @nPDQty, ISNULL(@cAreaKey,''),
                  'PP', @cStorerKey, @cStyle, '', @cOrderKey, @cWaveKey, 'PTLStation_Confirm_ToteIDSKU03', @cOrderKey, '9', '9', NULL)
               
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119756
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                  GOTO RollBackTran
               END
                  
               

               -- Update PickDetail to new TaskDetailKey 

               SET @curPickTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM dbo.Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.WaveKey =  O.UserDefine09 AND PD.OrderKey = O.OrderKey)
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU ) 
                     WHERE PD.WaveKey = @cWaveKey
                     AND PD.SKU = @cSKU
                     AND O.OrderKey = @cOrderKey 
                     --AND DropID = @cDropID
                     AND PD.Status = '3'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC'
                     AND O.SOStatus <> 'CANC'
                     AND SKU.Style = @cStyle
                     AND PD.CaseID = 'SORTED'
                     AND PD.Loc    = @cFromLoc
                     
               OPEN @curPickTD
               FETCH NEXT FROM @curPickTD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  
                     
                  -- Confirm PickDetail
                  UPDATE PickDetail SET
                     TaskDetailKey = @cNewTaskDetailKey,
                     --CaseID = @cCartonID,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     TrafficCop = NULL 
                     
                  WHERE PickDetailKey = @cPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 119757
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END
                  
                  FETCH NEXT FROM @curPickTD INTO @cPickDetailKey
               
               END
               
               
               SELECT @cSKUEndPosition = DevicePosition 
               FROM dbo.DeviceProfile WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND Loc = @cFromLoc
               AND LogicalName = 'PTL'
               
               IF @cLight = '1'
               BEGIN
                  -- LIGHT UP LOCATION to 'EnD'
                  EXEC PTL.isp_PTL_LightUpLoc  
                     @n_Func           = @nFunc  
                    ,@n_PTLKey         = 0  
                    ,@c_DisplayValue   = 'EnD'  
                    ,@b_Success        = @bSuccess    OUTPUT      
                    ,@n_Err            = @nErrNo      OUTPUT    
                    ,@c_ErrMsg         = @cErrMsg     OUTPUT  
                    ,@c_DeviceID       = @cStation1  
                    ,@c_DevicePos      = @cSKUEndPosition  
                    ,@c_DeviceIP       = @cIPAddress    
                    ,@c_LModMode       = '16'  
               END
               
               FETCH NEXT FROM @curTD INTO @cOrderKey, @cSKU, @nPDQty, @cFromLoc 
               
               
            END
            
            -- Release Task 
            SET @curTemp = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TaskDetailKey 
            FROM @tTaskDetailKeyList 
                  
            OPEN @curTemp
            FETCH NEXT FROM @curTemp INTO @cTaskDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
                           
               -- Confirm PickDetail
               UPDATE dbo.TaskDetail SET
                  Status = '0',
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  TrafficCop = NULL 
               WHERE TaskDetailKey = @cTaskDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119758
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TaskDet Fail
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM @curTemp INTO @cTaskDetailKey
            
            END
   
--            SELECT  @cPutawayZone = PutawayZone  
--                    --, @cFacility    = Facility  
--            FROM dbo.Loc WITH (NOLOCK)   
--            WHERE Loc = @cStation1  
              
      --      SELECT @cTowerLightLoc = Loc  
      --      FROM dbo.Loc WITH (NOLOCK)  
      --      WHERE PutawayZone = @cPutawayZone  
      --      AND Facility = @cFacility   
              
              
            SELECT @cTowerPosition = DevicePosition   
            FROM dbo.DeviceProfile WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND Loc = @cStation1  
            AND IPAddress = @cIPAddress 
        
            --SELECT @cTowerPosition '@cTowerPosition'   
            IF @cLight = '1'
            BEGIN 
               IF ISNULL(@cTowerPosition,'')  <> ''         
               BEGIN  
                  -- Light Up Tower Light  
                  EXEC PTL.isp_PTL_LightUpTowerLight  
                     @c_StorerKey     = @cStorerKEy  
                    ,@n_Func          = @nFunc  
                    ,@c_DeviceID      = @cStation1  
                    ,@c_LightAddress  = @cTowerPosition  
                    ,@c_ActionType    = 'ON'  
                    ,@c_DeviceIP      = @cIPAddress
                    ,@b_Success       = @bSuccess    OUTPUT   
                    ,@n_Err           = @nErrNo      OUTPUT  
                    ,@c_ErrMsg        = @cErrMsg     OUTPUT  
           
         --         EXEC PTL.isp_PTL_LightUpLoc  
         --            @n_Func           = @nFunc  
         --           ,@n_PTLKey         = 0  
         --           ,@c_DisplayValue   = '9999'  
         --           ,@b_Success        = @bSuccess    OUTPUT      
         --           ,@n_Err            = @nErrNo      OUTPUT    
         --           ,@c_ErrMsg         = @cErrMsg     OUTPUT  
         --           ,@c_DeviceID       = @cStation  
         --           ,@c_DevicePos      = @cTowerPosition  
         --           ,@c_DeviceIP       = @cIPAddress    
         --           ,@c_LModMode       = '16'  
               END  
            END 
            
              
            
         END            

         -- Move Qty
         -- PackDetail
--         IF @cUpdatePackDetail = '1'
--         BEGIN
--            -- Get PickSlipNo
--            SET @cPickSlipNo = ''
--            SELECT @cPickslipno = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--            
--            -- PackHeader
--            IF @cPickSlipNo = ''
--            BEGIN
--               SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--               IF @cPickSlipNo = ''
--               BEGIN
--                  -- Generate PickSlipNo
--                  EXECUTE dbo.nspg_GetKey
--                     'PICKSLIP',
--                     9,
--                     @cPickslipNo   OUTPUT,
--                     @bSuccess      OUTPUT,
--                     @nErrNo        OUTPUT,
--                     @cErrMsg       OUTPUT  
--                  IF @nErrNo <> 0
--                     GOTO RollBackTran
--         
--                  SET @cPickslipNo = 'P' + @cPickslipNo
--               END
--               
--               INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
--               VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118223
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
--                  GOTO RollBackTran
--               END
--            END
--            
--            -- Get carton no
--            SET @nCartonNo = 0
--            SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID
--
--            -- New carton
--            IF @nCartonNo = 0
--            BEGIN
--               -- Grap a track no
--               IF @cUpdateTrackNo = '1'
--               BEGIN
--                  -- Get order info
--                  SELECT @cUserDefine03 = UserDefine03 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--                  
--                  -- Get code lookup info
--                  SELECT TOP 1 
--                     @cNotes = LEFT( ISNULL( Notes, ''), 30)
--                  FROM CodeLKUP WITH (NOLOCK) 
--                  WHERE ListName = 'LOTTELBL' 
--                     AND Short = @cUserDefine03
--                     AND StorerKey = @cStorerKey
--                  
--                  -- Get track no
--                  SELECT TOP 1 
--                     @nRowRef = RowRef, 
--                     @cTrackNo = TrackingNo
--                  FROM CartonTrack WITH (NOLOCK)
--                  WHERE KeyName = @cNotes
--                     AND CarrierRef2 <> 'GET'
--                  ORDER BY RowRef
--                  
--                  -- Stamp track no used
--                  UPDATE CartonTrack SET 
--                     CarrierRef2 = 'GET', 
--                     LabelNo = @cCartonID
--                  WHERE RowRef = @nRowRef
--                  IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
--                  BEGIN
--                     SET @nErrNo = 118224
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTrackNoFail
--                     GOTO RollBackTran
--                  END 
--               END
--            END
--            
--            -- PackDetail
--            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID AND SKU = @cSKU)
--            BEGIN
--               -- Get next LabelLine
--               IF @nCartonNo = 0
--                  SET @cLabelLine = ''
--               ELSE
--                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
--                  FROM dbo.PackDetail (NOLOCK)
--                  WHERE Pickslipno = @cPickSlipNo
--                     AND CartonNo = @nCartonNo
--                     AND LabelNo = @cCartonID               
--
--               IF @cUpdatePackDetailDropID = '1' 
--                  SET @cPackDetailDropID = @cCartonID 
--               ELSE 
--                  SET @cPackDetailDropID = ''
--               
--               -- Insert PackDetail
--               INSERT INTO dbo.PackDetail
--                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
--               VALUES
--                  (@cPickSlipNo, @nCartonNo, @cCartonID, @cLabelLine, @cStorerKey, @cSKU, @nCartonQTY, @cPackDetailDropID, 
--                   'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118225
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
--                  GOTO RollBackTran
--               END     
--            END
--            ELSE
--            BEGIN
--               -- Update Packdetail
--               UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
--                  QTY = QTY + @nCartonQTY, 
--                  EditWho = 'rdt.' + SUSER_SNAME(), 
--                  EditDate = GETDATE(), 
--                  ArchiveCop = NULL
--               WHERE PickSlipNo = @cPickSlipNo
--                  AND CartonNo = @nCartonNo
--                  AND LabelNo = @cCartonID
--                  AND SKU = @cSKU
--               IF @@ERROR <> 0
--               BEGIN
--                  SET @nErrNo = 118226
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
--                  GOTO RollBackTran
--               END
--            END
--
--            IF @cAutoPackConfirm = '1'
--            BEGIN
--               -- No outstanding PickDetail
--               IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '5')
--               BEGIN
--                  SET @nPackQTY = 0
--                  SET @nPickQTY = 0
--                  SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
--                  SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
--      
--                  IF @nPackQTY = @nPickQTY
--                  BEGIN
--                     -- Pack confirm
--                     UPDATE PackHeader SET 
--                        Status = '9' 
--                     WHERE PickSlipNo = @cPickSlipNo
--                        AND Status <> '9'
--                     IF @@ERROR <> 0
--                     BEGIN
--                        SET @nErrNo = 118227
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
--                        GOTO RollBackTran
--                     END
--                  END
--               END
--            END
--         END
      END

      -- Update new carton
      IF @cType = 'CLOSECARTON' AND @cNewCartonID <> ''
      BEGIN
         
         
         SET @curLOG = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = @cCartonID
         ORDER BY RowRef   
         
         OPEN @curLOG
         FETCH NEXT FROM @curLOG INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Change carton on rdtPTLStationLog
            UPDATE rdt.rdtPTLStationLog SET
               CartonID = @cNewCartonID
            WHERE RowRef = @nRowRef 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 119773
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curLOG INTO @nRowRef
         END
      END
      
      -- Auto short all subsequence carton
      IF @cType = 'SHORTCARTON'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainCarton', @cStorerKey) = '1'
         BEGIN
            SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PTLKey, IPAddress, DevicePosition, ExpectedQTY
               FROM PTL.PTLTran WITH (NOLOCK)
               WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND DropID = @cScanID
                  AND SKU = @cSKU
                  AND Status <> '9'
      
            OPEN @curPTL
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get carton
               SELECT 
                  @cActCartonID = CartonID, 
                  @cOrderKey= OrderKey
               FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
               WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND IPAddress = @cIPAddress
                  AND Position = @cPosition
               
               -- Confirm PTLTran
               UPDATE PTL.PTLTran SET
                  Status = '9', 
                  QTY = 0, 
                  CaseID = @cActCartonID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 119774
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               
               -- Update PickDetail
               IF @cUpdatePickDetail = '1'
               BEGIN
                  -- Get PickDetail tally PTLTran
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.OrderKey = @cOrderKey
                     AND PD.DropID = @cScanID
                     AND PD.SKU = @cSKU
                     AND PD.Status <= '5'
                     AND PD.Status <> '4'
                     AND PD.CaseID = ''
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 119775
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM Orders O WITH (NOLOCK) 
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE O.OrderKey = @cOrderKey
                        AND PD.DropID = @cScanID
                        AND PD.SKU = @cSKU
                        AND PD.Status <= '5'
                        AND PD.Status <> '4'
                        AND PD.CaseID = ''
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE PickDetail SET
                        Status = '4', 
                        --CaseID = @cActCartonID, 
                        --DropID = @cActCartonID, 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 119776
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END
               
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY
            END
         END
      END

     -- EventLog - (cc01)
     EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', 
        @cUserID     = '',
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cOrderKey   = @cOrderKey,
        @cSKU        = @cSKU,
        @nQty        = @nQTY_PD

      --COMMIT TRAN rdt_PTLStation_Confirm
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_PTLStation_Confirm
END



GO