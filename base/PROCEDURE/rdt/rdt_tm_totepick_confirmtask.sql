SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_TotePick_ConfirmTask                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_TM_Picking                                       */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-05-29 1.0  Shong                                                */
/* 2014-07-18 1.1  ChewKP   Fixes & Putin more TraceInfo (ChewKP01)     */
/* 2014-08-01 1.2  ChewKP   DTC Enhancement (ChewKP02)                  */
/* 2014-09-03 1.3  ChewKP   Fixes To Update PickDetail.TaskDetailkey    */
/*                          for PickMethod = '' (ChewKP03)              */
/* 2014-10-03 1.4  ChewKP   Update DropID.Status = '5' when confirm     */
/*                          -- (ChewKP04)                               */
/* 2014-11-28 1.5  SPChin   SOS326207 - Bug Fixed                       */
/* 2015-06-08 1.6  ChewKP   SOS#343462 - Bug Fixed (ChewKP05)           */                           
/* 24-02-2017 2.5  TLTING   Performance tune- Editwho, Editdate         */
/* 03-09-2018 2.6  CHEEMUN  INC0366735 - Log UserQty into RDTSTDEvenLog */  
/************************************************************************/
CREATE PROC [RDT].[rdt_TM_TotePick_ConfirmTask] (
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

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN TM_Picking_ConfirmTask

  /*     INSERT INTO TraceInfo
       (
          TraceName,      TimeIn,    [TimeOut],
          TotalTime,      Step1,     Step2,
          Step3,          Step4,     Step5,
          Col1,           Col2,      Col3,
          Col4,           Col5        )
       VALUES
       (
          'rdt_TM_TotePick_ConfirmTask' /* TraceName */,
          GETDATE() /* TimeIn */,
          GETDATE() /* [TimeOut] */,
          '1' /* TotalTime */,
          CAST(@nPickQty AS VARCHAR(10))  /* Step1 */,
          @cStatus  /* Step2 */,
          @cToteNo  /* Step3 */,
          @nTotalQty /* Step4 */,
          '' /* Step5 */,
          @cTaskDetailKey /* Col1 */,
          @cLoadKey /* Col2 */,
          @cStorerKey /* Col3 */,
          @cSKU /* Col4 */,
          @cLOC /* Col5 */
       )
*/

   -- (ChewKP04)
   UPDATE DropID
   SET EditWho = SUSER_SNAME(),
         EditDate = GETDATE(),
         [Status] = '5'
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
  /*       INSERT INTO TraceInfo
         (
            TraceName,      TimeIn,    [TimeOut],
            TotalTime,      Step1,     Step2,
            Step3,          Step4,     Step5,
            Col1,           Col2,      Col3,
            Col4,           Col5        )
         VALUES
         (
            'rdt_TM_TotePick_ConfirmTask' /* TraceName */,
            GETDATE() /* TimeIn */,
            GETDATE() /* [TimeOut] */,
            '2' /* TotalTime */,
            ''  /* Step1 */,
            ''  /* Step2 */,
            @cPickDetailKey /* Step3 */,
            CAST(@nQTY_PD AS VARCHAR(10)) /* Step4 */,
            CAST(@nQTY_PD AS VARCHAR(10)) /* Step5 */,
            @cTaskDetailKey /* Col1 */,
            @cLoadKey /* Col2 */,
            @cStorerKey /* Col3 */,
            @cSKU /* Col4 */,
            @cLOC /* Col5 */
         )

