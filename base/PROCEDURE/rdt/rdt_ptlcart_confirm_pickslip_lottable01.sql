SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm_PickSlip_Lottable01             */
/* Copyright      : LF Logistics                                        */
/*                Confirm_PickSlip_Lottable->Confirm_PickSlip_Lottable01*/
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 21-05-2021 1.0  yeekung  WMS-17002 Created                           */
/* 28-12-2021 1.1  YeeKung  WMS-18463 Group by lot (yeekung01)			   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLCart_Confirm_PickSlip_Lottable01] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR(5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10) -- LOC = confirm LOC, CLOSETOTE/SHORTTOTE = confirm tote
   ,@cDPLKey         NVARCHAR( 10)
   ,@cCartID         NVARCHAR( 10) 
   ,@cToteID         NVARCHAR( 20) -- Required for confirm tote
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cNewToteID      NVARCHAR( 20) -- For close tote with balance
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@cLottableCode   NVARCHAR( 30) 
   ,@cLottable01     NVARCHAR( 18)  
   ,@cLottable02     NVARCHAR( 18)  
   ,@cLottable03     NVARCHAR( 18)  
   ,@dLottable04     DATETIME  
   ,@dLottable05     DATETIME  
   ,@cLottable06     NVARCHAR( 30) 
   ,@cLottable07     NVARCHAR( 30) 
   ,@cLottable08     NVARCHAR( 30) 
   ,@cLottable09     NVARCHAR( 30) 
   ,@cLottable10     NVARCHAR( 30) 
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActToteID     NVARCHAR( 20)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cPSType        NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)

   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cUpdatePickDetail    NVARCHAR( 1)
   DECLARE @cShortPickType       NVARCHAR( 1)
   DECLARE @cShortStatus         NVARCHAR( 1)
   DECLARE @cAutoScanOut         NVARCHAR( 1)
   DECLARE @nToScanOut           INT
   DECLARE @cPickZone            NVARCHAR( 10)
   DECLARE @cPickSlipNo2ScanOut  NVARCHAR( 10) = ''
   DECLARE @cTemp_OrderKey       NVARCHAR( 10) = ''
   DECLARE @cTemp_LoadKey        NVARCHAR( 10) = ''
   DECLARE @cM_PickSlipNo        NVARCHAR( 10) = ''
   DECLARE @cInsertDropID        NVARCHAR( 1)      --(cc01)
   DECLARE @cDropIDType          NVARCHAR( 10)      --(cc01)
   DECLARE @cPTLCartAllowReuseDropID   NVARCHAR( 1)      --(cc01)
   DECLARE @cLOT                 NVARCHAR(20)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   -- Get storer config
   SET @cShortPickType = rdt.rdtGetConfig( @nFunc, 'ShortPickType', @cStorerKey)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress
      SET @cPickConfirmStatus = '5'  -- 5=Pick confirm

   SET @cAutoScanOut = rdt.rdtGetConfig( @nFunc, 'AutoScanOut', @cStorerKey)
   
   --(cc01)
   SET @cInsertDropID = rdt.rdtGetConfig( @nFunc, 'InsertDropID', @cStorerKey)
   SET @cPTLCartAllowReuseDropID = rdt.rdtGetConfig( @nFunc, 'PTLCartAllowReuseDropID', @cStorerKey)
   

   -- Short pick type
   SET @cShortStatus = '4'
   IF @cShortPickType = '1'  -- Not allow
   BEGIN
      IF @cType = 'SHORTTOTE'
      BEGIN
         SET @nErrNo = 168151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Short NotAllow
         GOTO Quit
      END      
      SET @cShortStatus = '0'
   END
   IF @cShortPickType = '2' -- Balance pick later
      SET @cShortStatus = '0'

   SELECT @cPickZone = V_String2
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nQTY_Bal = @nQTY

   /***********************************************************************************************

                                                CONFIRM LOC 

   ***********************************************************************************************/
   IF @cType = 'LOC' 
   BEGIN
      -- Confirm entire LOC
      /*
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND Status <> '9'
      */
      SET @cSQL = 
         ' SELECT PTLKey, DevicePosition, ExpectedQTY, SourceKey,@cLottable02,@dLottable04,LOT ' + 
         ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
         ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
            ' AND LOC = @cLOC ' + 
            ' AND SKU = @cSKU ' + 
            ' AND Status <> ''9'' '
            
      EXEC rdt.rdt_PTLCart_Confirm_PickSlip_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
         @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, @cLot,
         @curPTL OUTPUT
         
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cPickSlipNo,@cLottable02,@dLottable04,@cLOT
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get tote
         SELECT @cActToteID = ToteID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND Position = @cPosition
         
         -- Transaction at order level
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLCart_Confirm -- For rollback or commit only our own transaction
         
         -- Confirm PTLTran
         UPDATE PTL.PTLTran SET
            Status = '9', 
            QTY = ExpectedQTY, 
            DropID = @cActToteID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 168152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END
         
         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN

            DECLARE @cPickinProcess NVARCHAR(20)
            SET @cPSType = ''

            Select @cPickinProcess = Max(CL.UDF03)
            FROM Orders O(Nolock)  LEFT Join CODELKUP CL(Nolock) On (O.Stop = CL.Code)
            JOIN PickHeader PH(Nolock)
            On PH.Orderkey = O.Orderkey
            WHERE CL.Listname = 'LORBRD' 
               AND PH.PickHeaderKey = @cPickSlipNo
    
            If @cPickinProcess = 'PickInProcess' 
            Begin
               Set @cPickConfirmStatus = '3' 
            End
            Else 
            Begin
               Set @cPickConfirmStatus = '5'
            End
 
            -- Get PickHeader info
            SELECT 
               @cZone = Zone, 
               @cOrderKey = ISNULL( OrderKey, ''), 
               @cLoadKey = ExternOrderKey
            FROM PickHeader WITH (NOLOCK) 
            WHERE PickHeaderKey = @cPickSlipNo
            
            IF @@ROWCOUNT = 0
               SET @cPSType = 'CUSTOM'
            
            IF @cPSType = ''
            BEGIN
               -- Get PickSlip type
               IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                  SET @cPSType = 'XD'
               ELSE IF @cOrderKey = ''
                  SET @cPSType = 'CONSO'
               ELSE
                  SET @cPSType = 'DISCRETE'
            END

            -- Check PickDetail tally PTLTran
            IF @cPSType = 'DISCRETE'
               SELECT top 1 @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON ( LA.Lot=PD.Lot)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND LA.Lot = @cLOT
                  AND O.SOStatus <> 'CANC'
               GROUP BY PD.LOT,Lottable02,Lottable04
            
            IF @cPSType = 'CONSO'
               SELECT top 1 @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
               FROM LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON ( LA.Lot=PD.Lot)
               WHERE LPD.Loadkey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
                  AND LA.Lottable02 = @cLottable02
                  AND La.Lottable04 = @dLottable04
                  AND LA.Lot = @cLOT
               GROUP BY PD.LOT,Lottable02,Lottable04
   
            IF @cPSType = 'XD'
               SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON ( LA.Lot=PD.Lot)
               WHERE RKL.PickslipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
                  AND LA.Lottable02 = @cLottable02
                  AND La.Lottable04 = @dLottable04
                  AND LA.Lot = @cLOT
               GROUP BY PD.LOT,Lottable02,Lottable04

            IF @cPSType = 'CUSTOM'
               SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON ( LA.Lot=PD.Lot)
               WHERE PD.PickslipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
                  AND LA.Lottable02 = @cLottable02
                  AND La.Lottable04 = @dLottable04
                  AND LA.Lot = @cLOT
               GROUP BY PD.LOT,Lottable02,Lottable04

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 168153
               SET @cErrMsg = @nQTY_PD--@nExpectedQTY--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- Loop PickDetail
            IF @cPSType = 'DISCRETE'
               SET @cSQL = 
                  ' SELECT PD.PickDetailKey ' + 
                  ' FROM Orders O WITH (NOLOCK) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                     ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                  ' WHERE O.OrderKey = @cOrderKey ' + 
                     ' AND PD.StorerKey = @cStorerKey ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.LOC = @cLOC ' + 
                     ' AND PD.Status < @cPickConfirmStatus ' + 
                     ' AND PD.Status <> ''4''  ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND LA.Lot = @cLOT' +
                     ' AND O.Status <> ''CANC'' ' +  
                     ' AND O.SOStatus <> ''CANC'' '
            
            IF @cPSType = 'CONSO'
               SET @cSQL = 
                  ' SELECT PD.PickDetailKey ' + 
                  ' FROM LoadPlanDetail LPD WITH (NOLOCK) ' + 
                     ' JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                     ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                  ' WHERE LPD.Loadkey = @cLoadKey ' + 
                     ' AND PD.StorerKey = @cStorerKey ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.LOC = @cLOC ' + 
                     ' AND PD.Status < @cPickConfirmStatus ' + 
                     ' AND PD.Status <> ''4''  ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND LA.Lot = @cLOT' +
                     ' AND O.Status <> ''CANC'' ' +  
                     ' AND O.SOStatus <> ''CANC'' '
   
            IF @cPSType = 'XD'
               SET @cSQL = 
                  ' SELECT PD.PickDetailKey ' + 
                  ' FROM Orders O WITH (NOLOCK) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                     ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' + 
                  ' WHERE RKL.PickslipNo = @cPickSlipNo ' + 
                     ' AND PD.StorerKey = @cStorerKey ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.LOC = @cLOC ' + 
                     ' AND PD.Status < @cPickConfirmStatus ' + 
                     ' AND PD.Status <> ''4''  ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND LA.Lot = @cLOT' +
                     ' AND O.Status <> ''CANC'' ' +  
                     ' AND O.SOStatus <> ''CANC'' '

            IF @cPSType = 'CUSTOM'
               SET @cSQL = 
                  ' SELECT PD.PickDetailKey ' + 
                  ' FROM Orders O WITH (NOLOCK) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                     ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                  ' WHERE PD.PickslipNo = @cPickSlipNo ' + 
                     ' AND PD.StorerKey = @cStorerKey ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.LOC = @cLOC ' + 
                     ' AND PD.Status < @cPickConfirmStatus ' + 
                     ' AND PD.Status <> ''4''  ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND LA.Lot = @cLOT' +
                     ' AND O.Status <> ''CANC'' ' +  
                     ' AND O.SOStatus <> ''CANC'' '

            IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
               DEALLOCATE @curPD

            EXEC rdt.rdt_PTLCart_Confirm_PickSlip_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
               @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, @cLot,
               @curPD OUTPUT

            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Confirm PickDetail
               UPDATE PickDetail WITH (ROWLOCK) SET
                  Status = @cPickConfirmStatus, 
                  DropID = @cActToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168154
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END            
         END
         
         --(cc01) --01
         IF @cInsertDropID = '1'
         BEGIN
         	SET @cPSType = ''

            -- Get PickHeader info
            SELECT 
               @cZone = Zone, 
               @cOrderKey = ISNULL( OrderKey, ''), 
               @cLoadKey = ExternOrderKey
            FROM PickHeader WITH (NOLOCK) 
            WHERE PickHeaderKey = @cPickSlipNo
            
            IF @@ROWCOUNT = 0
               SET @cPSType = 'CUSTOM'
            
            IF @cPSType = ''
            BEGIN
               -- Get PickSlip type
               IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                  SET @cPSType = 'XD'
               ELSE IF @cOrderKey = ''
                  SET @cPSType = 'CONSO'
               ELSE
                  SET @cPSType = 'DISCRETE'
            END

            -- Get Orderkey type
            IF @cPSType = 'CONSO'
               SELECT @cOrderKey = O.OrderKey
               FROM LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE LPD.Loadkey = @cLoadKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status = @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
   
            IF @cPSType = 'XD'
               SELECT @cOrderKey = O.OrderKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
               WHERE RKL.PickslipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status = @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'

            IF @cPSType = 'CUSTOM'
               SELECT @cOrderKey = O.OrderKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE PD.PickslipNo = @cPickSlipNo
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND PD.LOC = @cLOC
                  AND PD.Status = @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
                  
            IF @cOrderKey <> ''
            BEGIN
               SELECT @cDropIDType =     
               CASE WHEN ISNULL( SUM( Qty), 0) = 1 THEN 'SINGLES'     
                  WHEN ISNULL( SUM( Qty), 0) > 1 THEN 'MULTIS'     
                  ELSE '' END    
               FROM dbo.PickDetail WITH (NOLOCK)     
               WHERE StorerKey = @cStorerkey    
                     AND OrderKey = @cOrderKey    
                     
               IF ISNULL(@cLoadKey,'') = ''
               BEGIN
               	SELECT @cLoadKey = LoadKey FROM orders WITH (NOLOCK) WHERE storerKey = @cStorerKey AND orderKey = @cOrderKey
               END
               
               IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                          WHERE DropID = @cActToteID   
                          --AND   [Status] = '0'
                           )
               BEGIN
               	IF @cPTLCartAllowReuseDropID = '1 '
                  BEGIN
               	   -- Delete existing dropiddetail  
                     DELETE FROM dbo.DropIDDetail    
                     WHERE DropID = @cActToteID   
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 168155  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'  
                        GOTO RollBackTran  
                     END  
  
                     -- Delete existing dropid  
                     DELETE FROM dbo.DropID   
                     WHERE DropID = @cActToteID   
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 168156  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'  
                        GOTO RollBackTran  
                     END 
                  END
                  ELSE  
                  BEGIN  
                     SET @nErrNo = 168157  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'  
                     GOTO RollBackTran  
                  END  
               END

              	INSERT INTO dbo.DropID   
               (DropID, DropIDType, LabelPrinted, [Status], PickSlipNo, LoadKey)  
               VALUES   
               (@cActToteID, @cDropIDType, '0', '5', @cPickSlipNo, @cLoadKey) 
               
              	IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 168158  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'  
                  GOTO RollBackTran  
               END  
              	
              	INSERT INTO dbo.DropIDDetail (DropID, ChildID)  
               VALUES (@cActToteID, @cOrderKey)
              	
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 168159  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'  
                  GOTO RollBackTran  
               END  
            END
         END

         -- EventLog -- (james01) 
         EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', -- Sign-in  
           @nMobileNo   = @nMobile,  
           @nFunctionID = @nFunc,  
           @nStep       = @nStep,
           @cFacility   = @cFacility,  
           @cStorerKey  = @cStorerkey,    
           @cSKU        = @cSKU,
           @nQty        = @nExpectedQTY,
           @cDropID     = @cActToteID,
           @cLocation   = @cLoc,
           @cPickSlipNo = @cPickSlipNo,
           @cDeviceID   = @cCartID,
           @cDevicePosition = @cPosition,
           @cPickZone   = @cPickZone,
           @cLoadKey    = @cLoadKey,
           @nExpectedQTY = @nQTY_PD

         -- Commit order level
         COMMIT TRAN rdt_PTLCart_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cPickSlipNo,@cLottable02,@dLottable04,@cLOT
      END
   END


   /***********************************************************************************************

                                                CONFIRM TOTE 

   ***********************************************************************************************/
   -- Confirm tote
   IF @cType <> 'LOC'
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PTLCart_Confirm -- For rollback or commit only our own transaction
      
      -- Close with QTY or short 
      IF (@cType = 'CLOSETOTE' AND @nQTY > 0) OR
         (@cType = 'SHORTTOTE')
      BEGIN
         -- Get tote info
         SELECT 
            @cPosition = Position, 
            @cPickSlipNo = PickSlipNo
         FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
         WHERE CartID = @cCartID 
            AND ToteID = @cToteID

         DECLARE @cPDLOT NVARCHAR(20)
         SET @nExpectedQTY = NULL

         -- PTLTran
         SET @cSQL = 
            ' SELECT PTLKey, ExpectedQTY,LOT ' + 
            ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
            ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
               ' AND LOC = @cLOC ' + 
               ' AND SKU = @cSKU ' + 
               ' AND DevicePosition = @cPosition ' + 
               ' AND Status <> ''9'' '
         
         EXEC rdt.rdt_PTLCart_Confirm_PickSlip_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
            @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,@cLOT,
            @curPTL OUTPUT

         FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL,@cLOT
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @nExpectedQTY = @nQTY_PTL

            -- Exact match
            IF @nQTY_PTL = @nQTY_Bal
            BEGIN
               -- Confirm PTLTran
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                  Status = '9', 
                  QTY = ExpectedQTY, 
                  DropID = @cToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168160
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
            END
            
            -- PTLTran have less
      		ELSE IF @nQTY_PTL < @nQTY_Bal
            BEGIN
               -- Confirm PickDetail
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                  Status = '9',
                  QTY = ExpectedQTY, 
                  DropID = @cToteID, 
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168161
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                  GOTO RollBackTran
               END
            END
            
            -- PTLTran have more
      		ELSE IF @nQTY_PTL > @nQTY_Bal
            BEGIN
               -- Short pick
               IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split
               BEGIN
                  -- Confirm PTLTran
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     QTY = 0, 
                     DropID = @cToteID, 
                     TrafficCop = NULL, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 168162
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END

               END
               ELSE
               BEGIN -- Have balance, need to split
                  -- Create new a PTLTran to hold the balance
                  INSERT INTO PTL.PTLTran (
                     ExpectedQty, QTY, TrafficCop, 
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, DropID, OrderKey, Storerkey, SKU, LOC, LOT, Remarks, 
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey, 
                     Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                     Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                     Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
                  SELECT 
                     @nQTY_PTL - @nQTY_Bal, @nQTY_PTL - @nQTY_Bal, NULL, 
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, '', OrderKey, Storerkey, SKU, LOC, LOT, Remarks, 
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey, 
                     Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                     Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                     Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 168163
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail
                     GOTO RollBackTran
                  END
         
                  -- Confirm orginal PTLTran with exact QTY
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     ExpectedQty = @nQTY_Bal, 
                     QTY = @nQTY_Bal, 
                     DropID = @cToteID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME(), 
                     Trafficcop = NULL
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 168164
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END

               END
            END

                     -- PickDetail
            IF @cUpdatePickDetail = '1'
            BEGIN
               SET @cPSType = ''

               -- Get PickHeader info
               SELECT 
                  @cZone = Zone, 
                  @cOrderKey = ISNULL( OrderKey, ''), 
                  @cLoadKey = ExternOrderKey
               FROM PickHeader WITH (NOLOCK) 
               WHERE PickHeaderKey = @cPickSlipNo

               IF @@ROWCOUNT = 0
                  SET @cPSType = 'CUSTOM'

               IF @cPSType = ''
               BEGIN
                  -- Get PickSlip type
                  IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                     SET @cPSType = 'XD'
                  ELSE IF @cOrderKey = ''
                     SET @cPSType = 'CONSO'
                  ELSE
                     SET @cPSType = 'DISCRETE'
               END

               -- Check PickDetail tally PTLTran
               IF @cPSType = 'DISCRETE'
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.OrderKey = @cOrderKey
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.Lot = @cLot
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
            
               IF @cPSType = 'CONSO'
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE LPD.Loadkey = @cLoadKey
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND PD.Lot = @cLot
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
   
               IF @cPSType = 'XD'
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                  WHERE RKL.PickslipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND PD.Lot = @cLot
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'

               IF @cPSType = 'CUSTOM'
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE PD.PickslipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND PD.Lot = @cLot
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'

               IF @nQTY_PD <> @nExpectedQTY AND @nQTY_Bal<>0
               BEGIN
                  SET @nErrNo = 168165
                  SET @cErrMsg = @nQTY_PD--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                  GOTO RollBackTran
               END

               IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
                  DEALLOCATE @curPD
                           
               -- Get PickDetail candidate
               IF @cPSType = 'DISCRETE'
                  SET @cSQL = 
                     ' SELECT PD.PickDetailKey, PD.QTY ' +
                     ' FROM Orders O WITH (NOLOCK) ' +
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' +
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE O.OrderKey = @cOrderKey ' +
                        ' AND PD.StorerKey = @cStorerKey ' +
                        ' AND PD.SKU = @cSKU ' +
                        ' AND PD.LOC = @cLOC ' +
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4''' + 
                        ' AND PD.QTY > 0 ' +
                        ' AND PD.Lot = @cLot' +
                        ' AND O.Status <> ''CANC''  ' +
                        ' AND O.SOStatus <> ''CANC'' '
            
               IF @cPSType = 'CONSO'
                  SET @cSQL = 
                     ' SELECT PD.PickDetailKey, PD.QTY ' + 
                     ' FROM LoadPlanDetail LPD WITH (NOLOCK) ' + 
                        ' JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE LPD.Loadkey = @cLoadKey ' + 
                        ' AND PD.StorerKey = @cStorerKey ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.LOC = @cLOC ' + 
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4''' + 
                        ' AND PD.QTY > 0 ' + 
                        ' AND PD.Lot = @cLot' +
                        ' AND O.Status <> ''CANC''  ' + 
                        ' AND O.SOStatus <> ''CANC'' ' 
   
               IF @cPSType = 'XD'
                  SET @cSQL = 
                     ' SELECT PD.PickDetailKey, PD.QTY ' + 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                        ' JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' + 
                     ' WHERE RKL.PickslipNo = @cPickSlipNo ' + 
                        ' AND PD.StorerKey = @cStorerKey ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.LOC = @cLOC ' + 
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4''' + 
                        ' AND PD.QTY > 0 ' +                      
                        ' AND PD.Lot = @cLot' +
                        ' AND O.Status <> ''CANC'' ' +  
                        ' AND O.SOStatus <> ''CANC'' '

               IF @cPSType = 'CUSTOM'
                  SET @cSQL = 
                     ' SELECT PD.PickDetailKey, PD.QTY ' + 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE PD.PickslipNo = @cPickSlipNo ' + 
                        ' AND PD.StorerKey = @cStorerKey ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.LOC = @cLOC ' + 
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4''' + 
                        ' AND PD.QTY > 0 ' +                     
                        ' AND PD.Lot = @cLot' +
                        ' AND O.Status <> ''CANC'' ' +  
                        ' AND O.SOStatus <> ''CANC'' '

               EXEC rdt.rdt_PTLCart_Confirm_PickSlip_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
                  @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, @cLot,
                  @curPD OUTPUT
            
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
               WHILE @@FETCH_STATUS = 0
               BEGIN

                  select @nQTY_Bal,@nQTY_PD
   
                  -- Exact match
                  IF @nQTY_PD = @nQTY_Bal
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = @cPickConfirmStatus,
                        DropID = @cToteID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 168166
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
                        Status = @cPickConfirmStatus,
                        DropID = @cToteID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 168167
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
  
                     SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
                  END
               
                  -- PickDetail have more
         		   ELSE IF @nQTY_PD > @nQTY_Bal
                  BEGIN
                     -- Short pick
                     IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split
                     BEGIN
                        -- Confirm PickDetail
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                           Status = @cShortStatus,
                           DropID = @cToteID, 
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(),
                           TrafficCop = NULL
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 168168
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
                           SET @nErrNo = 168169
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                           GOTO RollBackTran
                        END
            
                        -- Create a new PickDetail to hold the balance
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
            				   SET @nErrNo = 168170
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
                              SET @nErrNo = 168171
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                              GOTO RollBackTran
                           END
                        END
                     
                        -- Change orginal PickDetail with exact QTY (with TrafficCop)
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                           QTY = @nQTY_Bal, 
                           DropID = @cToteID, 
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(), 
                           Trafficcop = NULL
                        WHERE PickDetailKey = @cPickDetailKey 
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 168172
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                           GOTO RollBackTran
                        END
            
                        -- Confirm orginal PickDetail with exact QTY
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                           Status = @cPickConfirmStatus,
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME() 
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 168173
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                           GOTO RollBackTran
                        END

                                 
                        SET @nQTY_Bal = 0 -- Reduce balance
                     END
                  END
         
                  -- Exit condition
                  IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
                     BREAK

                  IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 AND @cShortPickType = '2' -- Balance pick later
                     BREAK
         
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
               END 
            END
         
            --(cc01) 
            IF @cInsertDropID = '1'
            BEGIN
         	   SET @cPSType = ''

               -- Get PickHeader info
               SELECT 
                  @cZone = Zone, 
                  @cOrderKey = ISNULL( OrderKey, ''), 
                  @cLoadKey = ExternOrderKey
               FROM PickHeader WITH (NOLOCK) 
               WHERE PickHeaderKey = @cPickSlipNo
            
               IF @@ROWCOUNT = 0
                  SET @cPSType = 'CUSTOM'
            
               IF @cPSType = ''
               BEGIN
                  -- Get PickSlip type
                  IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                     SET @cPSType = 'XD'
                  ELSE IF @cOrderKey = ''
                     SET @cPSType = 'CONSO'
                  ELSE
                     SET @cPSType = 'DISCRETE'
               END

               -- Get Orderkey type
               IF @cPSType = 'CONSO'
                  SELECT @cOrderKey = O.OrderKey
                  FROM LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE LPD.Loadkey = @cLoadKey
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status = @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
   
               IF @cPSType = 'XD'
                  SELECT @cOrderKey = O.OrderKey
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                  WHERE RKL.PickslipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status = @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'

               IF @cPSType = 'CUSTOM'
                  SELECT @cOrderKey = O.OrderKey
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE PD.PickslipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status = @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
                  
               IF @cOrderKey <> ''
               BEGIN
                  SELECT @cDropIDType =     
                  CASE WHEN ISNULL( SUM( Qty), 0) = 1 THEN 'SINGLES'     
                     WHEN ISNULL( SUM( Qty), 0) > 1 THEN 'MULTIS'     
                     ELSE '' END    
                  FROM dbo.PickDetail WITH (NOLOCK)     
                        WHERE StorerKey = @cStorerkey    
                        AND OrderKey = @cOrderKey    
                     
                  IF ISNULL(@cLoadKey,'') = ''
                  BEGIN
               	   SELECT @cLoadKey = LoadKey FROM orders WITH (NOLOCK) WHERE storerKey = @cStorerKey AND orderKey = @cOrderKey
                  END
               
                  IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                             WHERE DropID = @cToteID   
                             --AND   [Status] = '0'
                              )
                  BEGIN
               	   IF @cPTLCartAllowReuseDropID = '1 '
                     BEGIN
               	      -- Delete existing dropiddetail  
                        DELETE FROM dbo.DropIDDetail    
                        WHERE DropID = @cToteID   
  
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @nErrNo = 168174  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'  
                           GOTO RollBackTran  
                        END  
  
                        -- Delete existing dropid  
                        DELETE FROM dbo.DropID   
                        WHERE DropID = @cToteID   
  
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @nErrNo = 168175  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'  
                           GOTO RollBackTran  
                        END 
                     END
                     ELSE  
                     BEGIN  
                        SET @nErrNo = 168176  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'  
                        GOTO RollBackTran  
                     END  
                  END
               
                  --INSERT INTO traceInfo (TraceName, Col1,Col2,col3)
                  --VALUES ('cc8081',@cToteID,@cPickSlipNo,@cLoadKey)
               
              	   INSERT INTO dbo.DropID   
                  (DropID, DropIDType, LabelPrinted, [Status], PickSlipNo, LoadKey)  
                  VALUES   
                  (@cToteID, @cDropIDType, '0', '5', @cPickSlipNo, @cLoadKey) 
               
              	   IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 168177  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'  
                     GOTO RollBackTran  
                  END  
              	
              	   INSERT INTO dbo.DropIDDetail (DropID, ChildID)  
                  VALUES (@cToteID, @cOrderKey)
              	
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 168178  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'  
                     GOTO RollBackTran  
                  END  
               END
            END

            IF (@cType = 'CLOSETOTE' AND @nQTY > 0)
               -- EventLog -- (james01) 
               EXEC RDT.rdt_STD_EventLog  
                  @cActionType = '3', -- Sign-in  
                  @nMobileNo   = @nMobile,  
                  @nFunctionID = @nFunc,  
                  @nStep       = @nStep,
                  @cFacility   = @cFacility,  
                  @cStorerKey  = @cStorerkey,    
                  @cSKU        = @cSKU,
                  @nQty        = @nQTY,
                  @cDropID     = @cToteID,
                  @cLocation   = @cLoc,
                  @cPickSlipNo = @cPickSlipNo,
                  @cDeviceID   = @cCartID,
                  @cDevicePosition = @cPosition,
                  @cPickZone   = @cPickZone,
                  @cLoadKey    = @cLoadKey,
                  @nExpectedQTY= @nQTY

            -- Exit condition
            IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
               BREAK

            IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 AND @cShortPickType = '2' -- Balance pick later
               BREAK

            
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL,@cLOT
         END
      END
      
      -- Update new tote
      IF @cType = 'CLOSETOTE' AND @cNewToteID <> ''
      BEGIN
         -- Get RowRef
         SELECT @nRowRef = RowRef FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID
         
         -- Change Tote on rdtPTLCartLog
         UPDATE rdt.rdtPTLCartLog SET
            ToteID = @cNewToteID
         WHERE RowRef = @nRowRef 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 168179
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollBackTran
         END
      END
      
      -- Auto short all subsequence tote
      IF @cType = 'SHORTTOTE'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1' AND @cShortPickType <> '2' -- Balance pick later
         BEGIN
            SET @cSQL = 
               ' SELECT PTLKey, DevicePosition, ExpectedQTY,Lot ' + 
               ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
               ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
                  ' AND LOC = @cLOC ' + 
                  ' AND SKU = @cSKU ' + 
                  ' AND Status <> ''9'' '

            IF CURSOR_STATUS( 'variable', '@curPTL') IN (0, 1)
               DEALLOCATE @curPTL

            EXEC rdt.rdt_PTLCart_Confirm_PickSlip_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
               @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,@cLot, 
               @curPTL OUTPUT
      
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY,@cLot
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get tote info
               SELECT 
                  @cActToteID = ToteID, 
                  @cPickSlipNo = PickSlipNo
               FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
               WHERE CartID = @cCartID 
                  AND Position = @cPosition

               -- Confirm PTLTran
               UPDATE PTL.PTLTran WITH (ROWLOCK)
               SET
                  Status = '9', 
                  QTY = 0, 
                  DropID = @cActToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168179
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               
               -- Update PickDetail
               IF @cUpdatePickDetail = '1'
               BEGIN
                  SET @cPSType = ''

                  -- Get PickHeader info
                  SELECT 
                     @cZone = Zone, 
                     @cOrderKey = ISNULL( OrderKey, ''), 
                     @cLoadKey = ExternOrderKey
                  FROM PickHeader WITH (NOLOCK) 
                  WHERE PickHeaderKey = @cPickSlipNo
                  
                  IF @@ROWCOUNT = 0
                     SET @cPSType = 'CUSTOM'

                  IF @cPSType = ''
                  BEGIN
                     -- Get PickSlip type
                     IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                        SET @cPSType = 'XD'
                     ELSE IF @cOrderKey = ''
                        SET @cPSType = 'CONSO'
                     ELSE
                        SET @cPSType = 'DISCRETE'
                  END

                  -- Check PickDetail tally PTLTran
                  IF @cPSType = 'DISCRETE'
                     SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                     FROM Orders O WITH (NOLOCK) 
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE O.OrderKey = @cOrderKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.LOC = @cLOC
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.Lot = @cLot
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'
                  
                  IF @cPSType = 'CONSO'
                     SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                     FROM LoadPlanDetail LPD WITH (NOLOCK) 
                        JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     WHERE LPD.Loadkey = @cLoadKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.LOC = @cLOC
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.Lot = @cLot
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'
         
                  IF @cPSType = 'XD'
                     SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                     FROM Orders O WITH (NOLOCK)
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                        JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                     WHERE RKL.PickslipNo = @cPickSlipNo
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.LOC = @cLOC
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.Lot = @cLot
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'

                  IF @cPSType = 'CUSTOM'
                     SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                     FROM Orders O WITH (NOLOCK)
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     WHERE PD.PickslipNo = @cPickSlipNo
                        AND PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cSKU
                        AND PD.LOC = @cLOC
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.Lot = @cLot
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'

                  -- Get PickDetail tally PTLTran
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 168180
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  IF @cPSType = 'DISCRETE'
                     SET @cSQL = 
                        ' SELECT PD.PickDetailKey ' +
                        ' FROM Orders O WITH (NOLOCK) ' +
                           ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' +
                           ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                        ' WHERE O.OrderKey = @cOrderKey ' +
                           ' AND PD.StorerKey = @cStorerKey ' +
                           ' AND PD.SKU = @cSKU ' +
                           ' AND PD.LOC = @cLOC ' +
                           ' AND PD.Status < @cPickConfirmStatus ' + 
                           ' AND PD.Status <> ''4''' + 
                           ' AND PD.QTY > 0 ' +
                           ' AND PD.Lot = @cLot' +
                           ' AND O.Status <> ''CANC''  ' +
                           ' AND O.SOStatus <> ''CANC'' '
                  
                  IF @cPSType = 'CONSO'
                     SET @cSQL = 
                        ' SELECT PD.PickDetailKey ' +
                        ' FROM LoadPlanDetail LPD WITH (NOLOCK) ' +
                           ' JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' +
                           ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
                           ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                        ' WHERE LPD.Loadkey = @cLoadKey ' +
                           ' AND PD.StorerKey = @cStorerKey ' +
                           ' AND PD.SKU = @cSKU ' +
                           ' AND PD.LOC = @cLOC ' +
                           ' AND PD.Status < @cPickConfirmStatus ' + 
                           ' AND PD.Status <> ''4''' + 
                           ' AND PD.QTY > 0 ' +
                           ' AND PD.Lot = @cLot' +
                           ' AND O.Status <> ''CANC''  ' +
                           ' AND O.SOStatus <> ''CANC'' '
         
                  IF @cPSType = 'XD'
                     SET @cSQL = 
                        ' SELECT PD.PickDetailKey ' +
                        ' FROM Orders O WITH (NOLOCK) ' +
                           ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
                           ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                           ' JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' +
                        ' WHERE RKL.PickslipNo = @cPickSlipNo ' +
                           ' AND PD.StorerKey = @cStorerKey ' +
                           ' AND PD.SKU = @cSKU ' +
                           ' AND PD.LOC = @cLOC ' +
                           ' AND PD.Status < @cPickConfirmStatus ' + 
                           ' AND PD.Status <> ''4''' + 
                           ' AND PD.QTY > 0 ' +
                           ' AND PD.Lot = @cLot' +
                           ' AND O.Status <> ''CANC'' ' +
                           ' AND O.SOStatus <> ''CANC'' '

                  IF @cPSType = 'CUSTOM'
                     SET @cSQL = 
                        ' SELECT PD.PickDetailKey ' +
                        ' FROM Orders O WITH (NOLOCK) ' +
                           ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +
                           ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                        ' WHERE PD.PickslipNo = @cPickSlipNo ' +
                           ' AND PD.StorerKey = @cStorerKey ' +
                           ' AND PD.SKU = @cSKU ' +
                           ' AND PD.LOC = @cLOC ' +
                           ' AND PD.Status < @cPickConfirmStatus ' + 
                           ' AND PD.Status <> ''4''' + 
                           ' AND PD.QTY > 0 ' +
                           ' AND PD.Lot = @cLot' +
                           ' AND O.Status <> ''CANC'' ' +
                           ' AND O.SOStatus <> ''CANC'' '

                  IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
                     DEALLOCATE @curPD
                           
                  EXEC rdt.rdt_PTLCart_Confirm_PickSlip_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
                     @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, @cLot,
                     @curPD OUTPUT

                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE PickDetail WITH (ROWLOCK)SET
                        Status = @cShortStatus, 
                        DropID = @cActToteID, 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 168181
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END

               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY,@cLot
            END
         END

         -- EventLog -- (james01) 
         EXEC RDT.rdt_STD_EventLog  
            @cActionType = '3', -- Sign-in  
            @nMobileNo   = @nMobile,  
            @nFunctionID = @nFunc,  
            @nStep       = @nStep,
            @cFacility   = @cFacility,  
            @cStorerKey  = @cStorerkey,    
            @cSKU        = @cSKU,
            @nQty        = @nQTY,
            @cDropID     = @cToteID,
            @cLocation   = @cLoc,
            @cPickSlipNo = @cPickSlipNo,
            @cDeviceID   = @cCartID,
            @cDevicePosition = @cPosition,
            @cPickZone   = @cPickZone,
            @cLoadKey    = @cLoadKey,
            @nExpectedQTY= @nExpectedQTY
      END

      COMMIT TRAN rdt_PTLCart_Confirm
   END

   IF @cAutoScanOut = '1'
   BEGIN
      SET @nToScanOut = 0

      -- Check everything already picked
      IF NOT EXISTS ( SELECT 1 
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID = @cCartID
         AND   PTLType = 'CART'
         AND   DeviceProfileLogKey = @cDPLKey
         AND   Status < '9')
      BEGIN
         DECLARE @cur_ScanOut CURSOR
         SET @cur_ScanOut = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT SourceKey 
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID = @cCartID
         AND   PTLType = 'CART'
         AND   DeviceProfileLogKey = @cDPLKey
         ORDER BY 1
         OPEN @cur_ScanOut
         FETCH NEXT FROM @cur_ScanOut INTO @cPickSlipNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @cPSType = ''

            -- Get PickHeader info
            SELECT 
               @cZone = Zone, 
               @cOrderKey = ISNULL( OrderKey, ''), 
               @cLoadKey = ExternOrderKey
            FROM PickHeader WITH (NOLOCK) 
            WHERE PickHeaderKey = @cPickSlipNo

            IF @@ROWCOUNT = 0
               SET @cPSType = 'CUSTOM'

            IF @cPSType = ''
            BEGIN
               -- Get PickSlip type
               IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                  SET @cPSType = 'XD'
               ELSE IF @cOrderKey = ''
                  SET @cPSType = 'CONSO'
               ELSE
                  SET @cPSType = 'DISCRETE'
            END

            -- Check anymore pickdetail not pick then do scan out
            IF @cPSType = 'DISCRETE' 
            BEGIN 
               IF NOT EXISTS ( SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON ( PD.OrderKey = PH.OrderKey)
                  WHERE PH.PickHeaderKey = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0)
                  SET @nToScanOut = 1
            END

            IF @cPSType = 'CONSO' 
            BEGIN 
               IF NOT EXISTS ( SELECT 1
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickHeader PH (NOLOCK) ON ( LPD.LoadKey = PH.ExternOrderKey)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  WHERE PH.PickHeaderKey = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0)
                  SET @nToScanOut = 1
            END
   
            IF @cPSType = 'XD' 
            BEGIN 
               IF NOT EXISTS ( SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                  WHERE RKL.PickslipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0)
                  SET @nToScanOut = 1
            END

            IF @cPSType = 'CUSTOM' 
            BEGIN 
               -- Check if this custom pickslip is a sub pickslip ( not exists in pickheader)
               SELECT TOP 1 @cTemp_OrderKey = OrderKey
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
                  AND   PickSlipNo = @cPickSlipNo
                  AND   Status = @cPickConfirmStatus
                  --AND   Status <> '4'
                  --AND   QTY > 0               
               ORDER BY 1

               -- Look for discrete pickslipno
               SELECT @cM_PickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE OrderKey = @cTemp_OrderKey

               -- Look for conso pickslipno
               IF @@ROWCOUNT = 0
               BEGIN
                  SELECT @cTemp_LoadKey = LoadKey
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cTemp_OrderKey

                  SELECT @cM_PickSlipNo = PickHeaderKey
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE ExternOrderKey = @cTemp_LoadKey
               END

               IF ISNULL( @cM_PickSlipNo, '') <> ''
                  SET @cPickSlipNo2ScanOut = @cM_PickSlipNo
                              
               -- If pickslipno used in cart not same as pickheaderkey
               -- this might be sub pickslipno, need use orderkey to check
               IF ISNULL( @cPickSlipNo2ScanOut, '') <> '' 
                  AND @cPickSlipNo2ScanOut <> @cPickslipNo
               BEGIN
                  IF ISNULL( @cTemp_LoadKey, '') <> ''
                  BEGIN
                     IF NOT EXISTS ( SELECT 1
                        FROM dbo.PickDetail PD WITH (NOLOCK) 
                        JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
                        WHERE LPD.LoadKey = @cTemp_LoadKey
                           AND PD.StorerKey = @cStorerKey
                           AND PD.Status < @cPickConfirmStatus
                           AND PD.Status <> '4'
                           AND PD.QTY > 0)
                        SET @nToScanOut = 1
                  END
                  ELSE
                  BEGIN
                  IF NOT EXISTS ( SELECT 1
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                     WHERE PD.OrderKey = @cTemp_OrderKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.QTY > 0)
                     SET @nToScanOut = 1
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS ( SELECT 1
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                     WHERE PD.PickslipNo = @cPickSlipNo
                        AND PD.StorerKey = @cStorerKey
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.QTY > 0)
                     SET @nToScanOut = 1

                     SET @cPickSlipNo2ScanOut = @cPickSlipNo
               END
            END

            IF @nToScanOut = 1
            BEGIN
               IF @cPSType <> 'CUSTOM' 
                  SET @cPickSlipNo2ScanOut = @cPickslipNo

               EXEC dbo.isp_ScanOutPickslip
                  @c_PickSlipNo  = @cPickSlipNo2ScanOut,
                  @n_err         = @nErrNo      OUTPUT,
                  @c_errmsg      = @cErrMsg     OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 168182
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan Out Fail
                  GOTO ROLLBACKTRAN
               END
            END

            FETCH NEXT FROM @cur_ScanOut INTO @cPickSlipNo
         END
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO