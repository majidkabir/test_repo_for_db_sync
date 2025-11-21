SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_TM_PiecePick_ConfirmTask                        */  
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
/* 02-07-2010 1.0  ChewKP   Created                                     */  
/* 27-07-2010 1.0  Vicky    Refine Code (Vicky01)                       */  
/* 29-07-2010 1.0  Vicky    Bug Fix (Vicky02)                           */  
/* 03-09-2010 1.0  Shong    Fixing BLANK TaskDetailKey Issues (Shong01) */  
/* 05-09-2010 1.0  Shong    Mixinf Blank TaskDetailKey Issues (Shong02) */  
/* 15-10-2010 1.0  Shong    Found Error when close tote for Singles     */  
/*                          Update Pickdetail belong to other PickMd    */  
/*                          (SHONG03)                                   */  
/* 02-11-2010 1.0  Shong    Only Update Pickdetail PickSlipNo if Pick   */  
/*                          Header not Exists (SHONG04)                 */  
/* 08-11-2010 1.0  Shong    Only Insert PickingInfo for scanned Task,   */  
/*                          Not for entire Load. (SHONG05)              */  
/* 24-11-2010 1.1  ChewKP   SOS#197067 Auto Short Pick, prevent         */  
/*                          WCSRouting update to QC when PickMethod     */  
/*                          = 'PIECE' (ChewKP01)                        */  
/* 22-12-2010 1.2  ChewKP   Bug Fixes (ChewKP02)                        */  
/* 14-01-2011 1.3  Leong    SOS# 202596 - Bug Fix                       */  
/* 25-02-2011 1.4  Leong    SOS# 206805 - Add rdt_STD_EventLog          */  
/* 18-01-2012 1.5  Leong    SOS# 233330 - Display error msg from        */  
/*                                        PickDetail update trigger     */  
/* 19-04-2012      Leong    SOS# 241911 - Log PickDetail DropId         */  
/* 23-06-2014 1.6  James    SOS313463 - Cater for additional pickmethod */
/*                          singles% or multis% (james01)               */
/* 09-12-2014 1.7  James    SOS326846 - Allow all tasktype use config   */
/*                          "TMAutoShortPick" (james02)                 */
/* 27-02-2015 1.8  James    SOS334537 - Bug fix on ecom short pick not  */
/*                          upd status 4 in pickdetail (james03)        */
/* 01-04-2015 1.9  James    SOS337577-Add pkkslip# in eventlog (james04)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_TM_PiecePick_ConfirmTask] (  
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
   , @nErrNo           INT         OUTPUT  
   , @cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max  
   , @c_PickMethod     NVARCHAR(10)=''  
   , @c_NTaskDetailkey NVARCHAR(10)=''  
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
          , @c_PDOrderkey          NVARCHAR(10)  
          , @cPickDetailKeySingle  NVARCHAR(10)  
          , @c_TMAutoShortPick     NVARCHAR(1)  
          , @cPD_DropId            NVARCHAR(18) -- SOS# 241911  
          , @cTD_DropId            NVARCHAR(18) -- SOS# 241911  
  
    SET @nTranCount = @@TRANCOUNT  
  
    BEGIN TRAN  
    SAVE TRAN TM_Picking_ConfirmTask  
  
    DECLARE curPickingInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     SELECT DISTINCT O.ORDERKEY  
     FROM   dbo.PickDetail PD WITH (NOLOCK)  
     JOIN dbo.Orders O WITH (NOLOCK) ON  (PD.OrderKey=O.OrderKey)  
     JOIN dbo.TaskDetail TD WITH (NOLOCK) ON  (TD.TaskDetailKey=PD.TaskDetailKey)  
      WHERE  O.LoadKey = @cLoadKey  
      AND    PD.StorerKey = @cStorerKey  
      AND    PD.LOC = @cLOC  
      AND    PD.Status = '0'  
      AND    PD.SKU = @cSKU  
      AND    TD.TaskDetailkey = @cTaskDetailKey  
  
--     (SHONG05) -- Replace with above  
--     SELECT DISTINCT O.ORDERKEY  
--     FROM   ORDERS O WITH (NOLOCK)  
--     INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON  OD.ORDERKEY = O.ORDERKEY  
--     INNER JOIN LOADPLANDETAIL LP WITH (NOLOCK) ON  LP.OrderKey = O.OrderKey  
--     WHERE  LP.Loadkey = @cLoadKey  
--     AND    O.Storerkey = @cStorerKey  
--     AND    OD.SKU = @cSKU  
--     AND    O.STORERKEY = @cStorerKey  
  
    OPEN curPickingInfo  
    FETCH NEXT FROM curPickingInfo INTO @cOrderKey  
    WHILE @@FETCH_STATUS<>-1  
    BEGIN  
        SET @cPickSlipno = ''  
        SELECT @cPickSlipno = ISNULL(PickheaderKey,'')  
        FROM   dbo.PickHeader WITH (NOLOCK)  
        WHERE  OrderKey = @cOrderKey -- AND Zone = 'D'  
  
        -- Create Pickheader  
        IF ISNULL(RTRIM(@cPickSlipno) ,'') = ''  
        BEGIN  
            EXECUTE dbo.nspg_GetKey  
                     'PICKSLIP',  
                     9,  
                     @cPickslipno OUTPUT,  
                     @b_success   OUTPUT,  
                     @n_err       OUTPUT,  
                     @c_errmsg    OUTPUT  
  
            IF @n_err <> 0  
            BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 70416  
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail  
                GOTO RollBackTran  
            END  
  
            SELECT @cPickslipno = 'P' + @cPickslipno  
  
            INSERT INTO dbo.PICKHEADER  
              (  
                PickHeaderKey  
               ,ExternOrderKey  
               ,Orderkey  
               ,PickType  
               ,Zone  
               ,TrafficCop  
              )  
            VALUES  
              (  
                @cPickslipno  
               ,@cLoadKey  
               ,@cOrderKey  
               ,'0'  
               ,'D'  
               ,''  
              )  
  
            IF @@ERROR <> 0  
            BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 70417  
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --InstPKHdr Fail  
                GOTO RollBackTran  
            END  
  
           -- (SHONG04)  
           -- Only UPDATE Pickdetail when Pick Header not exists  
           UPDATE dbo.PICKDETAIL WITH (ROWLOCK)  
           SET    PickSlipNo = @cPickSlipNo  
                 ,TrafficCop = NULL  
           WHERE  OrderKey = @cOrderKey  
  
           IF @@ERROR <> 0  
           BEGIN  
               ROLLBACK TRAN  
               SET @nErrNo = 70419  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- UpdPickDetailFail  
               GOTO RollBackTran  
           END  
  
        END --ISNULL(@cPickSlipno, '') = ''  
  
        IF NOT EXISTS (  
               SELECT 1  
               FROM   dbo.PickingInfo WITH (NOLOCK)  
               WHERE  PickSlipNo = @cPickSlipNo  
           )  
        BEGIN  
            INSERT INTO dbo.PickingInfo  
              (  
                PickSlipNo  
               ,ScanInDate  
               ,PickerID  
               ,ScanOutDate  
               ,AddWho  
              )  
            VALUES  
              (  
                @cPickSlipNo  
               ,GETDATE()  
               ,@cUserName  
               ,NULL  
               ,@cUserName  
              )  
  
            IF @@ERROR <> 0  
            BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 70418  
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan In Fail  
                GOTO RollBackTran  
            END  
        END  
  
        FETCH NEXT FROM curPickingInfo INTO @cOrderKey  
    END  
    CLOSE curPickingInfo  
    DEALLOCATE curPickingInfo  
  
    --**CONFIRM PICKDETAIL (START)**--  
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
        FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cLOT, @c_PDOrderkey  
        WHILE @@FETCH_STATUS<>-1  
        BEGIN  
            IF @nQTY_PD=@nPickQty  
            BEGIN  
                -- Confirm PickDetail  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  
                      ,STATUS = @cStatus  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
                   GOTO RollBackTran  
                END  
                -- IF @@ERROR <> 0  
                -- BEGIN  
                --     SET @nErrNo = 70433  
                --     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                --     GOTO RollBackTran  
                -- END  
  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-01'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
            END  
            ELSE  
            IF @nPickQty > @nQTY_PD  
            BEGIN  
                -- Confirm PickDetail  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  
                      ,STATUS = '5'  
                      -- ,TaskDetailkey = @cTaskDetailKey (Shong01)  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
                   GOTO RollBackTran  
                END  
                -- IF @@ERROR <> 0  
                -- BEGIN  
 --     SET @nErrNo = 70420  
                --     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                --     GOTO RollBackTran  
                -- END  
  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-02'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
            END  
            ELSE  
            IF @nPickQty < @nQTY_PD AND @nPickQty > 0  
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
                    SET @nErrNo = 70429  
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
                      ,@c_NTaskDetailkey  
                FROM   dbo.PickDetail WITH (NOLOCK)  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                IF @@ERROR <> 0  
                BEGIN  
                    SET @nErrNo = 70430  
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
                    SET @nErrNo = 70431  
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                    GOTO RollBackTran  
                END  
  
                -- Confirm orginal PickDetail with exact QTY  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  
                      ,STATUS = @cStatus  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-03'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
            END  
  
            IF @nPickQty > 0  
            BEGIN  
                SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty  
            END  
  
            -- (Shong02)  
            -- IF ISNULL(RTRIM(@c_NTaskDetailkey),'') = ''  
            --    BREAK  
  
            IF @nPickQty = 0 AND 
               (@c_PickMethod LIKE 'DOUBLES%' OR @c_PickMethod LIKE 'MULTIS%')
               BREAK  
            -- (Shong02)  
  
            IF @nPickQty = 0 AND 
               @c_PickMethod LIKE 'SINGLES%' AND 
               ISNULL(RTRIM(@c_NTaskDetailkey),'') <> '' -- (SHONG03)  
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
                    IF ISNULL(@c_NTaskDetailkey,'') = ''  
                    BEGIN  
                        -- INSERT INTO TraceInfo(TraceName,TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5)  
                        -- VALUES ('InvTaskDetKey', GetDate(), GetDate(), '', @cTaskDetailKey, @c_NTaskDetailkey, @cPickDetailKey,'','')  
  
                        SET @nErrNo = 70431  
                        SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'SEE_SUPERVISOR'  
                        GOTO RollBackTran  
                    END  
  
                    UPDATE dbo.PickDetail WITH (ROWLOCK)  
                     SET    TaskDetailkey = @c_NTaskDetailkey  
                          ,Trafficcop = NULL -- (Vicky01)  
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
                --IF @nPickQty = 0 BREAK  
                IF @nPickQTy = 0 AND ISNULL(RTRIM(@c_NTaskDetailkey),'') <> '' -- (SHONG03)  
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
                        IF ISNULL(@c_NTaskDetailkey,'') = ''  
                        BEGIN  
                           -- INSERT INTO TraceInfo(TraceName,TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5)  
                           -- VALUES ('InvTaskDetKey', GetDate(), GetDate(), '', @cTaskDetailKey, @c_NTaskDetailkey, @cPickDetailKey,'','')  
  
                           SET @nErrNo = 70432  
                           SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'SEE_SUPERVISOR'  
                           GOTO RollBackTran  
                        END  
  
                        UPDATE dbo.PickDetail WITH (ROWLOCK)  
                        SET    TaskDetailkey = @c_NTaskDetailkey  
                              ,Trafficcop = NULL -- (Vicky01)  
                        WHERE  Pickdetailkey = @cPickDetailKeySingle  
  
                        FETCH NEXT FROM CursorPickDetailSingle INTO @cPickDetailKeySingle  
                    END  
                    CLOSE CursorPickDetailSingle  
                    DEALLOCATE CursorPickDetailSingle  
  
                    BREAK  
                END  
            END  
  
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @cLOT, @c_PDOrderkey  
        END -- While Loop for PickDetail Key  
        CLOSE CursorPickDetail  
        DEALLOCATE CursorPickDetail  
    END --  @cStatus = '5'  
  
    -- (ChewKP01)  
    SET @c_TMAutoShortPick = ''  
    SET @c_TMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)  

   -- TMAutoShortPick (0 = off, 1 = on for Store piece pick only, 2 = on for Ecom pick only; 3 = on for both type) (james15)
   IF @c_TMAutoShortPick IN ('1', '2', '3')
   BEGIN  
       IF @cStatus = '4' AND 
          @c_PickMethod LIKE 'PIECE%' AND 
          ISNULL(RTRIM(@cLoc),'') = ''  
       BEGIN  
            IF @nPickQty = 0  
            BEGIN  
               DECLARE CursorPickDetailSingle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT PD.PickDetailKey  
               FROM  dbo.PickDetail PD WITH (NOLOCK)  
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
               ,@cRefNo3=@c_PickMethod  
               ,@cRefNo4='CFM-04'  
               ,@cPickSlipno = @cPickSlipno   -- (james04)
       END  
  
      IF @cStatus = '4' AND 
         @c_PickMethod LIKE 'PIECE%' AND 
         ISNULL(RTRIM(@cLoc),'') <> '' AND 
         ISNULL(RTRIM(@cSKU),'') <> '' -- (ChewKP01)  
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
                SET    DropID = @cToteNo  --               Status = @cStatus  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-05'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
            END  
            ELSE  
            IF @nPickQty > @nQTY_PD  
            BEGIN  
                -- Confirm PickDetail  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  --               Status = @cStatus  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
                   GOTO RollBackTran  
                END  
                -- IF @@ERROR <> 0  
                -- BEGIN  
                --     SET @nErrNo = 70423  
                --     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                --     GOTO RollBackTran  
                -- END  
  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-06'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)

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
                    SET @nErrNo = 70424  
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
                    SET @nErrNo = 70422  
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'  
                    GOTO RollBackTran  
                END  
  
                -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop  
                -- Change orginal PickDetail with exact QTY (with TrafficCop)  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    QTY = @nPickQty  
                      --,Trafficcop = NULL -- (ChewKP02)  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
                   GOTO RollBackTran  
                END  
  
                -- Confirm orginal PickDetail with exact QTY  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-07'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
            END  
  
            IF @nPickQty > 0  
            BEGIN  
               SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty  
            END  
  
            IF @nPickQty = 0 AND 
               @c_PickMethod LIKE 'SINGLES%'  
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
                    SET    STATUS = '4',  EditWho = sUser_sName(), EditDate = GETDATE()  , TrafficCop = NULL  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-08'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
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
                             , Qty = 0  --SOS# 202596  
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
                        ,@cRefNo3=@c_PickMethod  
                        ,@cRefNo4='CFM-09'  
                        ,@cPickSlipno = @cPickSlipno   -- (james04)
  
                    BREAK  
                END  
            END  
  
            FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT  
        END  
        CLOSE CursorPickDetailShort  
        DEALLOCATE CursorPickDetailShort  
       END  
  
       IF @cStatus = '4' AND 
          @c_PickMethod NOT LIKE 'PIECE%'  
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
                SET    DropID = @cToteNo  --               Status = @cStatus  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-10'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
            END  
            ELSE  
            IF @nPickQty > @nQTY_PD  
            BEGIN  
                -- Confirm PickDetail  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  --               Status = @cStatus  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-11'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
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
                    SET @nErrNo = 70424  
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'  
                    GOTO RollBackTran  
                END  
  
                -- Create a new PickDetail to hold the balance  
                INSERT INTO dbo.PICKDETAIL  
                  (  
                    CaseID          ,PickHeaderKey    ,OrderKey  
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
                      ,UOMQTY       ,QTYMoved         ,'4'  
                      ,DropID                ,LOC              ,ID  
                      ,PackKey               ,UpdateSource     ,CartonGroup  
                      ,CartonType            ,ToLoc  ,DoReplenish  
                      ,ReplenishZone         ,DoCartonize      ,PickMethod  
                      ,WaveKey               ,EffectiveDate    ,ArchiveCop  
                      ,ShipFlag              ,PickSlipNo       ,@cNewPickDetailKey  
                      ,@nQTY_PD - @nPickQty  ,NULL             ,'1'  
                      ,@cTaskDetailKey  
                FROM   dbo.PickDetail WITH (NOLOCK)  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                IF @@ERROR <> 0  
                BEGIN  
                    SET @nErrNo = 70422  
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
                    SET @nErrNo = 70425  
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                    GOTO RollBackTran  
                END  
  
                -- Confirm orginal PickDetail with exact QTY  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-12'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
            END  
  
            IF @nPickQty > 0  
            BEGIN  
                SET @nPickQty = @nPickQty- @nQTY_PD -- OffSet PickQty  
            END  
  
            IF @nPickQty = 0 AND 
               @c_PickMethod LIKE 'SINGLES%'  
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
                    -- (james02)
                    IF @c_TMAutoShortPick IN ('', '0', '1') -- (james03)
                    BEGIN
                       UPDATE dbo.PickDetail WITH (ROWLOCK)  
                       SET    STATUS = '4', TrafficCop = NULL, EditWho = sUser_sName(), EditDate = GETDATE()  
                       WHERE  Pickdetailkey = @cPickDetailKeySingle  

                       IF @@ERROR <> 0  
                       BEGIN  
                          SET @nErrNo = 70435  
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                          GOTO RollBackTran  
                       END  
                    END
                    ELSE IF @c_TMAutoShortPick IN ('2', '3')
                    BEGIN
                       -- if @c_TMAutoShortPick = '2' then tote not going to QC for inspection.
                       -- need to unallocate it and set pickdetail.status = '4'
                       UPDATE dbo.PickDetail WITH (ROWLOCK)  
                       SET     Qty = 0 
                       WHERE  Pickdetailkey = @cPickDetailKeySingle  

                       IF @@ERROR <> 0  
                       BEGIN  
                          SET @nErrNo = 70436  
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                          GOTO RollBackTran  
                       END  
                
                       UPDATE dbo.PickDetail WITH (ROWLOCK)  
                       SET    STATUS = '4', EditWho=sUser_sName(), EditDate=GETDATE()  
                       WHERE  Pickdetailkey = @cPickDetailKeySingle  

                       IF @@ERROR <> 0  
                       BEGIN  
                          SET @nErrNo = 70437  
                          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                          GOTO RollBackTran  
                       END  
                    END
                    
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-13'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
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
                    WHILE @@FETCH_STATUS <> -1  
                    BEGIN  
                       -- (james02)
                       IF @c_TMAutoShortPick IN ('', '0', '1') -- (james03)
                       BEGIN
                           UPDATE dbo.PickDetail WITH (ROWLOCK)  
                           SET    STATUS = '4', TrafficCop = NULL, EditWho = sUser_sName(), EditDate = GETDATE()  
                           WHERE  Pickdetailkey = @cPickDetailKeySingle  

                           IF @@ERROR <> 0  
                           BEGIN  
                              SET @nErrNo = 70438  
                              SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                              GOTO RollBackTran  
                           END  
                        END
                        ELSE IF @c_TMAutoShortPick IN ('2', '3')
                        BEGIN
                           -- if @c_TMAutoShortPick = '2' then tote not going to QC for inspection.
                           -- need to unallocate it and set pickdetail.status = '4'
                           UPDATE dbo.PickDetail WITH (ROWLOCK)  
                           SET     Qty = 0 
                           WHERE  Pickdetailkey = @cPickDetailKeySingle  

                           IF @@ERROR <> 0  
                           BEGIN  
                              SET @nErrNo = 70439  
                              SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                              GOTO RollBackTran  
                           END  
                   
                           UPDATE dbo.PickDetail WITH (ROWLOCK)  
                           SET    STATUS = '4', EditWho=sUser_sName(), EditDate=GETDATE()  
                           WHERE  Pickdetailkey = @cPickDetailKeySingle  

                           IF @@ERROR <> 0  
                           BEGIN  
                              SET @nErrNo = 70440  
                              SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                              GOTO RollBackTran  
                           END  
                        END
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
                        ,@cRefNo3=@c_PickMethod  
                        ,@cRefNo4='CFM-14'  
                        ,@cPickSlipno = @cPickSlipno   -- (james04)
  
                    BREAK  
                END  
            END  
            FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT  
        END  
        CLOSE CursorPickDetailShort  
        DEALLOCATE CursorPickDetailShort  
       END  
    END -- @c_TMAutoShortPick = '1'  
    ELSE  
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
            ORDER BY  
                   TD.PickDetailKey  
  
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
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-15'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
            END  
            ELSE  
            IF @nPickQty > @nQTY_PD  
            BEGIN  
                -- Confirm PickDetail  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  --               Status = @cStatus  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-16'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
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
                    SET @nErrNo = 70424  
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
                      ,DropID                 ,LOC                ,ID  
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
                    SET @nErrNo = 70422  
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
                    SET @nErrNo = 70425  
                    SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
                    GOTO RollBackTran  
                END  
  
                -- Confirm orginal PickDetail with exact QTY  
                UPDATE dbo.PickDetail WITH (ROWLOCK)  
                SET    DropID = @cToteNo  
                      ,STATUS = '5'  
                WHERE  PickDetailKey = @cPickDetailKey  
  
                -- SOS# 233330  
                SET @nErrNo = @@ERROR  
                IF @nErrNo <> 0  
                BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  
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
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-17'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
            END  
  
            IF @nPickQty > 0  
            BEGIN  
                SET @nPickQty = @nPickQty - @nQTY_PD -- OffSet PickQty  
            END  
  
            IF @nPickQty = 0 AND 
               @c_PickMethod LIKE 'SINGLES%'  
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
                    ,@nQTY=@nQTY_PD  
                    ,@cRefNo1=@cLoadKey  
                    ,@cRefNo2=@cTaskDetailKey  
                    ,@cRefNo3=@c_PickMethod  
                    ,@cRefNo4='CFM-18'  
                    ,@cPickSlipno = @cPickSlipno   -- (james04)
  
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
                           ,@nQTY=@nQTY_PD  
                           ,@cRefNo1=@cLoadKey  
                           ,@cRefNo2=@cTaskDetailKey  
                           ,@cRefNo3=@c_PickMethod  
                           ,@cRefNo4='CFM-19'  
                           ,@cPickSlipno = @cPickSlipno   -- (james04)
  
                    BREAK  
                END  
            END  
  
            FETCH NEXT FROM CursorPickDetailShort INTO @cPickDetailKey, @nQTY_PD, @cLOT  
        END  
        CLOSE CursorPickDetailShort  
        DEALLOCATE CursorPickDetailShort  
    END  
    GOTO Quit  
  
    RollBackTran:  
    ROLLBACK TRAN TM_Picking_ConfirmTask  
  
    -- SOS# 241911 (Start)  
    SET @cPD_DropId = ''  
    SET @cTD_DropId = ''  
  
    SELECT @cPD_DropId = DropId FROM dbo.PickDetail WITH (NOLOCK)  
    WHERE PickDetailKey = @cPickDetailKey  
  
    SELECT @cTD_DropId = DropId FROM dbo.TaskDetail WITH (NOLOCK)  
    WHERE TaskDetailKey = @cTaskDetailKey  
  
    INSERT INTO dbo.TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5  
                              , Col1, Col2, Col3, Col4, Col5 )  
    VALUES ( 'rdt_TM_PiecePick_ConfirmTask', GetDate(), @nMobile, @cStatus, @cSKU, @cToteNo, @nPickQty  
           , @cPickDetailKey, @cPD_DropId, @cTaskDetailKey, @cTD_DropId, @nErrNo )  
    -- SOS# 241911 (End)  
  
    Quit:  
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
          COMMIT TRAN TM_Picking_ConfirmTask  

    INSERT INTO dbo.TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5  
                              , Col1, Col2, Col3, Col4, Col5 )  
    VALUES ( 'TM_PP_CfmTask', GetDate(), @nMobile, @cStatus, @cSKU, @cToteNo, @nPickQty  
           , @cPickDetailKey, @cPD_DropId, @cTaskDetailKey, @cTD_DropId, @nErrNo )  

END

GO