*/
          IF @nQTY_PD=@nPickQty
          BEGIN
             -- Confirm PickDetail
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo
                   ,STATUS = @cStatus
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90133
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
                 ,@nQTY=@nPickQty  --INC0366735 
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-01'

          END
          ELSE IF @nPickQty > @nQTY_PD
          BEGIN
             -- Confirm PickDetail
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo
                   ,STATUS = '5'
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90120
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
                 ,@nQTY=@nQTY_PD  --INC0366735 
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
                 SET @nErrNo = 90129
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
                 SET @nErrNo = 90130
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                 GOTO RollBackTran
             END

             -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
             -- Change orginal PickDetail with exact QTY (with TrafficCop)
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     QTY = @nPickQty
                   ,Trafficcop = NULL
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90131
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                 GOTO RollBackTran
             END

             -- Confirm orginal PickDetail with exact QTY
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo
                   ,STATUS = @cStatus
             WHERE  PickDetailKey = @cPickDetailKey
             IF @@ERROR <> 0
             BEGIN                      SET @nErrNo = 90128
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
                 ,@nQTY=@nPickQty  --INC0366735 
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-03'

          END  -- IF @nPickQty < @nQTY_PD AND @nPickQty > 0

          IF @nPickQty > 0
          BEGIN
              SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty
              IF @nPickQty < 0 		--SOS326207
              		SET @nPickQty = 0	--SOS326207
          END

          --IF @nPickQty = 0 AND @cPickMethod IN ('DOUBLES', 'MULTIS', 'PP', 'STOTE')   -- (ChewKP03)
          --IF @nPickQty = 0 AND @cPickMethod IN ('DOUBLES', 'MULTIS', 'STOTE')   -- (ChewKP03) -- (ChewKP05)
          --   BREAK -- (ChewKP05)

          IF @nPickQty = 0 AND @cPickMethod = 'SINGLES' AND ISNULL(RTRIM(@cNTaskDetailkey),'') <> '' -- (SHONG03)
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
                  AND    PD.TaskDetailKey = @cTaskDetailKey -- (SHONG03)
                  ORDER BY TD.PickDetailKey

              OPEN CursorPickDetailSingle
              FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              WHILE @@FETCH_STATUS<>-1
              BEGIN
                 IF ISNULL(@cNTaskDetailkey,'') = ''
                 BEGIN
                     SET @nErrNo = 90131
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'SEE_SUPERVISOR'
                     GOTO RollBackTran
                 END

                 UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET   EditWho = SUSER_SNAME(),
                        EditDate = GETDATE(),
                        TaskDetailkey = @cNTaskDetailkey
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
                    ORDER BY TD.PickDetailKey

                OPEN CursorPickDetailSingle
                FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                WHILE @@FETCH_STATUS<>-1
                BEGIN
                    IF ISNULL(@cNTaskDetailkey,'') = ''
                    BEGIN
                       SET @nErrNo = 90132
                       SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'SEE_SUPERVISOR'
                       GOTO RollBackTran
                    END

                    UPDATE dbo.PickDetail WITH (ROWLOCK)
                    SET    EditWho = SUSER_SNAME(),
                           EditDate = GETDATE(),
                           TaskDetailkey = @cNTaskDetailkey
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
                ORDER BY TD.PickDetailKey

            OPEN CursorPickDetailSingle
            FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    STATUS = '4', EditWho=sUser_sName(), EditDate=GETDATE()
                  --, TrafficCop=NULL --SOS# 202596
                    , DropID  = @cToteNo
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
             ,@nQTY=@nPickQty  --INC0366735 
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
                TD.PickDetailKey

         OPEN CursorPickDetailShort
         FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Exact match
            IF @nQTY_PD = @nPickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 90134
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
                   ,@nQTY=@nPickQty  --INC0366735
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
               SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 90123
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
                   ,@nQTY=@nQTY_PD  --INC0366735 
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
                 SET @nErrNo = 90124
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
                  SET @nErrNo = 90122
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
              END

              -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
              -- Change orginal PickDetail with exact QTY (with TrafficCop)
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     QTY = @nPickQty
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 90125
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
              END

              -- Confirm orginal PickDetail with exact QTY
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo
                    ,STATUS = '5'
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 90126
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
                  ,@nQTY=@nPickQty  --INC0366735
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
                  ORDER BY TD.PickDetailKey

              OPEN CursorPickDetailSingle
              FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              WHILE @@FETCH_STATUS <> -1
              BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET    STATUS = '4',  DropID = @cToteNo, EditWho = sUser_sName(), EditDate = GETDATE()  , TrafficCop = NULL
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
                   ,@nQTY=@nPickQty  --INC0366735
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
                            TD.PickDetailKey

                 OPEN CursorPickDetailSingle
                 FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                 WHILE @@FETCH_STATUS <> -1
                 BEGIN
                     UPDATE dbo.PickDetail WITH (ROWLOCK)
                     SET    STATUS = '4', EditWho = sUser_sName(), EditDate = GETDATE()
                        --, TrafficCop=NULL --SOS# 202596
                          , DropID = @cToteNo
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
                     ,@nQTY=@nPickQty  --INC0366735
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
         ORDER BY TD.PickDetailKey

         OPEN CursorPickDetailShort
         FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
         WHILE @@FETCH_STATUS<>-1
         BEGIN
            -- Exact match
            IF @nQTY_PD = @nPickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 90134
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
                   ,@nQTY=@nPickQty  --INC0366735
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
               SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo  --               Status = @cStatus
                     ,STATUS = '5'
               WHERE  PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 90123
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
                   ,@nQTY=@nQTY_PD  --INC0366735 
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
                  SET @nErrNo = 90124
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
                    ,@cToteNo              ,LOC              ,ID
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
                  SET @nErrNo = 90122
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
              END

              -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
              -- Change orginal PickDetail with exact QTY (with TrafficCop)
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     QTY = @nPickQty
                    ,Trafficcop = NULL
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 90125
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
              END

              -- Confirm orginal PickDetail with exact QTY
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo
                    ,STATUS = '5'
              WHERE  PickDetailKey = @cPickDetailKey

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 90126
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
                  ,@nQTY=@nPickQty  --INC0366735
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
                  ORDER BY TD.PickDetailKey

              OPEN CursorPickDetailSingle
              FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
              WHILE @@FETCH_STATUS <> -1
              BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET    STATUS = '4'
                       , DropID = @cToteNo
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
                  ,@nQTY=@nPickQty  --INC0366735
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
                       ORDER BY TD.PickDetailKey

                   OPEN CursorPickDetailSingle
                   FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                   WHILE @@FETCH_STATUS <> -1
                   BEGIN
                       UPDATE dbo.PickDetail WITH (ROWLOCK)
                       SET    STATUS = '4'
                            , DropID = @cToteNo
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
                      ,@nQTY=@nPickQty  --INC0366735
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
   END -- @cTMAutoShortPick = '1'
   ELSE
   BEGIN
      DECLARE CursorPickDetailShort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PD.PickDetailKey
                ,PD.QTY
                ,PD.LOT
          FROM   dbo.PickDetail PD WITH (NOLOCK)
          JOIN dbo.Orders O WITH (NOLOCK) ON  (PD.OrderKey=O.OrderKey)
          JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (TD.TaskDetailKey=PD.TaskDetailKey)
          WHERE  O.LoadKey = @cLoadKey
          AND    PD.StorerKey = @cStorerKey
          AND    PD.LOC = @cLOC
          AND    PD.Status = '0'
          AND    PD.SKU = @cSKU
          AND    TD.TaskDetailkey = @cTaskDetailKey
          ORDER BY TD.PickDetailKey

      OPEN CursorPickDetailShort
      FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
      WHILE @@FETCH_STATUS<>-1
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
             -- Confirm PickDetail
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo  --               Status = @cStatus
                   ,STATUS = '5'
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90134
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
                 ,@nQTY=@nPickQty  --INC0366735
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-15'
         END
         ELSE
         IF @nPickQty > @nQTY_PD
         BEGIN
             -- Confirm PickDetail
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo  --               Status = @cStatus
                   ,STATUS = '5'
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90123
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
                 ,@nQTY=@nQTY_PD  --INC0366735
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-16'

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

             IF @b_success<>1
             BEGIN
                 SET @nErrNo = 90124
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'
                 GOTO RollBackTran
             END

             -- Create a new PickDetail to hold the balance
             INSERT INTO dbo.PICKDETAIL
               (
                 CaseID                    ,PickHeaderKey      ,OrderKey
                ,OrderLineNumber           ,LOT                ,StorerKey
                ,SKU                       ,AltSKU             ,UOM
                ,UOMQTY                    ,QTYMoved           ,STATUS
                ,DropID                    ,LOC                ,ID
                ,PackKey                   ,UpdateSource       ,CartonGroup
                ,CartonType                ,ToLoc              ,DoReplenish
                ,ReplenishZone             ,DoCartonize        ,PickMethod
                ,WaveKey                   ,EffectiveDate      ,ArchiveCop
                ,ShipFlag                  ,PickSlipNo         ,PickDetailKey
                ,QTY                       ,TrafficCop         ,OptimizeCop
                ,TaskDetailkey
               )
             SELECT CaseID                 ,PickHeaderKey      ,OrderKey
                   ,OrderLineNumber        ,Lot                ,StorerKey
                   ,SKU                    ,AltSku             ,UOM
                   ,UOMQTY                 ,QTYMoved           ,'4'
                   ,@cToteNo               ,LOC                ,ID
                   ,PackKey                ,UpdateSource       ,CartonGroup
                   ,CartonType             ,ToLoc              ,DoReplenish
                   ,ReplenishZone          ,DoCartonize        ,PickMethod
                   ,WaveKey                ,EffectiveDate      ,ArchiveCop
                   ,ShipFlag               ,PickSlipNo         ,@cNewPickDetailKey
                   ,@nQTY_PD - @nPickQty   ,NULL               ,'1'
                   ,@cTaskDetailKey
             FROM   dbo.PickDetail WITH (NOLOCK)
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90122
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'
                 GOTO RollBackTran
             END

             -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
             -- Change orginal PickDetail with exact QTY (with TrafficCop)
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     QTY = @nPickQty
                   ,Trafficcop = NULL
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90125
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'
                 GOTO RollBackTran
             END

             -- Confirm orginal PickDetail with exact QTY
             UPDATE dbo.PickDetail WITH (ROWLOCK)
             SET    EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     DropID = @cToteNo
                   ,STATUS = '5'
             WHERE  PickDetailKey = @cPickDetailKey

             IF @@ERROR <> 0
             BEGIN
                 SET @nErrNo = 90126
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
                 ,@nQTY=@nPickQty  --INC0366735
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-17'
         END

         IF @nPickQty > 0
         BEGIN
             SET @nPickQty = @nPickQty - @nQTY_PD -- OffSet PickQty
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
                 ORDER BY TD.PickDetailKey

             OPEN CursorPickDetailSingle
             FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
             WHILE @@FETCH_STATUS<>-1
             BEGIN
                 UPDATE dbo.PickDetail WITH (ROWLOCK)
                 SET    STATUS = '4', TrafficCop = NULL, EditWho = sUser_sName(), EditDate = GETDATE()
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
                 ,@nQTY=@nPickQty  --INC0366735
                 ,@cRefNo1=@cLoadKey
                 ,@cRefNo2=@cTaskDetailKey
                 ,@cRefNo3=@cPickMethod
                 ,@cRefNo4='CFM-18'

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
                    ORDER BY TD.PickDetailKey

                OPEN CursorPickDetailSingle
                FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle
                WHILE @@FETCH_STATUS<>-1
                BEGIN
                    UPDATE dbo.PickDetail WITH (ROWLOCK)
                    SET    STATUS = '4'
                         , DropID = @cToteNo
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
                    ,@nQTY=@nPickQty  --INC0366735
                    ,@cRefNo1=@cLoadKey
                    ,@cRefNo2=@cTaskDetailKey
                    ,@cRefNo3=@cPickMethod
                    ,@cRefNo4='CFM-19'

                BREAK
             END
         END

         FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT
      END
      CLOSE CursorPickDetailShort
      DEALLOCATE CursorPickDetailShort
   END

 /*  INSERT INTO TraceInfo
       (
          TraceName,      TimeIn,    [TimeOut],
          TotalTime,      Step1,     Step2,
          Step3,          Step4,     Step5,
          Col1,           Col2,      Col3,
          Col4,           Col5        )
       VALUES
       (
          'rdt_TM_TotePick_ConfirmTask' /* TraceName */,
          GETDATE() /* TimeIn */,
          GETDATE() /* [TimeOut] */,
          '4' /* TotalTime */,
          CAST(@nPickQty AS VARCHAR(10))  /* Step1 */,
          @cStatus  /* Step2 */,
          @cToteNo  /* Step3 */,
          @nTotalQty /* Step4 */,
          '' /* Step5 */,
          @cTaskDetailKey /* Col1 */,
          @cLoadKey /* Col2 */,
          @cStorerKey /* Col3 */,
          @cSKU /* Col4 */,
          @cLOC /* Col5 */
       )
