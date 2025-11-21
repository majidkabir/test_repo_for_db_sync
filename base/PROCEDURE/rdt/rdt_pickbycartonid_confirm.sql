SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PickByCartonID_Confirm                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-03-18  1.0  Ung      WMS-8284 Created                                 */
/* 2019-10-24  1.1  Ung      WMS-10821 Add PickDetail filter                  */
/* 2022-04-04  1.2  Ung      WMS-18892 Wave optional                          */
/*                           Add PickConfirmStatus                            */
/* 2021-11-10  1.3  YeeKung  WMS-18218 Add packconfirm (yeekung01)            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PickByCartonID_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cWaveKey      NVARCHAR( 10),
   @cPWZone       NVARCHAR( 10),
   @cCartonID     NVARCHAR( 20),
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cSKU          NVARCHAR( 20), 
   @cLottable01   NVARCHAR( 18),   
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME, 
   @nQTY          INT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cPickFilter    NVARCHAR( MAX) = ''
   DECLARE @curPD          CURSOR

   SET @nQTY_Bal = @nQTY

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

   -- Loop PickDetail
   SET @cSQL = 
      ' SELECT PD.PickDetailKey, PD.QTY ' + 
      ' FROM dbo.PickDetail PD WITH (NOLOCK)  ' + 
         ' JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT) ' + 
         CASE WHEN @cWaveKey <> '' THEN ' JOIN WaveDetail WD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey) ' ELSE '' END + 
      ' WHERE PD.CaseID = @cCartonID ' + 
         ' AND PD.LOC = @cLOC ' + 
         ' AND PD.ID = @cID ' + 
         ' AND PD.SKU = @cSKU ' + 
         ' AND LA.Lottable01 = @cLottable01 ' + 
         ' AND LA.Lottable02 = @cLottable02 ' + 
         ' AND LA.Lottable03 = @cLottable03 ' + 
         ' AND LA.Lottable04 = @dLottable04 ' + 
         ' AND PD.Status < @cPickConfirmStatus ' + 
         ' AND PD.Status <> ''4'' ' + 
         CASE WHEN @cWaveKey <> '' THEN ' AND WD.WaveKey = @cWaveKey ' ELSE '' END + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
      ' ORDER BY PD.PickDetailKey ' 
         
   -- Open cursor
   SET @cSQL = 
      ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
         @cSQL + 
      ' OPEN @curPD ' 

   SET @cSQLParam = 
      ' @curPD       CURSOR OUTPUT, ' + 
      ' @cWaveKey    NVARCHAR( 10), ' + 
      ' @cCartonID   NVARCHAR( 20), ' + 
      ' @cLOC        NVARCHAR( 10), ' + 
      ' @cID         NVARCHAR( 18), ' +  
      ' @cSKU        NVARCHAR( 20), ' + 
      ' @cLottable01 NVARCHAR( 18), ' + 
      ' @cLottable02 NVARCHAR( 18), ' + 
      ' @cLottable03 NVARCHAR( 18), ' + 
      ' @dLottable04 DATETIME,      ' + 
      ' @cPickConfirmStatus NVARCHAR( 1) '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cWaveKey, @cCartonID, @cLOC, @cID, @cSKU, 
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cPickConfirmStatus

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PickByCartonID_Confirm -- For rollback or commit only our own transaction

   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nQTY_Bal
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail SET 
            Status = @cPickConfirmStatus,
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME() 
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         SET @nQTY_Bal = 0 -- Reduce balance
      END
      
      -- PickDetail have less
      ELSE IF @nQTY_PD < @nQTY_Bal
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail SET 
            Status = @cPickConfirmStatus,
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME() 
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
      END
      
      -- PickDetail have more
      ELSE IF @nQTY_PD > @nQTY_Bal
      BEGIN
         -- Short pick
         IF @nQTY_Bal = 0 -- Don't need to split
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = '4', 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136503
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
               SET @nErrNo = 136504
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetDetKey Fail
               GOTO RollBackTran
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, 
               PickDetailKey, 
               QTY, 
               Status, 
               TrafficCop,
               OptimizeCop)
            SELECT 
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, 
               @cNewPickDetailKey, 
               @nQTY_PD - @nQTY_Bal, -- QTY
               Status, 
               NULL, --TrafficCop,  
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE PickDetailKey = @cPickDetailKey                    
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136505
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
               GOTO RollBackTran
            END

            -- Split RefKeyLookup
            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
            BEGIN
               -- Insert into
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
               FROM RefKeyLookup WITH (NOLOCK) 
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136506
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               QTY = @nQTY_Bal, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136507
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
   
            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = @cPickConfirmStatus,
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136508
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
   
            -- Short remaining balance
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = '4', 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME() 
            WHERE PickDetailKey = @cNewPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136509
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            SET @nQTY_Bal = 0 -- Reduce balance
         END
      END

      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
   END 

   -- Check offset balance
   IF @nQTY_Bal <> 0
   BEGIN
      SET @nErrNo = 136510
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
      GOTO RollBackTran
   END     
   
	DECLARE @nPackConfirm NVARCHAR(1)  

   SET @nPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackCfm', @cStorerkey)   

   IF @nPackConfirm='1'
   BEGIN

      DECLARE @nSumpackQty INT
      DECLARE @nSumpickQty INT
      DECLARE @cpickslipno NVARCHAR(20)
      DECLARE @cPackConfirm NVARCHAR(5)
   
      SELECT @cpickslipno=PH.PickHeaderKey
      FROM WaveDetail WD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
      JOIN dbo.PICKHEADER PH (NOLOCK) ON PH.PickHeaderKey=pd.PickSlipNo
      WHERE wd.WaveKey=@cWaveKey

      SELECT @nSumpackQty= SUM(qty)
      FROM packdetail (NOLOCK)
      WHERE PickSlipNo=@cpickslipno

      IF EXISTS(SELECT 1
               FROM WaveDetail WD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)  
               JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) 
               WHERE WD.WaveKey = @cWaveKey 
                  AND PD.Status < '5' )
         SET @cPackConfirm='N'
      ELSE 
         SET @cPackConfirm = 'Y' 

      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nSumpickQty=SUM(pd.Qty)
         FROM dbo.PICKHEADER PH (NOLOCK) 
			JOIN dbo.PickDetail PD WITH (NOLOCK) ON PH.PickHeaderKey=pd.PickSlipNo 
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) 
         WHERE PH.Pickheaderkey=@cPickslipNo
            AND PD.Status = '5' 
           
         IF @nSumpickQty <> @nSumpackQty  
            SET @cPackConfirm = 'N'  
      END  


      IF @cPackConfirm = 'Y'  
      BEGIN  

         UPDATE dbo.PackHeader WITH (ROWLOCK) SET   
            [Status] = '9'  
         WHERE PickSlipNo = @cPickSlipNo  
         AND   [Status] < '9'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 136511  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail  
            GOTO RollBackTran  
         END  
  
         SET @nErrNo = 0  
         EXEC isp_ScanOutPickSlip  
            @c_PickSlipNo  = @cPickSlipNo,  
            @n_err         = @nErrNo OUTPUT,  
            @c_errmsg      = @cErrMsg OUTPUT  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 136512  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Out Fail  
            GOTO RollBackTran  
         END  
      END  
   END
 
   COMMIT TRAN rdt_PickByCartonID_Confirm
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
      
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cSKU          = @cSKU,
      @nQTY          = @nQTY,
      @cLottable01   = @cLottable01,   
      @cLottable02   = @cLottable02, 
      @cLottable03   = @cLottable03, 
      @dLottable04   = @dLottable04, 
      @cLocation     = @cLOC,
      @cCaseID       = @cCartonID

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PickByCartonID_Confirm
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO