SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Pick_SwapLot_ConfirmTask                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Confirm Picking                                             */
/*                                                                      */
/* Called from: rdtfnc_Pick_SwapLot                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-Dec-2008 1.0  James       Created                                 */
/* 01-Apr-2009 1.1  James       Added support for conso pickslip        */
/* 29-May-2009 1.2  Shong       Fixing Bugs                             */
/* 03-Apr-2014 1.3  Ung         SOS306868 Add DropID.                   */
/* 31-Dec-2014 1.4  James       SOS326026 - Add EventLog (james01)      */
/************************************************************************/

CREATE PROC [RDT].[rdt_Pick_SwapLot_ConfirmTask] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 15),
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
--   @cOrderKey NVARCHAR( 10),  --Support for conso pickslip, hence no need orderkey
   @cSKU        NVARCHAR( 20),
   @cPickSlipNo NVARCHAR( 10),
   @cLOT        NVARCHAR( 10),
   @cLOC        NVARCHAR( 10), 
   @cID         NVARCHAR( 18),
   @nQTY        INT,
   @cStatus     NVARCHAR( 1), -- 3=In-Progress, 5=Picked
   @cDropID     NVARCHAR( 20), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT,
      @nQTY_Bal         INT,
      @nQTY_PD          INT,
      @cPickDetailKey   NVARCHAR( 10),
      @b_success        INT,
      @n_err            INT,
      @c_errmsg         NVARCHAR( 250),
      @cOrderLineNumber NVARCHAR( 5),
      @cLoadKey         NVARCHAR( 10),
      @cOrderKey        NVARCHAR( 10), 
      @cUOM             NVARCHAR( 10)  -- (james01)

   -- TraceInfo
   DECLARE    @c_starttime    datetime,
              @c_endtime      datetime,
              @c_step1        datetime,
              @c_step2        datetime,
              @c_step3        datetime,
              @c_step4        datetime,
              @c_step5        datetime, 
              @c_Col5         NVARCHAR(20)

   SET @c_starttime = getdate()         
   SET @c_Col5 = CONVERT(varchar(20), @nQTY)

   SET @nTranCount = @@TRANCOUNT
     

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Pick_SwapLot_ConfirmTask -- For rollback or commit only our own transaction

   /*-------------------------------------------------------------------------------

                                     PickDetail

   -------------------------------------------------------------------------------*/
   -- For calculation

   -- (james01) 
   SELECT @cUOM = RTRIM(PACK.PACKUOM3)
   FROM dbo.PACK PACK WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE SKU.Storerkey = @cStorerKey
   AND   SKU.SKU = @cSKU

   SELECT TOP 1 @cLoadKey = LPD.LoadKey 
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE PD.StorerKey  = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.LOT = @cLOT
      AND PD.LOC = @cLOC
      AND PD.ID  = @cID -- Added By SHONG On 29th May 2009
      AND PD.Status = '0' 
      AND PD.QTY > 0
      AND PD.PickSlipNo = @cPickSlipNo
      
   SET @nQTY_Bal = @nQTY
   SET @c_step1 = GETDATE()
   SET @c_step2 = GETDATE()
   SET @c_step3 = GETDATE()

   -- Get PickDetail candidate
   DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT PickDetailKey, QTY
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE StorerKey  = @cStorerKey
      AND SKU = @cSKU
      AND LOT = @cLOT
      AND LOC = @cLOC
      AND ID  = @cID -- Added By SHONG On 29th May 2009
      AND Status = '0' 
      AND PD.QTY > 0
      AND PickSlipNo = @cPickSlipNo
   ORDER BY PD.PickDetailKey

   OPEN curPD
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD 
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nQTY_Bal
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Status = @cStatus, 
            DropID = @cDropID
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66126
            SET @cErrMsg = rdt.rdtgetmessage( 66126, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            -- EventLog - QTY
            EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cID,
              @cSKU          = @cSKU,
              @cUOM          = @cUOM,
              @nQTY          = @nQty,
              @cLot          = @cLOT,
              @cDropID       = @cDropID, 
              @cPickSlipNo   = @cPickSlipNo,   
              @cLoadKey      = @cLoadKey      
         END

         SET @nQTY_Bal = 0 -- Reduce balance
         SET @c_step1 = GETDATE() - @c_step1
      END
      ELSE IF @nQTY_PD < @nQTY_Bal -- PickDetail have less
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Status = @cStatus, 
            DropID = @cDropID
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66127
            SET @cErrMsg = rdt.rdtgetmessage( 11267, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            -- EventLog - QTY
            EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cID,
              @cSKU          = @cSKU,
              @cUOM          = @cUOM,
              @nQTY          = @nQty,
              @cLot          = @cLOT,
              @cDropID       = @cDropID, 
              @cPickSlipNo   = @cPickSlipNo,         
              @cLoadKey      = @cLoadKey      
         END
         
         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
         SET @c_step2 = GETDATE() - @c_step2
      END
      ELSE IF @nQTY_PD > @nQTY_Bal -- PickDetail have more, need to split
      BEGIN
         -- Get new PickDetailkey
         DECLARE @cNewPickDetailKey NVARCHAR( 10)
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY', 
            10 ,
            @cNewPickDetailKey OUTPUT,
            @b_success         OUTPUT,
            @n_err             OUTPUT,
            @c_errmsg          OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 66128
            SET @cErrMsg = rdt.rdtgetmessage( 66128, @cLangCode, 'DSP') -- 'GetDetKey Fail'
            GOTO RollBackTran
         END

         -- Create new a PickDetail to hold the balance
         INSERT INTO dbo.PICKDETAIL (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
            QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
            DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
            ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop)
         SELECT 
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
            QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotCfmA', ToLoc, 
            DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
            ShipFlag, PickSlipNo, @cNewPickDetailKey, @nQTY_PD - @nQTY_Bal, NULL, '1'
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE PickDetailKey = @cPickDetailKey
            
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66129
            SET @cErrMsg = rdt.rdtgetmessage( 66129, @cLangCode, 'DSP') --'Ins PDtl Fail'
            GOTO RollBackTran
         END

         IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo) 
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cNewPickDetailKey)  
            BEGIN
               SELECT 
                  @cOrderKey = OrderKey,
                  @cOrderLineNumber = OrderLineNumber 
               FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE PickDetailKey = @cPickDetailKey

               SELECT @cLoadKey = ExternOrderKey
               FROM dbo.PickHeader WITH (NOLOCK) 
                  WHERE PickHeaderKey = @cPickSlipNo

               INSERT INTO dbo.RefkeyLookup (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
               VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66132
                  SET @cErrMsg = rdt.rdtgetmessage( 66132, @cLangCode, 'DSP') --'InsRefKLupFail'
                  GOTO RollBackTran
               END
            END
         END
               
         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            QTY = @nQTY_Bal, 
            Trafficcop = NULL, CartonType = 'SwpLotCfmU', 
            EditDate=GetDate(), EditWho=sUser_sName()
         WHERE PickDetailKey = @cPickDetailKey
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66130
            SET @cErrMsg = rdt.rdtgetmessage( 66130, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END

         -- Confirm orginal PickDetail with exact QTY
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Status = @cStatus, 
            DropID = @cDropID
         WHERE PickDetailKey = @cPickDetailKey
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66131
            SET @cErrMsg = rdt.rdtgetmessage( 66131, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            -- EventLog - QTY
            EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cID,
              @cSKU          = @cSKU,
              @cUOM          = @cUOM,
              @nQTY          = @nQty,
              @cLot          = @cLOT,
              @cDropID       = @cDropID, 
              @cPickSlipNo   = @cPickSlipNo,         
              @cLoadKey      = @cLoadKey      
         END

         SET @nQTY_Bal = 0 -- Reduce balance
         SET @c_step3 = GETDATE() - @c_step3
      END
      
      IF @nQTY_Bal = 0 BREAK -- Exit

      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD 
   END 
   CLOSE curPD
   DEALLOCATE curPD 
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Pick_SwapLot_ConfirmTask
Fail:
Quit:
   SET @c_endtime = GETDATE()

   INSERT INTO TraceInfo 
     ([TraceName]     ,[TimeIn]     ,[TimeOut]
     ,[TotalTime]     ,[Step1]      ,[Step2]
     ,[Step3]         ,[Step4]      ,[Step5]
     ,[Col1]          ,[Col2]       ,[Col3]
     ,[Col4]          ,[Col5])

   VALUES
      ('rdt_Pick_SwapLot_ConfirmTask PickSlip No = ' + @cPickSlipNo 
        , @c_starttime, @c_endtime 
      ,CONVERT(CHAR(12),@c_endtime-@c_starttime ,114) 
      ,ISNULL(CONVERT(CHAR(12),@c_step1,114), '00:00:00:000') 
      ,ISNULL(CONVERT(CHAR(12),@c_step2,114), '00:00:00:000')  
      ,ISNULL(CONVERT(CHAR(12),@c_step3,114), '00:00:00:000')  
      ,ISNULL(CONVERT(CHAR(12),@c_step4,114), '00:00:00:000')  
      ,ISNULL(CONVERT(CHAR(12),@c_step5,114), '00:00:00:000')
      , @cSKU
      , @cLOT
      , @cLOC 
      , @cID
      , @c_Col5 )

   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN 
END



GO