*/
   -- (ChewKP01)
   --IF CAST(@cToteNo AS INT) > 0
   --BEGIN
         SET @cTaskType = ''
         SELECT @cTaskType = TaskType
               ,@cOrderKey = OrderKey
               ,@cAreaKey  = AreaKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey




         EXEC [dbo].[ispWCSRO01]
           @c_StorerKey     = @cStorerKey
         , @c_Facility      = @cFacility
         , @c_ToteNo        = @cToteNo
         , @c_TaskType      = @cTaskType -- 'SPK' -- (ChewKP02)
         , @c_ActionFlag    = 'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
         , @c_TaskDetailKey = ''
         , @c_Username      = @cUserName
         , @c_RefNo01       = @cLoadKey
         , @c_RefNo02       = @cPickMethod -- (ChewKP02)
         , @c_RefNo03       = @cOrderKey -- (ChewKP02)
         , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
         , @c_RefNo05       = ''
         , @b_debug         = '0'
         , @c_LangCode      = 'ENG'
         , @n_Func          = 0
         , @b_Success       = @b_success OUTPUT
         , @n_ErrNo         = @nErrNo    OUTPUT
         , @c_ErrMsg        = @cErrMSG   OUTPUT

         IF @cStatus = '5'
         BEGIN
            IF @cPickMethod = 'MULTIS'
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                          WHERE OrderKey = @cOrderKey
                          AND StorerKey = @cStorerKey
                          AND ISNULL(ReasonKey,'')  <> '' )
               BEGIN
                  SET @cShortPick = '1'
               END

            END
            ELSE
            BEGIN
               SET @cActionFlag = 'N'
            END
         END
         ELSE IF @cStatus = '4'
         BEGIN
            SET @cShortPick = '1'
         END


         IF @cPickMethod IN ( 'SINGLES' , 'PP' ) AND @cShortPick = '1'
         BEGIN
            SET @cActionFlag = 'S'
         END
         ELSE IF @cPickMethod = 'MULTIS' AND @cShortPick = '1'
         BEGIN
            -- Insert Routing to QC when there is last task in the Orders

            SET @nCountTask = 0

            SELECT @nCountTask = Count(Distinct TaskDetailKey )
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND StorerKey = @cStorerKey
            AND Status <> '9'


--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
--                        WHERE OrderKey = @cOrderKey
--                        AND StorerKey = @cStorerKey
--                        AND Status <> '9')
--                        --HAVING Count(TaskDetailKey) BETWEEN 0 AND 1  )
            IF @nCountTask = '1'
            BEGIN
                 SET @cActionFlag = 'S'
            END
            ELSE
            BEGIN
               SET @cActionFlag = 'N'
            END
         END

  /*       INSERT INTO TraceInfo
       (
          TraceName,      TimeIn,    [TimeOut],
          TotalTime,      Step1,     Step2,
          Step3,          Step4,     Step5,
          Col1,           Col2,      Col3,
          Col4,           Col5        )
       VALUES
       (
          'rdt_TM_TotePick_ConfirmTask' /* TraceName */,
          GETDATE() /* TimeIn */,
          GETDATE() /* [TimeOut] */,
          '4' /* TotalTime */,
          CAST(@nPickQty AS VARCHAR(10))  /* Step1 */,
          @cStatus  /* Step2 */,
          @cToteNo  /* Step3 */,
          @nCountTask /* Step4 */,
          '' /* Step5 */,
          @cTaskDetailKey /* Col1 */,
          @cActionFlag /* Col2 */,
          @cStorerKey /* Col3 */,
          @cSKU /* Col4 */,
          @cLOC /* Col5 */
       )
