SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1867CfmToLoc01                                        */  
/* Copyright      : Maersk                                                    */  
/*                                                                            */  
/* Purpose: Confirm To Loc                                                    */
/*                  For HUSQ                                                  */
/* Called from: rdt_TM_Assist_ClusterPick_ConfirmToLoc                        */
/*                                                                            */
/* Date         Rev    Author    Purposes                                     */
/* 2024-10-10   1.0    JHU151    FCR-777 Created                              */ 
/* 2025-01-17   1.1    PPA374    Adding TOP 1 to @nCartonNo to avoid grey scren */
/* 2025-01-23   1.2    Dennis    Fix Serial No Issue                          */ 
/* 2025-02-11   1.3.0  NLT013    FCR-1872 Correct picked quantity             */ 
/* 2025-02-11   1.3.1  NLT013    FCR-1872 Correct LabelLine                   */ 
/* 2025-02-11   1.3.2  NLT013    FCR-1872 Be able to picking the remaining of */
/*                               an order which  was unassigned cart          */ 
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_1867CfmToLoc01] (  
    @nMobile         INT,  
    @nFunc           INT,  
    @cLangCode       NVARCHAR( 3),  
    @nStep           INT,  
    @nInputKey       INT,  
    @cFacility       NVARCHAR( 5),  
    @cStorerKey      NVARCHAR( 15),  
    @cTaskDetailKey  NVARCHAR( 10),  
    @cToLOC          NVARCHAR( 10),  
    @tConfirm        VARIABLETABLE READONLY,
    @nErrNo          INT           OUTPUT,  
    @cErrMsg         NVARCHAR(250) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cur         CURSOR
   DECLARE @curMV       CURSOR
   DECLARE @cGroupKey   NVARCHAR( 10)
   DECLARE @cCartID     NVARCHAR( 20)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQty        INT
   DECLARE @nTranCount  INT
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cConfirmToLocMoveInventory NVARCHAR( 1)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @nQTYAlloc   INT
   DECLARE @nQTYPick    INT
   DECLARE @cFromLot    NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10) 
   DECLARE @cLoadKey  NVARCHAR( 10)
   DECLARE @nCartonNo   INT
   DECLARE @nMaxCartonNo   INT
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cSuggestToLOC  NVARCHAR(10)
   DECLARE @cSerialNoKey   NVARCHAR( 10)
   DECLARE @cSerialNo      NVARCHAR( 30)
   DECLARE @cPickSerialNoKey   NVARCHAR( 10)
   DECLARE @cOrderLineNumber  NVARCHAR(5)
   DECLARE @cTransmitLogKey  NVARCHAR(10)
   DECLARE @fStdGrossWgt   FLOAT
   DECLARE @nPickedQty     INT
   DECLARE @nPackedQty     INT
   DECLARE @bSuccess       INT
   DECLARE @nLoopIndex         INT
   DECLARE @cPickDetailKey      NVARCHAR(10)
   DECLARE @nPickDetailQty      INT
   DECLARE @cNewTaskDetailKey   NVARCHAR(10)

   DECLARE @tTaskDetailPickDetail TABLE
   (
      id   INT IDENTITY(1,1),
      TaskDetailKey   NVARCHAR(10),
      PickDetailKey   NVARCHAR(10),
      PickDetailQty   INT
   )


   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @cConfirmToLocMoveInventory = rdt.rdtGetConfig( @nFunc, 'ConfirmToLocMoveInventory', @cStorerKey)
   
   SELECT TOP 1 
      @cGroupKey = Groupkey,
      @cCartID = DeviceID
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   ORDER BY 1
   
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN ConfirmToLoc -- For rollback or commit only our own transaction  

   SET @cur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT TaskDetailKey
   FROM dbo.TASKDETAIL WITH (NOLOCK)
   WHERE Groupkey = @cGroupKey 
   AND   DeviceID = @cCartID 
   AND   UserKey = @cUserName
   AND   [Status] = '5'
   ORDER BY 1
   OPEN @cur
   FETCH NEXT FROM @cur INTO @cTaskKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT 
         @cFromLOC = FromLOC, 
         @cSuggestToLOC = ToLoc, 
         @cSKU = Sku, 
         @cDropID = DropID, 
         @nQty = SUM( Qty)
      FROM dbo.TASKDETAIL WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskKey
      GROUP BY FromLOC, ToLoc, Sku, DropID
      
      IF @cSuggestToLOC <> @cToLoc
      BEGIN
         UPDATE dbo.TASKDETAIL
         SET ToLoc = @cToLoc
         WHERE TaskDetailKey = @cTaskKey 
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                      JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey) 
                      WHERE PD.DropID = @cDropID
                      AND   TD.Groupkey = @cGroupKey 
                      AND   DeviceID = @cCartID 
                      AND   TD.Status = '5'
                      AND   TD.TaskDetailKey = @cTaskKey
                      AND  (PD.Status = '4' OR PD.Status < @cPickConfirmStatus)
                      )
      BEGIN
         IF @cConfirmToLocMoveInventory = '1'
         BEGIN
            SET @curMV = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT LOT, ID, SUM( Qty)
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskKey
            AND   Status = @cPickConfirmStatus
            GROUP BY LOT, ID
            OPEN @curMV
            FETCH NEXT FROM @curMV INTO @cFromLot, @cFromID, @nQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @cPickConfirmStatus = '5'
               BEGIN
                  SET @nQTYAlloc = 0
                  SET @nQTYPick = @nQTY
               END
               ELSE
               BEGIN
                  SET @nQTYAlloc = @nQTY
                  SET @nQTYPick = 0
               END

               
               IF @nQTY > 0
               BEGIN

                  -- Move inventory
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT,
                     @cSourceType = 'rdt_1867CfmToLoc01',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cToLoc,
                     @cFromID     = @cFromID,
                     @cToID       = @cDropID,
                     @cSKU        = @cSKU,
                     @nQTY        = @nQTY,
                     @cFromLot    = @cFromLot,
                     @nQTYAlloc   = @nQTYAlloc,          
                     @nQTYPick    = @nQTYPick,
                     @cDropID     = @cDropID,
                     @nFunc       = @nFunc
      
                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END

               FETCH NEXT FROM @curMV INTO @cFromLot, @cFromID, @nQTY
            END
         END
      END
      
      FETCH NEXT FROM @cur INTO @cTaskKey
   END

   --Split TaskDetails if needed
   --INSERT INTO @tTaskDetailPickDetail (TaskDetailKey, PickDetailKey, PickDetailQty)
   --SELECT TD.TaskDetailKey, PKD.PickDetailKey, PKD.Qty
   --FROM dbo.TASKDETAIL TD WITH (NOLOCK)   
   --INNER JOIN dbo.PickDetail PKD WITH (NOLOCK)  
   --   ON TD.Storerkey = PKD.Storerkey AND TD.TaskDetailKey = PKD.TaskDetailKey
   --INNER JOIN dbo.PickDetail PKD1 WITH (NOLOCK)  
   --   ON PKD.Storerkey = PKD1.Storerkey AND PKD.TaskDetailKey = PKD1.TaskDetailKey
   --WHERE TD.Groupkey = @cGroupKey 
   --   AND TD.DeviceID = @cCartID 
   --   AND TD.UserKey = @cUserName
   --   AND TD.[Status] = '3' AND PKD.Status = '0'
   --   AND PKD1.Status = '5'

   --SET @nLoopIndex = -1

   --WHILE 1 = 1
   --BEGIN
   --   SELECT TOP 1
   --      @cPickDetailKey = PickDetailKey,
   --      @nPickDetailQty = PickDetailQty,
   --      @cTaskDetailKey = TaskDetailKey,
   --      @nLoopIndex = id
   --   FROM @tTaskDetailPickDetail
   --   WHERE id > @nLoopIndex

   --   IF @@ROWCOUNT = 0 
   --      BREAK

   --   EXECUTE dbo.nspg_getkey
   --      'TaskDetailKey'
   --      , 10
   --      , @cNewTaskDetailKey OUTPUT
   --      , @bSuccess OUTPUT
   --      , @nErrNo
   --      , @cErrMsg OUTPUT

   --      IF NOT @bSuccess = 1
   --      BEGIN
   --         SET @nErrNo = 227208
   --         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKeyFailed
   --         GOTO RollBackTran 
   --      END

   --   INSERT INTO dbo.TaskDetail
   --     (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,QTY,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
   --     ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
   --     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
   --     ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty,Groupkey,TrafficCop, DeviceID)
   --     SELECT  TOP 1
   --     @cNewTaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,@nPickDetailQty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
   --     ,ToID,Caseid,PickMethod,'3',StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
   --     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
   --     ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, @nPickDetailQty,GroupKey,NULL, DeviceID
   --     FROM dbo.TaskDetail WITH (NOLOCK)
   --     WHERE Taskdetailkey = @cTaskDetailKey
   --      AND Storerkey = @cStorerkey
                        
   --   IF @@ERROR <> 0
   --   BEGIN
   --      SET @nErrNo = 227209
   --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskFailed
   --      GOTO RollBackTran 
   --   END

   --   UPDATE dbo.PickDetail SET 
   --      TaskDetailKey = @cNewTaskDetailKey, 
   --      EditWho = @cUserName, 
   --      EditDate = GETDATE()
   --   WHERE PickDetailKey = @cPickDetailKey 
   --   AND Storerkey = @cStorerkey

   --   UPDATE TD WITH(ROWLOCK)
   --   SET SystemQty = PKD.Qty,
   --      Qty = PKD.Qty,
   --      TD.EditWho = SUSER_SNAME(),
   --      TD.EditDate = GETDATE(), 
   --      TD.EndTime = GETDATE()
   --   FROM dbo.TASKDETAIL TD   
   --   INNER JOIN dbo.PICKDETAIL PKD WITH(NOLOCK)
   --      ON TD.StorerKey = PKD.StorerKey AND TD.TaskDetailKey = PKD.TaskDetailKey
   --   WHERE TD.Taskdetailkey = @cTaskDetailKey
   --      AND TD.Storerkey = @cStorerkey
   --END

   --UPDATE TD WITH(ROWLOCK)
   --SET TD.Status = '5',
   --   TD.EditWho = SUSER_SNAME(),
   --   TD.EditDate = GETDATE(), 
   --   TD.EndTime = GETDATE()
   --FROM dbo.TASKDETAIL TD   
   --INNER JOIN dbo.PICKDETAIL PKD WITH(NOLOCK)
   --   ON TD.StorerKey = PKD.StorerKey AND TD.TaskDetailKey = PKD.TaskDetailKey
   --WHERE TD.Groupkey = @cGroupKey 
   --   AND TD.DeviceID = @cCartID 
   --   AND TD.UserKey = @cUserName
   --   AND TD.[Status] = '3' AND PKD.Status = '5'

   SET @cur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT TaskdetailKey,OrderKey,DropID,SKU,QTY
   FROM dbo.TASKDETAIL WITH (NOLOCK)   
   WHERE Groupkey = @cGroupKey 
   AND   DeviceID = @cCartID 
   AND   UserKey = @cUserName
   AND   [Status] = '5'
   ORDER BY OrderKey,Dropid
   OPEN @cur
   FETCH NEXT FROM @cur INTO @cTaskKey,@cOrderKey,@cDropID,@cSKU,@nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.TaskDetail SET 
         FinalLOC = @cToLoc,
         [Status] = '9',
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE(), 
         EndTime = GETDATE()
      WHERE TaskDetailKey = @cTaskKey 

      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 227201  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Confirm Fail  
         GOTO RollBackTran  
      END

      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                      WHERE TaskDetailKey = @cTaskKey
                      AND (Status = '4' 
                      --OR Status < @cPickConfirmStatus
                      )
                      )
      BEGIN
         UPDATE dbo.PickDetail SET 
            Status = '5', 
            EditWho = @cUserName, 
            EditDate = GETDATE()
         WHERE TaskDetailKey = @cTaskKey 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 227202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd CaseID Err 
            SET @cErrMsg = 'Upd Pick confirm' 
            GOTO RollBackTran  
         END         
      END
      
      

      -- Get PickHeader info  
      SELECT @cLoadKey = LoadKey
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

               
      DECLARE @cRoute    NVARCHAR( 10)
      DECLARE @cStatus   NVARCHAR( 10)
      DECLARE @cCartonGroup   NVARCHAR( 10)
      DECLARE @cConsigneeKey  NVARCHAR( 30)

      SELECT TOP 1
         @cPickSlipNo = PH.PickheaderKey,
         @cStatus = PH.Status,
         @cConsigneeKey = PH.ConsigneeKey,
         @cRoute = ORD.Route
      FROM dbo.PICKHEADER PH WITH (NOLOCK)
      INNER JOIN dbo.ORDERS ORD WITH (NOLOCK) ON PH.Storerkey = ORD.StorerKey AND PH.OrderKey = ORD.OrderKey
      WHERE PH.OrderKey = @cOrderKey 

      -- PackHeader
      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE PickslipNo = @cPickslipNo
                   AND OrderKey = @cOrderKey)
      BEGIN         

         SELECT @cCartonGroup = CartonGroup
         FROM Storer WITH(NOLOCK)
         WHERE Storerkey = @cStorerKey
         
         INSERT INTO dbo.PackHeader
         (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey,
          Status, TTLCNTS, CtnCnt1, CartonGroup)
         VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey, @cRoute, @cConsigneeKey,
                 @cStatus, 1, 1, @cCartonGroup)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 227203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END

         
            
      END
      ELSE
      BEGIN
         UPDATE dbo.PackHeader
            SET status = @cStatus
         WHERE Pickslipno = @cPickslipNo
           AND StorerKey = @cStorerkey
           AND OrderKey = @cOrderKey
           AND status <> @cStatus
      END

      SET @cLabelLine = ''
      SET @nMaxCartonNo = 0

      SELECT TOP 1
         @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) AS NVARCHAR( 5)), 5) ,
         @nMaxCartonNo = MAX(CartonNo)
      FROM dbo.PackDetail (NOLOCK)
      WHERE Pickslipno = @cPickSlipNo
         AND LabelNo = @cDropID
         AND Storerkey = @cStorerKey

      IF @cLabelLine = '00000'
      BEGIN
         SELECT TOP 1
            @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) ,
            @nMaxCartonNo = MAX(CartonNo)
         FROM dbo.PackDetail (NOLOCK)
         WHERE Pickslipno = @cPickSlipNo
            AND Storerkey = @cStorerKey
      END
      
      IF @cLabelLine = ''
         SET @cLabelLine = '000001'
      IF ISNULL(@nMaxCartonNo,0) = 0
      BEGIN
         SET @nMaxCartonNo = 0
      END
      
      IF NOT EXISTS(SELECT 1 FROM dbo.PackDetail WITH(NOLOCK)
                     WHERE PickslipNo = @cPickslipNo
                      AND StorerKey = @cStorerKey
                      --AND Sku = @cSKU
                      AND DropID = @cDropID)
      BEGIN
         
         SET @nMaxCartonNo = @nMaxCartonNo + 1
         SET @nCartonNo = @nMaxCartonNo
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, 
            LabelLine,
            StorerKey, SKU, QTY, 
            DropID, RefNo, RefNo2,
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cDropID, 
            @cLabelLine,
            @cStorerKey, @cSKU, @nQTY, 
            @cDropID, '', @cDropID,
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 227204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
            GOTO RollBackTran
         END

         SELECT @fStdGrossWgt = @nQty * StdGrossWgt
         FROM SKU WITH(NOLOCK)
         WHERE SKU = @csku
         AND StorerKey = @cStorerKey

         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Weight, Cube, QTY, CartonType, RefNo, Length, Width, Height, UCCNo, TrackingNo)
            SELECT TOP 1 
               @cPickSlipNo,
               @nCartonNo,
               @fStdGrossWgt,
               0,
               @nQTY,
               '',
               @cDropID,
               0,
               0,
               0,
               '', --UCC
               '' --TrackingNo
         END
      END
      ELSE IF NOT EXISTS(SELECT 1 FROM dbo.PackDetail WITH(NOLOCK)
                     WHERE PickslipNo = @cPickslipNo
                      AND StorerKey = @cStorerKey
                      AND Sku = @cSKU
                      AND DropID = @cDropID)
      BEGIN
         SELECT TOP 1 @nCartonNo = CartonNo,   --PPA374 ADDED TOP 1 15/01/2025
            @cLabelLine = RIGHT( '00000' + CONVERT(NVARCHAR(5), @cLabelLine + 1  ), 5)
         FROM dbo.PackDetail WITH(NOLOCK)
            WHERE PickslipNo = @cPickslipNo
               AND StorerKey = @cStorerKey
               AND DropID = @cDropID
               
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, 
            LabelLine,
            StorerKey, SKU, QTY, 
            DropID, RefNo, RefNo2,
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cDropID, 
            @cLabelLine,
            @cStorerKey, @cSKU, @nQTY, 
            @cDropID, '', @cDropID,
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 227205
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
            GOTO RollBackTran
         END

         SELECT @fStdGrossWgt = @nQty * StdGrossWgt
         FROM SKU WITH(NOLOCK)
         WHERE SKU = @csku
         AND StorerKey = @cStorerKey

         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Weight, Cube, QTY, CartonType, RefNo, Length, Width, Height, UCCNo, TrackingNo)
            SELECT TOP 1 
               @cPickSlipNo,
               @nCartonNo,
               @fStdGrossWgt,
               0,
               @nQTY,
               '',
               @cDropID,
               0,
               0,
               0,
               '', --UCC
               '' --TrackingNo
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackDetail
         SET Qty = Qty + @nQty
         WHERE PickslipNo = @cPickslipNo
         AND StorerKey = @cStorerKey
         AND Sku = @cSKU
         AND LabelNo = @cDropID 

         UPDATE dbo.PackInfo
         SET QTY = Qty + @nQty,
             Weight = Weight + @fStdGrossWgt
         WHERE PickslipNo = @cPickslipNo
         AND RefNo = @cDropID
      END

      --
      BEGIN
         INSERT INTO PackSerialNo 
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
         SELECT
            @cPickSlipNo,
            @nCartonNo,
            @cDropID,
            @cLabelLine,
            @cStorerkey,
            @cSKU,
            PSN.SerialNo,
            PSN.QTY
         FROM dbo.PICKDETAIL PD WITH(NOLOCK)
         INNER JOIN PickSerialNo PSN WITH(NOLOCK) ON PD.PickDetailKey = PSN.PickDetailKey
               AND PD.Sku = PSN.Sku
         WHERE TaskDetailKey = @cTaskKey
         AND PSN.SKU = @cSku
         AND NOT EXISTS(SELECT 1 FROM PackSerialNo WITH(NOLOCK)
                           WHERE SerialNo = PSN.SerialNo
                           AND sku = PSN.sku
                           AND Storerkey = @cStorerKey
                           AND labelNo = @cDropID)

         SET @cPickSerialNoKey = ''
         WHILE (1=1)
         BEGIN
            SELECT   top 1  
               @cPickSerialNoKey = PSN.PickSerialNoKey,
               @cSerialNo = PSN.SerialNo,
               @cOrderLineNumber = PD.OrderLineNumber
            FROM dbo.PICKDETAIL PD WITH(NOLOCK)
            INNER JOIN PickSerialNo PSN WITH(NOLOCK) ON PD.PickDetailKey = PSN.PickDetailKey
                  AND PD.Sku = PSN.Sku
            WHERE TaskDetailKey = @cTaskKey
            AND PSN.SKU = @cSku
            AND PSN.PickSerialNoKey > @cPickSerialNoKey
            ORDER BY PSN.PickSerialNoKey ASC

            IF @@ROWCOUNT = 0 
            BEGIN
               SET @cPickSerialNoKey = ''
               BREAK
            END
            
            IF NOT EXISTS(SELECT 1 FROM SerialNo WITH(NOLOCK)
                           WHERE SerialNo = @cSerialNo
                           AND sku = @cSKU
                           AND Storerkey = @cStorerKey)
            BEGIN
               -- Get SerialNoKey
               EXECUTE nspg_getkey
                  'SerialNo'
                  ,10
                  ,@cSerialNoKey  OUTPUT
                  ,@bSuccess      OUTPUT
                  ,@nErrNo        OUTPUT
                  ,@cErrMsg       OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 227273
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NSQL94213: GetKey fail. (rdt_1867CfmToLoc01)
                  GOTO RollBackTran
               END

               -- Insert SerialNo
               INSERT INTO dbo.SerialNo (SerialNoKey, StorerKey, SKU, SerialNo, QTY, Status, OrderKey, OrderLineNumber)
               SELECT 
                  @cSerialNoKey,
                  @cStorerkey,
                  @cSKU,            
                  @cSerialNo,
                  1,
                  '0',
                  @cOrderkey,
                  @cOrderLineNumber

                  /**
               FROM dbo.PICKDETAIL PD WITH(NOLOCK)
               INNER JOIN PickSerialNo PSN WITH(NOLOCK) ON PD.PickDetailKey = PSN.PickDetailKey
                     AND PD.Sku = PSN.Sku
               WHERE TaskDetailKey = @cTaskKey
               AND PSN.SKU = @cSku
               AND PSN.PickSerialNoKey = @cPickSerialNoKey
               AND PSN.SerialNo = @cSerialNo
               AND NOT EXISTS(SELECT 1 FROM SerialNo WITH(NOLOCK)
                                 WHERE SerialNo = PSN.SerialNo
                                 AND sku = PSN.sku
                                 AND Storerkey = @cStorerKey)
               **/
            END
            
         END

      END

      SELECT @nPickedQty = SUM(Qty)
      FROM pickdetail PD WITH(NOLOCK)
      WHERE storerKey = @cStorerkey
      AND OrderKey =  @cOrderKey
         AND STATUS NOT IN ('4', '9')

      SELECT @nPackedQty = SUM(Qty)
      FROM PackHeader PH WITH(NOLOCK)
      INNER JOIN PackDetail PD WITH(NOLOCK) 
      ON PH.PickslipNo = PD.Pickslipno 
      AND PH.storerkey = PD.storerkey
      WHERE PH.storerkey = @cStorerkey
      AND PH.OrderKey = @cOrderKey
      

      IF @nPickedQty = @nPackedQty
      Begin
         UPDATE PackHeader
         SET status = '9'
         WHERE OrderKey = @cOrderKey
         AND storerkey = @cStorerKey
         AND status <> '9'


         -- method 1
         -- insert transmitlog2
         IF EXISTS(SELECT 1
                   FROM ORDERS ORD WITH(NOLOCK)
                   WHERE storerkey = @cstorerkey
                   AND Orderkey = @cOrderkey
                   AND UserDefine10 IN (SELECT  short 
                                       FROM CodeLKUP WITH(NOLOCK) 
                                       WHERE LISTNAME = 'HUSQPKTYPE' 
                                       AND Code2 = 'UnderSized' 
                                       AND StorerKey = @cStorerKey)
                   )
         BEGIN
            
            EXECUTE nspg_GetKey 'TransmitLogKey2'    
                        , 10    
                        , @cTransmitLogKey OUTPUT    
                        , @bSuccess OUTPUT    
                        , @nErrNo OUTPUT    
                        , @cErrMsg OUTPUT 

            IF @bSuccess <> 1   
            BEGIN 
               ROLLBACK TRAN        
               SET @nErrNo = 227206
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey TransmitLogKey2 Fail             
               GOTO RollBackTran     
            END

                     
            INSERT dbo.TRANSMITLOG2   (TransmitLogKey, Tablename, Key1, Key2, Key3, TransmitFlag  ) 
            VALUES ( @cTransmitLogKey, 'WSCRSOEDELIV', @cOrderKey, '', @cStorerKey , '0' )

            SET @nErrNo = @@ERROR        
            IF @nErrNo <> 0        
            BEGIN        
               ROLLBACK TRAN        
               SET @nErrNo = 227207    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERT TRANSMITLOG2 Fail           
               GOTO RollBackTran       
            END                                                                
         END
      END



      IF NOT EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cDropID,'','',0,'N',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@cLoadKey,@cPickslipNo,'','','','','')
      END
      /**
      ELSE
      BEGIN
         UPDATE DropID
         SET Loadkey = @cLoadKey,
             PickSlipNo = @cPickslipNo
         WHERE DropID = @cDropID

      END
      **/
      FETCH NEXT FROM @cur INTO @cTaskKey,@cOrderKey,@cDropID,@cSKU,@nQTY
   END
   
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN ConfirmToLoc -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
      IF @nErrNo <> 0
      INSERT INTO TRACEINFO (TraceName, TimeIn, Col1, Col2, Col3, Col4) VALUES
      ('rdt_1867CfmToLoc01', GETDATE(), @cFromLOC, @cToLoc, @cSKU, @nQTY)
      
      
Fail:
END  

GO