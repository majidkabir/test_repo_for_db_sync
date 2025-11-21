SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/      
/* Store procedure: rdt_866ConfirmSP01                                        */      
/* Copyright      : LF Logistics                                              */      
/*                                                                            */      
/* Purpose: Comfirm pick with swap lot                                        */      
/*                                                                            */      
/* Date       Rev  Author   Purposes                                          */      
/* 2017-01-25 1.0  Ung      WMS-1000 Temporary modify for urgent release      */   
/******************************************************************************/      
      
CREATE PROC [RDT].[rdt_866ConfirmSP01] (    
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20), 
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME, 
   @nQTY         INT,           
   @cType        NVARCHAR(1),   -- 4=Short, 5=Picked
   @nErrNo       INT           OUTPUT,  
   @cErrMsg      NVARCHAR(250) OUTPUT  
 )        
AS        
BEGIN    
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
    
   DECLARE @nTranCount        INT
   DECLARE @bSuccess          INT
   DECLARE @cOrderKey         NVARCHAR(10)
   DECLARE @cPickDetailKey    NVARCHAR(10)
   DECLARE @cOtherPickDetailKey NVARCHAR(10)
   DECLARE @cLottable02Label  NVARCHAR(20)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cOtherLOT         NVARCHAR(10)
   DECLARE @nQTY_PD           INT
   DECLARE @nQTY_Bal          INT
   
   SET @nTranCount = @@TRANCOUNT
   SET @cPickDetailKey = ''
   SET @cOtherPickDetailKey = ''
   SET @cLOT = ''
   SET @cOtherLOT = ''
   
   -- Get Pick slip info
   SELECT @cOrderKey = OrderKey FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo

   -- Get SKU info
   SELECT @cLottable02Label = Lottable02Label FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_866ConfirmSP01 -- For rollback or commit only our own transaction   


   /***********************************************************************************************
   
                                            Serial No stock (can swap)
   
   ***********************************************************************************************/
   IF @cLottable02Label = 'SERIALNO'
   BEGIN
      IF @nQTY <> 1
      BEGIN
         SET @nErrNo = 105751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         GOTO Quit
      END

      /***********************************************************************************************
                                             Find in current order
      ***********************************************************************************************/
      SELECT 
         @cPickDetailKey = PD.PickDetailKey
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.LOC = @cLOC
         AND PD.SKU = @cSKU
         AND PD.Status < '4' -- Short
         AND PD.QTY = 1
         AND LA.Lottable02 = @cLottable02
      
      IF @cPickDetailKey <> ''
      BEGIN
         UPDATE PickDetail SET
            Status = '5', 
            DropID = @cDropID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         GOTO Quit
      END
   
      /***********************************************************************************************
                                                Find in other order
      ***********************************************************************************************/
      -- Get random in current order
      SELECT TOP 1 
         @cPickDetailKey = PD.PickDetailKey,
         @cLOT = PD.LOT
      FROM PickDetail PD WITH (NOLOCK) 
      WHERE PD.OrderKey = @cOrderKey
         AND PD.LOC = @cLOC
         AND PD.SKU = @cSKU
         AND PD.Status < '4' -- Short
         AND PD.QTY = 1
      
      -- Check PickDetail
      IF @cPickDetailKey = ''
      BEGIN
         SET @nErrNo = 105753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more PKDtl
         GOTO RollBackTran
      END
         
      -- Find in other order
      SELECT 
         @cOtherPickDetailKey = PD.PickDetailKey, 
         @cOtherLOT = PD.LOT
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.LOC = @cLOC
         AND PD.SKU = @cSKU
         AND PD.Status < '4' -- Short
         AND PD.QTY = 1
         AND LA.Lottable02 = @cLottable02
            
      -- Swap LOT
      IF @cPickDetailKey <> '' AND @cOtherPickDetailKey <> ''
      BEGIN
         -- Current order
         UPDATE PickDetail SET
            LOT = @cOtherLOT, 
            DropID = @cDropID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
   
         -- Other order
         UPDATE PickDetail SET
            LOT = @cLOT, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cOtherPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- Pick confirm
      IF @cPickDetailKey <> '' AND @cOtherPickDetailKey <> ''
      BEGIN
         -- Current order
         UPDATE PickDetail SET
            Status = '5', 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         GOTO Quit
      END
   
      /***********************************************************************************************
                                              Find not allocated LOT
      ***********************************************************************************************/
      SELECT @cOtherLOT = LLI.LOT 
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.LOC = @cLOC
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LA.Lottable02 = @cLottable02
         AND LLI.QTY-LLI.QTYAllocated-QTYPicked > 0
   
      -- Check L02 valid
      IF @cOtherLOT = ''
      BEGIN
         SET @nErrNo = 105758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid L02
         GOTO RollBackTran
      END  
         
      -- Swap LOT, pick confirm
      IF @cPickDetailKey <> '' AND @cOtherLOT <> ''
      BEGIN
         -- Current order
         UPDATE PickDetail SET
            LOT = @cOtherLOT, 
            DropID = @cDropID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105759
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END   
      
         -- Current order
         UPDATE PickDetail SET
            Status = '5', 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         GOTO Quit
      END
   END
   
   
   /***********************************************************************************************
   
                                      Non serial no stock (cannot swap)
   
   ***********************************************************************************************/
   IF @cLottable02Label <> 'SERIALNO'
   BEGIN
      -- For calculation
      SET @nQTY_Bal = @nQTY
   
      -- Get PickDetail candidate
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PickDetailKey, QTY
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         WHERE O.OrderKey = @cOrderKey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = '5',
               DropID = @cDropID, 
               EditDate = GETDATE(), 
               EditWho  = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 105761
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
   
            SET @nQTY_Bal = 0 -- Reduce balance
         END
         
         -- PickDetail have less
   		ELSE IF @nQTY_PD < @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               Status = '5',
               DropID = @cDropID, 
               EditDate = GETDATE(), 
               EditWho  = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 105762
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
   
            SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
         END
         
         -- PickDetail have more
   		ELSE IF @nQTY_PD > @nQTY_Bal
         BEGIN
            -- Short pick
            IF @cType = '4' AND @nQTY_Bal = 0 -- Don't need to split
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                  Status = '4',
                  DropID = @cDropID, 
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME(),
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 105763
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
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
                  SET @nErrNo = 105764
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
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
      				SET @nErrNo = 105765
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
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
                     SET @nErrNo = 105766
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                     GOTO RollBackTran
                  END
               END
               
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                  QTY = @nQTY_Bal, 
                  DropID = @cDropID, 
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME(), 
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey 
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 105767
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               -- Confirm orginal PickDetail with exact QTY
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                  Status = '5',
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME() 
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 105768
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               SET @nQTY_Bal = 0 -- Reduce balance
            END
         END
   
         -- Exit condition
         IF @nQTY_Bal = 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
      END 
   


   END

   COMMIT TRAN rdt_866ConfirmSP01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_866ConfirmSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END        


GO