*/

         IF @cActionFlag = 'S'
         BEGIN
             EXEC [dbo].[ispWCSRO01]
                @c_StorerKey     = @cStorerKey
              , @c_Facility      = @cFacility
              , @c_ToteNo        = @cToteNo
              , @c_TaskType      = @cTaskType -- 'SPK' -- (ChewKP02)
              , @c_ActionFlag    = @cActionFlag -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
              , @c_TaskDetailKey = '' -- @cTaskdetailkey
              , @c_Username      = @cUserName
              , @c_RefNo01       = @cLoadKey
              , @c_RefNo02       = @cPickMethod -- (ChewKP02)
              , @c_RefNo03       = @cOrderKey -- (ChewKP02)
              , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
              , @c_RefNo05       = ''
              , @b_debug         = '0'
              , @c_LangCode      = 'ENG'
              , @n_Func          = 0
              , @b_Success       = @b_success OUTPUT
              , @n_ErrNo         = @nErrNo    OUTPUT
              , @c_ErrMsg        = @cErrMSG   OUTPUT


--              IF @nErrNo <> 0
--              BEGIN
--                 SET @nErrNo = @nErrNo
--                 SET @cErrMsg = @cErrMsg  --'UpdWCSRouteFail'
--                 GOTO RollBackTran
--              END

              --SET @cActionFlag = 'N'
         END


         -- QC Station Inserted after last pick
         EXEC [dbo].[ispWCSRO01]
           @c_StorerKey     = @cStorerKey
         , @c_Facility      = @cFacility
         , @c_ToteNo        = @cToteNo
         , @c_TaskType      = @cTaskType -- 'SPK' -- (ChewKP02)
         , @c_ActionFlag    = 'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
         , @c_TaskDetailKey = '' -- @cTaskdetailkey
         , @c_Username      = @cUserName
         , @c_RefNo01       = @cLoadKey
         , @c_RefNo02       = @cPickMethod -- (ChewKP02)
         , @c_RefNo03       = @cOrderKey -- (ChewKP02)
         , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
         , @c_RefNo05       = ''
         , @b_debug         = '0'
         , @c_LangCode      = 'ENG'
         , @n_Func          = 0
         , @b_Success       = @b_success OUTPUT
         , @n_ErrNo         = @nErrNo    OUTPUT
         , @c_ErrMsg        = @cErrMSG   OUTPUT





   --END
   GOTO Quit

   RollBackTran:
   ROLLBACK TRAN TM_Picking_ConfirmTask

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN TM_Picking_ConfirmTask
END

GO