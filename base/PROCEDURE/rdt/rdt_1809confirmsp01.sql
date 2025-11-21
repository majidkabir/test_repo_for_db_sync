SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1809ConfirmSP01                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_TM_Tote_Picking                                  */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-12-30 1.0  ChewKP   SOS#358813 Created                          */
/************************************************************************/
CREATE PROC [RDT].[rdt_1809ConfirmSP01] (
     @nMobile          INT
   , @nFunc            INT
   , @cStorerKey       NVARCHAR(15)
   , @cUserName        NVARCHAR(15)
   , @cFacility        NVARCHAR(5)
   , @cTaskDetailKey   NVARCHAR(10)
   , @cLoadKey         NVARCHAR(10)
   , @cSKU             NVARCHAR(20)
   , @cAltSKU          NVARCHAR(20)
   , @cLOC             NVARCHAR(10)
   , @cToLOC           NVARCHAR(10)
   , @cID              NVARCHAR(18)
   , @cToteNo          NVARCHAR(18)
   , @nPickQty         INT
   , @cStatus          NVARCHAR(1) -- 4 = PickInProgress ; 5 = Picked
   , @cLangCode        NVARCHAR(3)
   , @nTotalQty        INT
   , @nErrNo           INT          OUTPUT
   , @cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
   , @cPickMethod      NVARCHAR(10)=''
   , @cNTaskDetailkey  NVARCHAR(10)=''
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success             INT
         , @n_err                 INT
         , @c_errmsg              NVARCHAR(250)
         , @nTranCount            INT

   DECLARE @cOrderKey             NVARCHAR(10)
         , @cPickSlipno           NVARCHAR(10)
         , @cPickDetailKey        NVARCHAR(10)
         , @nQTY_PD               INT
         , @cLOT                  NVARCHAR(10)
         , @cNewPickDetailKey     NVARCHAR(10)
         , @cPDOrderkey           NVARCHAR(10)
         , @cPickDetailKeySingle  NVARCHAR(10)
         , @cTMAutoShortPick      NVARCHAR(1)
         , @cActionFlag           NVARCHAR(1)
         , @cTaskType             NVARCHAR(10)
         , @cAreaKey              NVARCHAR(10)
         , @cShortPick            NVARCHAR(1)
         , @nCountTask            INT
         , @cNewTaskDetailkey     NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN TM_Picking_ConfirmTask



   -- (ChewKP04)
   UPDATE DropID
   SET [Status] = '5'
   WHERE Dropid   = @cToteNo
   AND   [Status] ='0'
   AND   Loadkey  = CASE WHEN ISNULL(RTRIM(@cLoadkey), '') <> '' THEN @cLoadkey ELSE DropID.LoadKey END

   IF @cStatus='5'
   BEGIN

      DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
                ,PD.QTY
                ,PD.LOT
                ,PD.Orderkey
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON  (PD.OrderKey=O.OrderKey)
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON  (TD.TaskDetailKey=PD.TaskDetailKey)
          WHERE  O.LoadKey = @cLoadKey
          AND    PD.StorerKey = @cStorerKey
          AND    PD.LOC = @cLOC
          AND    PD.Status = '0'
          AND    PD.SKU = @cSKU
          AND    TD.TaskDetailkey = @cTaskDetailKey
          ORDER BY PD.PickDetailKey

      OPEN CursorPickDetail
      FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cLOT, @cPDOrderkey
      WHILE @@FETCH_STATUS<>-1
      BEGIN
         


          IF @nQTY_PD=@nPickQty
          BEGIN
             -- Confirm PickDetail
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    DropID = @cToteNo
                   ,STATUS = @cStatus
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 95551
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                 GOTO RollBackTran
             END

             -- EventLog -- SOS# 206805
             EXEC RDT.rdt_STD_EventLog
                  @cActionType='3' -- Picking
                 ,@cUserID=@cUserName
                 ,@nMobileNo=@nMobile
                 ,@nFunctionID=@nFunc
                 ,@cFacility=@cFacility
                 ,@cStorerKey=@cStorerKey
                 ,@cLocation=@cLoc
                 ,@cToLocation=@cToLOC
                 ,@cID=@cID -- Sugg FromID
                 ,@cToID=@cToteNo -- DropID
                 ,@cSKU=@cSKU
                 ,@nQTY=@nQTY_PD
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-01'

          END
          ELSE IF @nPickQty > @nQTY_PD
          BEGIN
             -- Confirm PickDetail
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    DropID = @cToteNo
                   ,STATUS = '5'
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 95552
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                 GOTO RollBackTran
             END

             -- EventLog -- SOS# 206805
             EXEC RDT.rdt_STD_EventLog
                  @cActionType='3' -- Picking
                 ,@cUserID=@cUserName
                 ,@nMobileNo=@nMobile
                 ,@nFunctionID=@nFunc
                 ,@cFacility=@cFacility
                 ,@cStorerKey=@cStorerKey
                 ,@cLocation=@cLoc
                 ,@cToLocation=@cToLOC
                 ,@cID=@cID -- Sugg FromID
                 ,@cToID=@cToteNo -- DropID
                 ,@cSKU=@cSKU
                 ,@nQTY=@nQTY_PD
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-02'

          END -- IF @nPickQty > @nQTY_PD
          ELSE IF @nPickQty < @nQTY_PD AND @nPickQty > 0
          BEGIN
             EXECUTE dbo.nspg_GetKey
                      'PICKDETAILKEY',
                      10 ,
                      @cNewPickDetailKey OUTPUT,
                      @b_success         OUTPUT,
                      @n_err             OUTPUT,
                      @c_errmsg          OUTPUT

             IF @b_success<>1
             BEGIN
                 SET @nErrNo = 95553
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'
                 GOTO RollBackTran
             END

             -- Create a new PickDetail to hold the balance
             INSERT INTO dbo.PICKDETAIL
               (
                 CaseID                  ,PickHeaderKey   ,OrderKey
                ,OrderLineNumber         ,LOT             ,StorerKey
                ,SKU                     ,AltSKU          ,UOM
                ,UOMQTY                  ,QTYMoved        ,STATUS
                ,DropID                  ,LOC             ,ID
                ,PackKey                 ,UpdateSource    ,CartonGroup
                ,CartonType              ,ToLoc           ,DoReplenish
                ,ReplenishZone           ,DoCartonize     ,PickMethod
                ,WaveKey                 ,EffectiveDate   ,ArchiveCop
                ,ShipFlag                ,PickSlipNo      ,PickDetailKey
                ,QTY                     ,TrafficCop      ,OptimizeCop
                ,TaskDetailkey
               )
             SELECT CaseID               ,PickHeaderKey   ,OrderKey
                   ,OrderLineNumber      ,Lot             ,StorerKey
                   ,SKU                  ,AltSku          ,UOM
                   ,UOMQTY               ,QTYMoved        ,'0'
                   ,''                   ,LOC             ,ID
                   ,PackKey              ,UpdateSource    ,CartonGroup
                   ,CartonType           ,ToLoc           ,DoReplenish
                   ,ReplenishZone        ,DoCartonize     ,PickMethod
                   ,WaveKey              ,EffectiveDate   ,ArchiveCop
                   ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey
                   ,@nQTY_PD - @nPickQty ,NULL            ,'1'  --OptimizeCop,
                   ,@cNTaskDetailkey
             FROM   dbo.PickDetail WITH (NOLOCK)
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 95554
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                 GOTO RollBackTran
             END

             -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
             -- Change orginal PickDetail with exact QTY (with TrafficCop)
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    QTY = @nPickQty
                   ,Trafficcop = NULL
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 95555
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                 GOTO RollBackTran
             END

             -- Confirm orginal PickDetail with exact QTY
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    DropID = @cToteNo
                   ,STATUS = @cStatus
             WHERE  PickDetailKey = @cPickDetailKey
             IF @@ERROR <> 0
             BEGIN                      
                 SET @nErrNo = 95556
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                 GOTO RollBackTran
             END

             -- EventLog -- SOS# 206805
             EXEC RDT.rdt_STD_EventLog
                  @cActionType='3' -- Picking
                 ,@cUserID=@cUserName
                 ,@nMobileNo=@nMobile
                 ,@nFunctionID=@nFunc
                 ,@cFacility=@cFacility
                 ,@cStorerKey=@cStorerKey
                 ,@cLocation=@cLoc
                 ,@cToLocation=@cToLOC
                 ,@cID=@cID -- Sugg FromID
                 ,@cToID=@cToteNo -- DropID
                 ,@cSKU=@cSKU
                 ,@nQTY=@nQTY_PD
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-03'

          END  -- IF @nPickQty < @nQTY_PD AND @nPickQty > 0

          IF @nPickQty > 0
          BEGIN
              SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty
              IF @nPickQty < 0 		
              		SET @nPickQty = 0	
          END

     

          IF @nPickQty = 0 AND @cPickMethod = 'SINGLES' AND ISNULL(RTRIM(@cNTaskDetailkey),'') <> '' 
          BEGIN
              DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PD.PickDetailKey
                  FROM   dbo.PickDetail PD WITH (NOLOCK)
                         JOIN dbo.Orders O WITH (NOLOCK)
                              ON  (PD.OrderKey=O.OrderKey)
                         INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                              ON  (TD.TaskDetailKey=PD.TaskDetailKey)
                  WHERE  O.LoadKey = @cLoadKey
                  AND    PD.StorerKey = @cStorerKey
                  AND    PD.LOC = @cLOC
                  AND    PD.Status = '0'
                  AND    PD.SKU = @cSKU
                  AND    PD.TaskDetailKey = @cTaskDetailKey 
                  ORDER BY PD.PickDetailKey

              OPEN CursorPickDetailSingle
              FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              WHILE @@FETCH_STATUS<>-1
              BEGIN
                 IF ISNULL(@cNTaskDetailkey,'') = ''
                 BEGIN
                     SET @nErrNo = 95557
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'SEE_SUPERVISOR'
                     GOTO RollBackTran
                 END

                 UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET   TaskDetailkey = @cNTaskDetailkey
                       ,Trafficcop = NULL
                 WHERE  Pickdetailkey = @cPickDetailKeySingle
                 AND    TaskDetailKey = @cTaskDetailKey -- Old TaskDetailKey (SHONG03)

                 FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              END
              CLOSE CursorPickDetailSingle
              DEALLOCATE CursorPickDetailSingle

              BREAK
          END
          ELSE
          BEGIN
             IF @nPickQTy = 0 AND ISNULL(RTRIM(@cNTaskDetailkey),'') <> ''
             BEGIN
                DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                    SELECT PD.PickDetailKey
                    FROM   dbo.PickDetail PD WITH (NOLOCK)
                    JOIN dbo.Orders O WITH (NOLOCK) ON  (PD.OrderKey=O.OrderKey)
                    INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON  (TD.TaskDetailKey=PD.TaskDetailKey)
                    WHERE  O.LoadKey = @cLoadKey
                    AND    PD.StorerKey = @cStorerKey
                    AND    PD.LOC = @cLOC
                    AND    PD.Status = '0'
                    AND    PD.SKU = @cSKU
                    AND    TD.TaskDetailkey = @cTaskDetailKey
                    ORDER BY PD.PickDetailKey

                OPEN CursorPickDetailSingle
                FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                WHILE @@FETCH_STATUS<>-1
                BEGIN
                    IF ISNULL(@cNTaskDetailkey,'') = ''
                    BEGIN
                       SET @nErrNo = 95558
                       SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'SEE_SUPERVISOR'
                       GOTO RollBackTran
                    END

                    UPDATE dbo.PickDetail WITH (ROWLOCK)
                    SET    TaskDetailkey = @cNTaskDetailkey
                          ,Trafficcop = NULL
                    WHERE  Pickdetailkey = @cPickDetailKeySingle

                    FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                END
                CLOSE CursorPickDetailSingle
                DEALLOCATE CursorPickDetailSingle

                BREAK
             END
          END

          FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cLOT, @cPDOrderkey
       END -- While Loop for PickDetail Key
       CLOSE CursorPickDetail
       DEALLOCATE CursorPickDetail
   END --  @cStatus = '5'

   -- (ChewKP01)
   SET @cTMAutoShortPick = ''
   SET @cTMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)

   IF @cTMAutoShortPick = '1'
   BEGIN
      IF @cStatus = '4'
         AND @cPickMethod = 'PIECE'
         AND ISNULL(RTRIM(@cLoc),'') = ''
      BEGIN
         IF @nPickQty = 0
         BEGIN
            DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT PD.PickDetailKey
                FROM   dbo.PickDetail PD WITH (NOLOCK)
                       JOIN dbo.Orders O WITH (NOLOCK)
                            ON  (PD.OrderKey=O.OrderKey)
                       INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                            ON  (TD.TaskDetailKey=PD.TaskDetailKey)
                WHERE  O.LoadKey = @cLoadKey
                AND    PD.StorerKey = @cStorerKey
                AND    PD.Status = '0'
                AND    TD.TaskDetailkey = @cTaskDetailKey
                ORDER BY PD.PickDetailKey

            OPEN CursorPickDetailSingle
            FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    STATUS = '4', EditWho=sUser_sName(), EditDate=GETDATE()
                  --, TrafficCop=NULL --SOS# 202596
                    , DropID  = ''-- @cToteNo
                    , Qty = 0         --SOS# 202596
               WHERE  Pickdetailkey = @cPickDetailKeySingle

               FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
            END
            CLOSE CursorPickDetailSingle
            DEALLOCATE CursorPickDetailSingle
         END
         -- EventLog -- SOS# 206805
         EXEC RDT.rdt_STD_EventLog
              @cActionType='3' -- Picking
             ,@cUserID=@cUserName
             ,@nMobileNo=@nMobile
             ,@nFunctionID=@nFunc
             ,@cFacility=@cFacility
             ,@cStorerKey=@cStorerKey
             ,@cLocation=@cLoc
             ,@cToLocation=@cToLOC
             ,@cID=@cID -- Sugg FromID
             ,@cToID=@cToteNo -- DropID
             ,@cSKU=@cSKU
             ,@nQTY=@nQTY_PD
             ,@cRefNo1=@cLoadKey
             ,@cRefNo2=@cTaskDetailKey
             ,@cRefNo3=@cPickMethod
             ,@cRefNo4='CFM-04'
      END

      IF @cStatus = '4'
         AND @cPickMethod = 'PIECE'
         AND ISNULL(RTRIM(@cLoc),'') <> ''
         AND ISNULL(RTRIM(@cSKU),'') <> ''
      BEGIN
         DECLARE CursorPickDetailShort  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
               ,PD.QTY
               ,PD.LOT
         FROM   dbo.PickDetail PD WITH (NOLOCK)
                JOIN dbo.Orders O WITH (NOLOCK)
                     ON  (PD.OrderKey=O.OrderKey)
                INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                     ON  (TD.TaskDetailKey=PD.TaskDetailKey)
         WHERE  O.LoadKey = @cLoadKey
         AND    PD.StorerKey = @cStorerKey
         AND    PD.LOC = @cLOC
         AND    PD.Status = '0'
         AND    PD.SKU = @cSKU
         AND    TD.TaskDetailkey = @cTaskDetailKey
         ORDER BY
                PD.PickDetailKey

         OPEN CursorPickDetailShort
         FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Exact match
            IF @nQTY_PD = @nPickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 95559
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                   GOTO RollBackTran
               END

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                    @cActionType='3' -- Picking
                   ,@cUserID=@cUserName
                   ,@nMobileNo=@nMobile
                   ,@nFunctionID=@nFunc
                   ,@cFacility=@cFacility
                   ,@cStorerKey=@cStorerKey
                   ,@cLocation=@cLoc
                   ,@cToLocation=@cToLOC
                   ,@cID=@cID -- Sugg FromID
                   ,@cToID=@cToteNo -- DropID
                   ,@cSKU=@cSKU
                   ,@nQTY=@nQTY_PD
                   ,@cRefNo1=@cLoadKey
                   ,@cRefNo2=@cTaskDetailKey
                   ,@cRefNo3=@cPickMethod
                   ,@cRefNo4='CFM-05'
            END -- IF @nQTY_PD = @nPickQty
            ELSE
            IF @nPickQty > @nQTY_PD
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 95560
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                   GOTO RollBackTran
               END

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                    @cActionType='3' -- Picking
                   ,@cUserID=@cUserName
                   ,@nMobileNo=@nMobile
                   ,@nFunctionID=@nFunc
                   ,@cFacility=@cFacility
                   ,@cStorerKey=@cStorerKey
                   ,@cLocation=@cLoc
                   ,@cToLocation=@cToLOC
                   ,@cID=@cID -- Sugg FromID
                   ,@cToID=@cToteNo -- DropID
                   ,@cSKU=@cSKU
                   ,@nQTY=@nQTY_PD
                   ,@cRefNo1=@cLoadKey
                   ,@cRefNo2=@cTaskDetailKey
                   ,@cRefNo3=@cPickMethod
                   ,@cRefNo4='CFM-06'
           END-- PickDetail have more, need to split
           ELSE
           IF @nQTY_PD > @nPickQty AND @nPickQty > 0
           BEGIN
              -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
              -- just have to update the pickdetail.qty = short pick qty
              -- Get new PickDetailkey

              EXECUTE dbo.nspg_GetKey
                       'PICKDETAILKEY',
                       10 ,
                       @cNewPickDetailKey OUTPUT,
                       @b_success         OUTPUT,
                       @n_err             OUTPUT,
                       @c_errmsg          OUTPUT

              IF @b_success <> 1
              BEGIN
                 SET @nErrNo = 95561
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'
                 GOTO RollBackTran
              END

              -- Create a new PickDetail to hold the balance
              INSERT INTO dbo.PICKDETAIL
                (
                  CaseID                ,PickHeaderKey    ,OrderKey
                 ,OrderLineNumber       ,LOT              ,StorerKey
                 ,SKU                   ,AltSKU           ,UOM
                 ,UOMQTY                ,QTYMoved         ,STATUS
                 ,DropID                ,LOC              ,ID
                 ,PackKey               ,UpdateSource     ,CartonGroup
                 ,CartonType            ,ToLoc            ,DoReplenish
                 ,ReplenishZone         ,DoCartonize      ,PickMethod
                 ,WaveKey               ,EffectiveDate    ,ArchiveCop
                 ,ShipFlag              ,PickSlipNo       ,PickDetailKey
                 ,QTY                   ,TrafficCop       ,OptimizeCop
                 ,TaskDetailkey
                )
              SELECT CaseID             ,PickHeaderKey    ,OrderKey
                     ,OrderLineNumber    ,Lot              ,StorerKey
                     ,SKU                ,AltSku           ,UOM
                     ,UOMQTY             ,QTYMoved         ,'5'
                     ,DropID             ,LOC              ,ID
                     ,PackKey            ,UpdateSource     ,CartonGroup
                     ,CartonType         ,ToLoc            ,DoReplenish
                     ,ReplenishZone      ,DoCartonize      ,PickMethod
                     ,WaveKey            ,EffectiveDate    ,ArchiveCop
                     ,ShipFlag           ,PickSlipNo       ,@cNewPickDetailKey
                     ,0                  ,NULL             ,'1'
                     ,@cTaskDetailKey
              FROM   dbo.PickDetail WITH (NOLOCK)
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 95562
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
              END

              -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
              -- Change orginal PickDetail with exact QTY (with TrafficCop)
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    QTY = @nPickQty
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 95563
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
              END

              -- Confirm orginal PickDetail with exact QTY
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    DropID = @cToteNo
                    ,STATUS = '5'
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 95564
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
              END

              -- EventLog
              EXEC RDT.rdt_STD_EventLog
                   @cActionType='3' -- Picking
                  ,@cUserID=@cUserName
                  ,@nMobileNo=@nMobile
                  ,@nFunctionID=@nFunc
                  ,@cFacility=@cFacility
                  ,@cStorerKey=@cStorerKey
                  ,@cLocation=@cLoc
                  ,@cToLocation=@cToLOC
                  ,@cID=@cID -- Sugg FromID
                  ,@cToID=@cToteNo -- DropID
                  ,@cSKU=@cSKU
                  ,@nQTY=@nQTY_PD
                  ,@cRefNo1=@cLoadKey
                  ,@cRefNo2=@cTaskDetailKey
                  ,@cRefNo3=@cPickMethod
                  ,@cRefNo4='CFM-07'
           END

           IF @nPickQty > 0
           BEGIN
               SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty
           END

           IF @nPickQty = 0 AND @cPickMethod = 'SINGLES'
           BEGIN
              DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PD.PickDetailKey
                  FROM   dbo.PickDetail PD WITH (NOLOCK)
                         JOIN dbo.Orders O WITH (NOLOCK)
                              ON  (PD.OrderKey=O.OrderKey)
                         INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                              ON  (TD.TaskDetailKey=PD.TaskDetailKey)
                  WHERE  O.LoadKey = @cLoadKey
                  AND    PD.StorerKey = @cStorerKey
                  AND    PD.LOC = @cLOC
                  AND    PD.Status = '0'
                  AND    PD.SKU = @cSKU
                  ORDER BY PD.PickDetailKey

              OPEN CursorPickDetailSingle
              FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              WHILE @@FETCH_STATUS <> -1
              BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET    STATUS = '4',  DropID = '' --@cToteNo
                       , EditWho = sUser_sName(), EditDate = GETDATE()  , TrafficCop = NULL
                  WHERE  Pickdetailkey = @cPickDetailKeySingle

                  FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              END
              CLOSE CursorPickDetailSingle
              DEALLOCATE CursorPickDetailSingle

              EXEC RDT.rdt_STD_EventLog
                    @cActionType='3' -- Picking
                   ,@cUserID=@cUserName
                   ,@nMobileNo=@nMobile
                   ,@nFunctionID=@nFunc
                   ,@cFacility=@cFacility
                   ,@cStorerKey=@cStorerKey
                   ,@cLocation=@cLoc
                   ,@cToLocation=@cToLOC
                   ,@cID=@cID -- Sugg FromID
                   ,@cToID=@cToteNo -- DropID
                   ,@cSKU=@cSKU
                   ,@nQTY=@nQTY_PD
                   ,@cRefNo1=@cLoadKey
                   ,@cRefNo2=@cTaskDetailKey
                   ,@cRefNo3=@cPickMethod
                   ,@cRefNo4='CFM-08'

              BREAK
           END
           ELSE
           BEGIN
              IF @nPickQty = 0
              BEGIN
                 DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PD.PickDetailKey
                     FROM   dbo.PickDetail PD WITH (NOLOCK)
                            JOIN dbo.Orders O WITH (NOLOCK)
                                 ON  (PD.OrderKey=O.OrderKey)
                            INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                                 ON  (TD.TaskDetailKey=PD.TaskDetailKey)
                     WHERE  O.LoadKey = @cLoadKey
                     AND    PD.StorerKey = @cStorerKey
                     AND    PD.LOC = @cLOC
                     AND    PD.Status = '0'
                     AND    PD.SKU = @cSKU
                     AND    TD.TaskDetailkey = @cTaskDetailKey
                     ORDER BY
                            PD.PickDetailKey

                 OPEN CursorPickDetailSingle
                 FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                 WHILE @@FETCH_STATUS <> -1
                 BEGIN
                     UPDATE dbo.PickDetail WITH (ROWLOCK)
                     SET    STATUS = '4', EditWho = sUser_sName(), EditDate = GETDATE()
                        --, TrafficCop=NULL --SOS# 202596
                          , DropID = ''--@cToteNo
                          , Qty = 0         --SOS# 202596
                     WHERE  Pickdetailkey = @cPickDetailKeySingle

                     FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                 END
                 CLOSE CursorPickDetailSingle
                 DEALLOCATE CursorPickDetailSingle

                 -- EventLog -- SOS# 206805
                 EXEC RDT.rdt_STD_EventLog
                      @cActionType='3' -- Picking
                     ,@cUserID=@cUserName
                     ,@nMobileNo=@nMobile
                     ,@nFunctionID=@nFunc
                     ,@cFacility=@cFacility
                     ,@cStorerKey=@cStorerKey
                     ,@cLocation=@cLoc
                     ,@cToLocation=@cToLOC
                     ,@cID=@cID -- Sugg FromID
                     ,@cToID=@cToteNo -- DropID
                     ,@cSKU=@cSKU
                     ,@nQTY=@nQTY_PD
                     ,@cRefNo1=@cLoadKey
                     ,@cRefNo2=@cTaskDetailKey
                     ,@cRefNo3=@cPickMethod
                     ,@cRefNo4='CFM-09'

                 BREAK
              END
           END

           FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
       END
       CLOSE CursorPickDetailShort
       DEALLOCATE CursorPickDetailShort
      END

      IF @cStatus = '4' AND @cPickMethod <> 'PIECE'
      BEGIN
         DECLARE CursorPickDetailShort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
               ,PD.QTY
               ,PD.LOT
         FROM   dbo.PickDetail PD WITH (NOLOCK)
                JOIN dbo.Orders O WITH (NOLOCK)
                     ON  (PD.OrderKey=O.OrderKey)
                INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                     ON  (TD.TaskDetailKey=PD.TaskDetailKey)
         WHERE  O.LoadKey = @cLoadKey
         AND    PD.StorerKey = @cStorerKey
         AND    PD.LOC = @cLOC
         AND    PD.Status = '0'
         AND    PD.SKU = @cSKU
         AND    TD.TaskDetailkey = @cTaskDetailKey
         ORDER BY PD.PickDetailKey

         OPEN CursorPickDetailShort
         FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
         WHILE @@FETCH_STATUS<>-1
         BEGIN
            -- Exact match
            IF @nQTY_PD = @nPickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 95565
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                   GOTO RollBackTran
               END

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                    @cActionType='3' -- Picking
                   ,@cUserID=@cUserName
                   ,@nMobileNo=@nMobile
                   ,@nFunctionID=@nFunc
                   ,@cFacility=@cFacility
                   ,@cStorerKey=@cStorerKey
                   ,@cLocation=@cLoc
                   ,@cToLocation=@cToLOC
                   ,@cID=@cID -- Sugg FromID
                   ,@cToID=@cToteNo -- DropID
                   ,@cSKU=@cSKU
                   ,@nQTY=@nQTY_PD
                   ,@cRefNo1=@cLoadKey
                   ,@cRefNo2=@cTaskDetailKey
                   ,@cRefNo3=@cPickMethod
                   ,@cRefNo4='CFM-10'
            END
            ELSE
            IF @nPickQty > @nQTY_PD
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 95566
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                   GOTO RollBackTran
               END

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                    @cActionType='3' -- Picking
                   ,@cUserID=@cUserName
                   ,@nMobileNo=@nMobile
                   ,@nFunctionID=@nFunc
                   ,@cFacility=@cFacility
                   ,@cStorerKey=@cStorerKey
                   ,@cLocation=@cLoc
                   ,@cToLocation=@cToLOC
                   ,@cID=@cID -- Sugg FromID
                   ,@cToID=@cToteNo -- DropID
                   ,@cSKU=@cSKU
                   ,@nQTY=@nQTY_PD
                   ,@cRefNo1=@cLoadKey
                   ,@cRefNo2=@cTaskDetailKey
                   ,@cRefNo3=@cPickMethod
                   ,@cRefNo4='CFM-11'

            END-- PickDetail have more, need to split
            ELSE
            IF @nQTY_PD > @nPickQty AND @nPickQty > 0
            BEGIN
              -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
              -- just have to update the pickdetail.qty = short pick qty
              -- Get new PickDetailkey

              EXECUTE dbo.nspg_GetKey
                       'PICKDETAILKEY',
                       10 ,
                       @cNewPickDetailKey OUTPUT,
                       @b_success         OUTPUT,
                       @n_err             OUTPUT,
                       @c_errmsg          OUTPUT

              IF @b_success <> 1
              BEGIN
                  SET @nErrNo = 95567
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'
                  GOTO RollBackTran
              END

              -- Create a new PickDetail to hold the balance
              INSERT INTO dbo.PICKDETAIL
                 (
                   CaseID                   ,PickHeaderKey    ,OrderKey
                  ,OrderLineNumber          ,LOT              ,StorerKey
                  ,SKU                      ,AltSKU           ,UOM
                  ,UOMQTY                   ,QTYMoved         ,STATUS
                  ,DropID                   ,LOC              ,ID
                  ,PackKey                  ,UpdateSource     ,CartonGroup
                  ,CartonType               ,ToLoc            ,DoReplenish
                  ,ReplenishZone            ,DoCartonize      ,PickMethod
                  ,WaveKey                  ,EffectiveDate    ,ArchiveCop
                  ,ShipFlag                 ,PickSlipNo       ,PickDetailKey
                  ,QTY                      ,TrafficCop       ,OptimizeCop
                  ,TaskDetailkey
                 )
              SELECT CaseID                ,PickHeaderKey    ,OrderKey
                    ,OrderLineNumber       ,Lot              ,StorerKey
                    ,SKU                   ,AltSku           ,UOM
                    ,UOMQTY                ,QTYMoved         ,'4'
                    ,''                    ,LOC              ,ID
                    ,PackKey               ,UpdateSource     ,CartonGroup
                    ,CartonType            ,ToLoc            ,DoReplenish
                    ,ReplenishZone         ,DoCartonize      ,PickMethod
                    ,WaveKey               ,EffectiveDate    ,ArchiveCop
                    ,ShipFlag              ,PickSlipNo       ,@cNewPickDetailKey
                    ,@nQTY_PD - @nPickQty  ,NULL             ,'1'
                    ,@cTaskDetailKey
              FROM   dbo.PickDetail WITH (NOLOCK)
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 95568
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
              END

              -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
              -- Change orginal PickDetail with exact QTY (with TrafficCop)
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    QTY = @nPickQty
                    ,Trafficcop = NULL
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 95569
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
              END

              -- Confirm orginal PickDetail with exact QTY
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    DropID = @cToteNo
                    ,STATUS = '5'
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 95570
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
              END

              -- EventLog
              EXEC RDT.rdt_STD_EventLog
                   @cActionType='3' -- Picking
                  ,@cUserID=@cUserName
                  ,@nMobileNo=@nMobile
                  ,@nFunctionID=@nFunc
                  ,@cFacility=@cFacility
                  ,@cStorerKey=@cStorerKey
                  ,@cLocation=@cLoc
                  ,@cToLocation=@cToLOC
                  ,@cID=@cID -- Sugg FromID
                  ,@cToID=@cToteNo -- DropID
                  ,@cSKU=@cSKU
                  ,@nQTY=@nQTY_PD
                  ,@cRefNo1=@cLoadKey
                  ,@cRefNo2=@cTaskDetailKey
                  ,@cRefNo3=@cPickMethod
                  ,@cRefNo4='CFM-12'
            END

            IF @nPickQty > 0
            BEGIN
               SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty
            END

            IF @nPickQty = 0 AND @cPickMethod = 'SINGLES'
            BEGIN
               DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                   SELECT PD.PickDetailKey
                   FROM   dbo.PickDetail PD WITH (NOLOCK)
                          JOIN dbo.Orders O WITH (NOLOCK)
                               ON  (PD.OrderKey=O.OrderKey)
                          INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                               ON  (TD.TaskDetailKey=PD.TaskDetailKey)
                   WHERE  O.LoadKey = @cLoadKey
                   AND    PD.StorerKey = @cStorerKey
                   AND    PD.LOC = @cLOC
                   AND    PD.Status = '0'
                   AND    PD.SKU = @cSKU
                   ORDER BY PD.PickDetailKey
            
               OPEN CursorPickDetailSingle
               FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                   UPDATE dbo.PickDetail WITH (ROWLOCK)
                   SET    STATUS = '4'
                        , DropID = ''-- @cToteNo
                        , TrafficCop = NULL, EditWho = sUser_sName(), EditDate = GETDATE()
                   WHERE  Pickdetailkey = @cPickDetailKeySingle
            
                   FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
               END
               CLOSE CursorPickDetailSingle
               DEALLOCATE CursorPickDetailSingle
            
               -- EventLog -- SOS# 206805
               EXEC RDT.rdt_STD_EventLog
                    @cActionType='3' -- Picking
                   ,@cUserID=@cUserName
                   ,@nMobileNo=@nMobile
                   ,@nFunctionID=@nFunc
                   ,@cFacility=@cFacility
                   ,@cStorerKey=@cStorerKey
                   ,@cLocation=@cLoc
                   ,@cToLocation=@cToLOC
                   ,@cID=@cID -- Sugg FromID
                   ,@cToID=@cToteNo -- DropID
                   ,@cSKU=@cSKU
                   ,@nQTY=@nQTY_PD
                   ,@cRefNo1=@cLoadKey
                   ,@cRefNo2=@cTaskDetailKey
                   ,@cRefNo3=@cPickMethod
                   ,@cRefNo4='CFM-13'
            
               BREAK
            END
            ELSE
            BEGIN
                IF @nPickQty = 0
                BEGIN
                    DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT PD.PickDetailKey
                        FROM   dbo.PickDetail PD WITH (NOLOCK)
                        JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey=O.OrderKey)
                        JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (TD.TaskDetailKey=PD.TaskDetailKey)
                        WHERE  O.LoadKey = @cLoadKey
                        AND    PD.StorerKey = @cStorerKey
                        AND    PD.LOC = @cLOC
                        AND    PD.Status = '0'
                        AND    PD.SKU = @cSKU
                        AND    TD.TaskDetailkey = @cTaskDetailKey
                        ORDER BY PD.PickDetailKey
            
                    OPEN CursorPickDetailSingle
                    FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                    WHILE @@FETCH_STATUS <> -1
                    BEGIN
                        UPDATE dbo.PickDetail WITH (ROWLOCK)
                        SET    STATUS = '4'
                             , DropID = ''-- @cToteNo
                             , TrafficCop = NULL, EditWho = sUser_sName(), EditDate = GETDATE()
                        WHERE  Pickdetailkey = @cPickDetailKeySingle
            
                        FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                   END
                   CLOSE CursorPickDetailSingle
                   DEALLOCATE CursorPickDetailSingle
            
                   -- EventLog -- SOS# 206805
                   EXEC RDT.rdt_STD_EventLog
                        @cActionType='3' -- Picking
                       ,@cUserID=@cUserName
                       ,@nMobileNo=@nMobile
                       ,@nFunctionID=@nFunc
                       ,@cFacility=@cFacility
                       ,@cStorerKey=@cStorerKey
                       ,@cLocation=@cLoc
                       ,@cToLocation=@cToLOC
                       ,@cID=@cID -- Sugg FromID
                       ,@cToID=@cToteNo -- DropID
                       ,@cSKU=@cSKU
                       ,@nQTY=@nQTY_PD
                       ,@cRefNo1=@cLoadKey
                       ,@cRefNo2=@cTaskDetailKey
                       ,@cRefNo3=@cPickMethod
                       ,@cRefNo4='CFM-14'
            
                   BREAK
                END
            END

           FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
         END
       CLOSE CursorPickDetailShort
       DEALLOCATE CursorPickDetailShort
      END
      
      
      -- Create New TaskDetail Base on Status = '4' In PickDetail 
      DECLARE CursorPickDetailTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SUM(PD.QTY)
            ,PD.LOT
      FROM   dbo.PickDetail PD WITH (NOLOCK)
             JOIN dbo.Orders O WITH (NOLOCK)
                  ON  (PD.OrderKey=O.OrderKey)
             INNER JOIN dbo.TaskDetail TD WITH (NOLOCK)
                  ON  (TD.TaskDetailKey=PD.TaskDetailKey)
      WHERE  O.LoadKey = @cLoadKey
      AND    PD.StorerKey = @cStorerKey
      AND    PD.Status = '4'
      AND    TD.TaskDetailkey = @cTaskDetailKey
      GROUP BY PD.TaskDetailKey, PD.Lot
      ORDER BY PD.TaskDetailKey

      OPEN CursorPickDetailTD
      FETCH NEXT FROM CursorPickDetailTD INTO @nQTY_PD, @cLot
      WHILE @@FETCH_STATUS<>-1
      BEGIN
         
         EXECUTE   nspg_getkey  
             'TaskDetailKey'  
             , 10  
             , @cNewTaskDetailkey OUTPUT  
             , @b_success OUTPUT  
             , @n_err OUTPUT  
             , @c_errmsg OUTPUT  
         
             
         INSERT TASKDETAIL  
             (  
             TaskDetailKey  
             ,TaskType  
             ,Storerkey  
             ,Sku  
             ,Lot  
             ,UOM  
             ,UOMQty  
             ,Qty  
             ,FromLoc  
             ,FromID  
             ,ToLoc  
             ,ToId  
             ,SourceType  
             ,SourceKey  
             ,WaveKey  
             ,Caseid  
             ,Priority  
             ,SourcePriority  
             ,OrderKey  
             ,OrderLineNumber  
             ,PickDetailKey  
             ,PickMethod  
             ,[Status]
             ,AreaKey
             ,Message03
             ,RefTaskKey
             ,SystemQty
             ,LoadKey
             ,LogicalFromLoc
             )  
         SELECT 
              @cNewTaskDetailKey
             ,TaskType  
             ,Storerkey  
             ,Sku  
             ,@cLot  
             ,UOM  
             ,UOMQty  
             ,@nQTY_PD 
             ,FromLoc  
             ,FromID  
             ,ToLoc  
             ,ToId  
             ,SourceType  
             ,SourceKey  
             ,WaveKey  
             ,Caseid  
             ,Priority  
             ,SourcePriority  
             ,OrderKey  
             ,OrderLineNumber  
             ,PickDetailKey  
             ,PickMethod 
             ,'4' 
             ,AreaKey
             ,Message03
             ,@cTaskDetailKey
             ,@nQTY_PD
             ,LoadKey
             ,LogicalFromLoc
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
         
         -- Update Original Pickdetail When Status = '4' to new TaskDetailKey
         DECLARE CursorPDTaskDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey 
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         WHERE  PD.StorerKey = @cStorerKey
         AND    PD.Status = '4'
         AND    PD.TaskDetailkey = @cTaskDetailKey
         ORDER BY PD.PickDetailKey
   
         OPEN CursorPDTaskDetailKey
         FETCH NEXT FROM CursorPDTaskDetailKey INTO @cPickDetailKey 
         WHILE @@FETCH_STATUS<>-1
         BEGIN
            
            UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET TaskDetailKey = @cNewTaskDetailkey 
                  ,Trafficcop    = NULL
                  ,EditWho       = sUser_sName()
                  ,EditDate      = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey 
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 95577
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPickDetFail'
               GOTO RollBackTran
            END
            
            FETCH NEXT FROM CursorPDTaskDetailKey INTO @cPickDetailKey 
            
         END
         CLOSE CursorPDTaskDetailKey
         DEALLOCATE CursorPDTaskDetailKey
         

         FETCH NEXT FROM CursorPickDetailTD INTO @nQTY_PD, @cLot
         
      END
      CLOSE CursorPickDetailTD
      DEALLOCATE CursorPickDetailTD
      
      
   END -- @cTMAutoShortPick = '1'

   GOTO Quit

   RollBackTran:
   ROLLBACK TRAN TM_Picking_ConfirmTask

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN TM_Picking_ConfirmTask
END

GO