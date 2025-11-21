SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_805PTL_Confirm13                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 10-04-2021 1.0  YeeKung  WMS-16833 Created                           */
/* 16-02-2022 1.1  Ung      WMS-18928 Add calc PackInfo.CartonType      */
/************************************************************************/

CREATE PROC [PTL].[isp_805PTL_Confirm13] (
   @cIPAddress    NVARCHAR(30),
   @cPosition     NVARCHAR(20),
   @cFuncKey      NVARCHAR(2),
   @nSerialNo     INT,
   @cInputValue   NVARCHAR(20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR(125) OUTPUT,
   @cDebug        NVARCHAR( 1) = ''
)
AS
BEGIN TRY
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLangCode      NVARCHAR( 3)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @nFunc          INT
   DECLARE @nQTY           INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
   DECLARE @nGroupKey      INT
   DECLARE @nCartonNo      INT
   DECLARE @cStation       NVARCHAR( 10)
   DECLARE @cStation1      NVARCHAR( 10)
   DECLARE @cStation2      NVARCHAR( 10)
   DECLARE @cStation3      NVARCHAR( 10)
   DECLARE @cStation4      NVARCHAR( 10)
   DECLARE @cStation5      NVARCHAR( 10)
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLightMode     NVARCHAR( 4)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cCriteria1     NVARCHAR( 30)
   DECLARE @cCriteria2     NVARCHAR( 30)
   DECLARE @cLabelNo       NVARCHAR( 30)
   DECLARE @nTotalExpectedQTY INT
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cNewLine       NVARCHAR(1)

   DECLARE @cLabelPrinter     NVARCHAR( 10)
         , @cPaperPrinter     NVARCHAR( 10)
         , @nMobile           INT
         , @cLightModeEnd     NVARCHAR(10)
         , @cbatchkey NVARCHAR(20)
         , @nCUBE FLOAT

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   SET @nFunc = 805 -- PTL station (rdt.rdtfnc_PTLStation)
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))

   -- Get storer
   DECLARE @cStorerKey NVARCHAR(15)
   SELECT TOP 1
      @cStorerKey = StorerKey
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND LightUp = '1'

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   -- Get device profile info
   SELECT @cStation = DeviceID
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND DeviceType = 'STATION'
      AND DeviceID <> ''

   -- Get PTLTran info
   SELECT TOP 1
      @nGroupKey = GroupKey,
      @cOrderKey = OrderKey,
      @cDropID = DropID,
      @cSKU = SKU,
      @cUserName = EditWho
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND Func = 805
      AND Status = '1' -- Lighted up
      AND LightUp= '1'

   SELECT TOP 1 @cPaperPrinter   = Printer_Paper
      ,@cLabelPrinter   = Printer
      ,@nMobile         = Mobile
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE username=@cUserName
   AND Func=805

      SELECT @cUserName,@cPaperPrinter,@cLabelPrinter

   -- Get booking info
   SELECT
      @cWaveKey = wavekey,
      @cCartonID=CartonID,
      @cPickSlipNo =PickSlipNo,
      @cbatchkey =BatchKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)
   WHERE RowRef = @nGroupKey


   SELECT @cLoadKey=ph.ExternOrderKey
   FROM pickdetail pd (NOLOCK) JOIN
   pickheader ph (NOLOCK) ON pd.PickSlipNo=ph.PickHeaderKey
   WHERE pd.PickSlipNo=@cPickSlipNo
   -- Calc QTY
   IF @cInputValue = ''
      SET @nQTY = 0
   ELSE IF @cInputValue = 'End' -- IN00028515
   BEGIN
      GOTO QUIT
   END
   ELSE
      SET @nQTY = CAST( @cInputValue AS INT)

   -- Determine action
   IF @nQTY = 0
      SET @cType = 'SHORTTOTE'
   ELSE
      SET @cType = 'CLOSETOTE'

   if @cDebug = '1'
      select @cStorerKey '@cStorerKey', @cStation '@cStation', @nGroupKey '@nGroupKey', @cOrderKey '@cOrderKey', @cCartonID '@cCartonID', @cSKU '@cSKU',
      @nQTY '@nQTY', @cType '@cType', @cUserName '@cUserName'

   -- For calc balance
   SET @nQTY_Bal = @nQTY

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_805PTL_Confirm13 -- For rollback or commit only our own transaction

   SET @nExpectedQTY = 0

   -- PTLTran
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey, ExpectedQTY
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
         AND DevicePosition = @cPosition
         AND GroupKey = @nGroupKey
         AND DropID = @cDropID
         AND SKU = @cSKU
         AND Status <> '9'
   OPEN @curPTL
   FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @nExpectedQTY = @nExpectedQTY + @nQTY_PTL

      -- Exact match
      IF @nQTY_PTL = @nQTY_Bal
      BEGIN
			-- Confirm PTLTran
			UPDATE PTL.PTLTran WITH (ROWLOCK) SET
				Status = '9',
				LightUp = '0',
				QTY = ExpectedQTY,
				CaseID = @cCartonID,
				-- MessageNum = @cMessageNum,
				EditWho = SUSER_SNAME(),
				EditDate = GETDATE(),
				TrafficCop = NULL
			WHERE PTLKey = @nPTLKey

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo = 182701
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
            LightUp = '0',
            QTY = ExpectedQTY,
            CaseID = @cCartonID,
            -- MessageNum = @cMessageNum,
            EditDate = GETDATE(),
				EditWho  = SUSER_SNAME(),
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
            GOTO RollBackTran
         END

         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PTL -- Reduce balance
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
               LightUp = '0',
               QTY = 0,
               CaseID = @cCartonID,
               -- MessageNum = @cMessageNum,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
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
               Storerkey, OrderKey, ConsigneeKey, SKU, LOC, LOT, UOM, Remarks, Func, GroupKey, 'isp_805PTL_Confirm13', ArchiveCop
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182704
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail
               GOTO RollBackTran
            END

            -- Confirm orginal PTLTran with exact QTY
            UPDATE PTL.PTLTran WITH (ROWLOCK) SET
               Status = '9',
               LightUp = '0',
               ExpectedQty = @nQTY_Bal,
               QTY = @nQTY_Bal,
               -- MessageNum = @cMessageNum,
               CaseID = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END
      END

      -- Exit condition
      IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
         BREAK

      FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
   END

   -- PackDetail
   IF @cUpdatePackDetail = '1'
   BEGIN
      -- PackHeader
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader (nolock) WHERE pickslipno = @cPickSlipNo)
      BEGIN

         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, ConsigneeKey, OrderKey)
         VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, '', @cOrderKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END

      -- Get carton info
      SET @nCartonNo = 0
      SET @cLabelNo = ''
      SET @cNewLine = 'N'
      SELECT
         @nCartonNo = CartonNo,
         @cLabelNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND RefNo = @cCartonID

      -- New carton, generate labelNo
      IF @nCartonNo = 0
      BEGIN
         SET @cLabelNo = ''

         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey)
         IF @cGenLabelNo_SP = '0'
            SET @cGenLabelNo_SP = ''

         IF @cGenLabelNo_SP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +
                  ' @cPickslipNo, ' +
                  ' @nCartonNo,   ' +
                  ' @cLabelNo     OUTPUT '
               SET @cSQLParam =
                  ' @cPickslipNo  NVARCHAR(10),       ' +
                  ' @nCartonNo    INT,                ' +
                  ' @cLabelNo     NVARCHAR(20) OUTPUT '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @cPickslipNo,
                 @nCartonNo,
                  @cLabelNo OUTPUT
            END
         END
         ELSE
         BEGIN
            EXEC isp_GenUCCLabelNo
               @cStorerKey,
               @cLabelNo      OUTPUT,
               @bSuccess      OUTPUT,
               @nErrNo        OUTPUT,
               @cErrMsg       OUTPUT
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 182707
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO RollBackTran
            END
         END

         IF @cLabelNo = ''
         BEGIN
            SET @nErrNo = 182708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
            GOTO RollBackTran
         END

         SET @cLabelLine = ''
         SET @cNewLine = 'Y'
      END
      ELSE
      BEGIN
         -- Get LabelLine
         SET @cLabelLine = ''
         SELECT @cLabelLine = LabelLine
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo 
            AND SKU = @cSKU
         
         IF @cLabelLine = ''
         BEGIN
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) 
            FROM dbo.PackDetail (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo

            SET @cNewLine = 'Y'
         END
      END

      -- PackDetail
      IF @cNewLine = 'Y'
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo, DropID, 
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cCartonID, @cCartonID, 
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Update Packdetail
         UPDATE dbo.PackDetail SET
            QTY = QTY + @nQTY,
            EditWho = 'rdt.' + SUSER_SNAME(),
            EditDate = GETDATE(),
            ArchiveCop = NULL
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
            GOTO RollBackTran
         END
      END

      -- Get system assigned CartonoNo and LabelNo
      IF @nCartonNo = 0
      BEGIN
         -- If insert cartonno = 0, system will auto assign max cartonno
         SELECT TOP 1 
            @nCartonNo = CartonNo
         FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cLabelNo
      END  

      -- Get storer info
      DECLARE @cCartonGroup NVARCHAR( 10)
      SELECT @cCartonGroup = CartonGroup FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey = @cStorerKey
      
      -- Calc carton cube
      SELECT @nCube = ISNULL( SUM( SKU.STDCube * PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo

      -- Get best fit carton type
      DECLARE @cCartonType NVARCHAR( 10) = ''
      DECLARE @nCartonCube FLOAT = 0
      SELECT TOP 1 
         @cCartonType = CartonType, 
         @nCartonCube = Cube
      FROM dbo.Cartonization WITH (NOLOCK)
      WHERE CartonizationGroup = @cCartonGroup
         AND Cube >= @nCube
      ORDER BY Cube

      -- Get biggest carton type, if cannot fit
      IF @cCartonType = ''
         SELECT TOP 1 
            @cCartonType = CartonType, 
            @nCartonCube = Cube
         FROM dbo.Cartonization WITH (NOLOCK)
         WHERE CartonizationGroup = @cCartonGroup
         ORDER BY Cube DESC
      
      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM packinfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO PACKINFO (PickSlipNo, CartonNo, QTY, CartonType, Cube)
         VALUES( @cPickSlipNo, @nCartonNo, @nQTY, @cCartonType, @nCartonCube)
			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo = 182711
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfFail
				GOTO RollBackTran
			END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET 
            CartonType = @cCartonType, 
            Cube = @nCartonCube, 
            QTY = QTY + @nQTY, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182712
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --UPDPackInfFail
            GOTO RollBackTran
         END 
      END  
   END

   -- PickDetail
   IF @cUpdatePickDetail = '1'
   BEGIN
      -- Get PickDetail tally PTLTran
      SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
      FROM   Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE o.UserDefine09=@cWaveKey
         AND PD.DropID = @cDropID
         AND PD.SKU = @cSKU
         AND pd.Notes=@cbatchkey
         AND pd.PickSlipNo=@cPickSlipNo
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      select @nQTY_PD,'@nQTY_PD',@nExpectedQTY,'@nExpectedQTY',@cDropID,'@cDropID',@cOrderKey,'@cOrderKey',@cSKU,'@cSKU'

      IF @nQTY_PD <> @nExpectedQTY
      BEGIN
         SET @nErrNo = 182714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END

      -- For calculation
      SET @nQTY_Bal = @nQTY


      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT pickdetailkey, SUM( PD.QTY)
      FROM   Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE o.UserDefine09=@cWaveKey
         AND PD.DropID = @cDropID
         AND PD.SKU = @cSKU
         AND pd.Notes=@cbatchkey
         AND pd.PickSlipNo=@cPickSlipNo
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
      GROUP BY pickdetailkey

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
               CaseID = @cLabelNo,
               dropid = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182715
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
               CaseID = @cLabelNo,
               dropid = @cCartonID,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182716
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
                  Status = '4',
                  -- CaseID = @cCartonID,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
                  -- TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                 SET @nErrNo = 182717
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
                  SET @nErrNo = 182718
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                  GOTO RollBackTran
               END

               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PickDetail (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  PickDetailKey,Channel_ID,
                  QTY,
              TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  @cNewPickDetailKey, Channel_ID,
                  @nQTY_PD - @nQTY_Bal, -- QTY
                  NULL, -- TrafficCop
                  '1'   -- OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 182719
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
                     SET @nErrNo = 182720
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INSRefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  CaseID = @cLabelNo,
                  dropid = @cCartonID,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 182721
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
                  SET @nErrNo = 182722
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END

               SET @nQTY_Bal = 0 -- Reduce balance
            END
         END

         -- Exit condition
         IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END

      DECLARE @tRDTUCCLabel AS VariableTable
      DECLARE @tRDTPrintJob AS VariableTable
      DECLARE @tPriceTag AS VariableTable
      DECLARE @nPickQty INT,
              @nPAckQty INT


      SELECT @nPickQty=SUM(pd.qty)
      FROM  Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE o.UserDefine09=@cWaveKey
        -- AND PD.DropID = @cDropID
         AND PD.Status <= '5'
         AND pd.Notes=@cbatchkey
         AND pd.PickSlipNo=@cPickSlipNo
         --AND pd.CaseID<>''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'

      SELECT @nPackQTY=SUM(pds.Qty)  --(yeekung01)      
      FROM packheader PH (NOLOCK)
      JOIN packdetail PD (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo        
      JOIN pickdetail PDS (NOLOCK) ON PD.PickSlipNo=pds.PickSlipNo AND pd.sku=pds.sku AND pd.StorerKey=pds.Storerkey AND pd.LabelNo=pds.CaseID
      WHERE pd.PickSlipNo=@cPickSlipNo
      AND pd.StorerKey=@cStorerKey
      AND pds.Notes=@cbatchkey

      if @cDebug = '1'
      select @nPackQTY '@nPackQTY', @nPickQty '@nPickQty', @cPickSlipNo '@cPickSlipNo', @cOrderKey '@cOrderKey',@cLoadKey '@cLoadKey'


      IF @nPackQTY=@nPickQty
      BEGIN

         SET @cLightModeEnd = rdt.RDTGetConfig( @nFunc, 'LightModeEnd', @cStorerKey)

         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
            ,@n_PTLKey         = 0
            ,@c_DisplayValue   = 'End'
            ,@b_Success        = @bSuccess    OUTPUT
            ,@n_Err            = @nErrNo      OUTPUT
            ,@c_ErrMsg         = @cErrMsg     OUTPUT
            ,@c_DeviceID       = @cStation
            ,@c_DevicePos      = @cPosition
            ,@c_DeviceIP       = @cIPAddress
            ,@c_LModMode       = @cLightModeEnd

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 182723
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'LightUpFail'
            GOTO RollBackTran
         END

         SELECT TOP 1 @nCartonNo=CartonNo
         FROM packheader PH (NOLOCK)
         JOIN packdetail PD (NOLOCK) ON
         PH.PickSlipNo=PD.PickSlipNo
         JOIN pickdetail PDS (NOLOCK) ON PD.PickSlipNo=pds.PickSlipNo AND pd.sku=pds.sku AND pd.StorerKey=pds.Storerkey AND pd.LabelNo=pds.CaseID
         WHERE pd.PickSlipNo=@cPickSlipNo
         AND pd.StorerKey=@cStorerKey
         AND pds.Notes=@cbatchkey

         INSERT INTO @tRDTPrintJob (Variable, Value) VALUES
         ( '@cPickSlipNo',          @cPickslipno),
         ( '@nCartonNo',            CAST(@nCartonNo AS NVARCHAR(5)))

         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,
            'cartonlbl',      -- Report type
            @tRDTPrintJob,    -- Report params
            'rdt_PTLStation_Confirm',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

			SELECT @cErrMsg

         IF @nErrNo<>''
            GOTO ROLLBACKTRAN

         INSERT INTO @tRDTUCCLabel (Variable, Value) VALUES
         ( '@cstorerkey',          @cStorerKey),
         ( '@cPickslipno',          @cPickslipno),
         ( '@cLabelNo',            @cLabelNo)

         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,
            'ucclabel',      -- Report type
            @tRDTUCCLabel,    -- Report params
            'rdt_PTLStation_Confirm',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo<>''
            GOTO ROLLBACKTRAN

         INSERT INTO @tPriceTag (Variable, Value) VALUES
         ( '@cStorerKey',          @cStorerKey) ,
         ( '@cLabelNo',            @cLabelNo)

         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,
            'PVHLBL1',      -- Report type
            @tPriceTag,    -- Report params
            'rdt_PTLStation_Confirm',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo<>''
            GOTO ROLLBACKTRAN
      END

      SELECT @nPickQty=SUM(qty)--*
      FROM  Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE o.UserDefine09=@cWaveKey
         AND pd.storerkey=@cStorerKey

      SELECT @nPackQTY=SUM(pd.Qty)
      FROM packheader PH (NOLOCK)
         JOIN packdetail PD (NOLOCK) ON
         PH.PickSlipNo=PD.PickSlipNo
      WHERE pd.PickSlipNo=@cPickSlipNo
         AND pd.StorerKey=@cStorerKey

      IF @nPackQTY=@nPickQty
      BEGIN
         UPDATE PackHeader SET 
            Status ='9', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182724
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPHFail'
            GOTO RollBackTran
         END
      END
   END

   -- Auto short all subsequence tote
   IF @cType = 'SHORTTOTE'
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainCarton', @cStorerKey) = '1'
      BEGIN
         -- Get station
         SELECT
            @cStation1 = V_String1,
            @cStation2 = V_String2,
            @cStation2 = V_String3,
            @cStation3 = V_String4,
            @cStation5 = V_String5
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE UserName = @cUserName

         SET @nExpectedQTY = 0

         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, IPAddress, DevicePosition, ExpectedQTY
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND DropID = @cDropID
               AND SKU = @cSKU
               AND Status <> '9'

         OPEN @curPTL
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY_PTL
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @nExpectedQTY = @nExpectedQTY + @nQTY_PTL

            -- Get carton
            SELECT @cCartonID = CartonID
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND IPAddress = @cIPAddress
               AND Position = @cPosition

            -- Confirm PTLTran
            UPDATE PTL.PTLTran SET
               Status = '9',
               LightUp = '0',
               QTY = 0,
               CaseID = @cCartonID,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(),
               TrafficCop = NULL
            WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182725
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
               GOTO RollBackTran
            END

            -- Update PickDetail
            IF @cUpdatePickDetail = '1'
            BEGIN
               -- Get PickDetail tally PTLTran
               SELECT PickDetailKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.DropID = @cDropID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.CaseID = ''
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND O.Status <> 'CANC'
						AND O.SOStatus <> 'CANC'
               IF @nQTY_PD <> @nExpectedQTY
               BEGIN
                  SET @nErrNo = 182726
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                  GOTO RollBackTran
               END

               -- Loop PickDetail
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.DropID = @cDropID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.CaseID = ''
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Confirm PickDetail
                  UPDATE PickDetail SET
                     Status = '4',
                     -- CaseID = @cCartonID,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 182727
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO RollBackTran
                  END
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
               END
            END

            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY_PTL
         END

         -- Turn all Light off in station
         DECLARE @i INT
         SET @i = 1
         WHILE @i = 1
         BEGIN
            SET @cStation = ''
            IF @i = 1 SET @cStation = @cStation1 ELSE
            IF @i = 2 SET @cStation = @cStation2 ELSE
            IF @i = 3 SET @cStation = @cStation3 ELSE
            IF @i = 4 SET @cStation = @cStation4 ELSE
            IF @i = 5 SET @cStation = @cStation5

            IF @cStation <> ''
            BEGIN
               -- Off all lights
               EXEC PTL.isp_PTL_TerminateModule
                   @cStorerKey
                  ,@nFunc
                  ,@cStation
                  ,'STATION'
                ,@bSuccess    OUTPUT
                  ,@nErrNo      OUTPUT
                  ,@cErrMsg     OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
            SET @i = @i + 1
         END
      END
   END

   -- Re-light up
   IF @cType = 'CLOSETOTE'
   BEGIN
      SET @nPTLKey = ''
      SET @nExpectedQTY = 0
      SELECT TOP 1
         @nPTLKey = PTLKey,
         @nExpectedQTY = ExpectedQTY
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
         AND DevicePosition = @cPosition
         AND GroupKey = @nGroupKey
         AND DropID = @cDropID
         AND SKU = @cSKU
         AND Status <> '9'

      IF @cDebug = '1'
         SELECT @cType '@cType', @cIPAddress '@cIPAddress', @cPosition '@cPosition', @nGroupKey '@nGroupKey', @cDropID '@cDropID', @cSKU '@cSKU', @nExpectedQTY '@nExpectedQTY'

      IF @nExpectedQTY > 0
      BEGIN
         DECLARE @cQTY NVARCHAR(10)
         SET @cQTY = CAST( @nExpectedQTY AS NVARCHAR(10))
         IF LEN( @cQTY) > 5
            SET @cQTY = '*'
         ELSE
            SET @cQTY = LEFT( @cQTY, 5)

         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = @nPTLKey
           ,@c_DisplayValue   = @cQTY
           ,@b_Success        = @bSuccess    OUTPUT
           ,@n_Err            = @nErrNo      OUTPUT
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos      = @cPosition
           ,@c_DeviceIP       = @cIPAddress
           ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

   COMMIT TRAN isp_805PTL_Confirm13
   GOTO Quit

	RollBackTran:
   ROLLBACK TRAN isp_805PTL_Confirm13 -- Only rollback change made here

   -- Raise error to go to catch block
   RAISERROR ('', 16, 1) WITH SETERROR

   END TRY
   BEGIN CATCH
     IF @cDebug = 0
      -- RelightUp
      EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
        ,@n_PTLKey         = 0
        ,@c_DisplayValue   = 'ERR'
        ,@b_Success        = @bSuccess    OUTPUT
        ,@n_Err            = @nErrNo      OUTPUT
        ,@c_ErrMsg         = @cErrMsg     OUTPUT
        ,@c_DeviceID       = @cStation
        ,@c_DevicePos      = @cPosition
        ,@c_DeviceIP       = @cIPAddress
        ,@c_LModMode       = '99'

   END CATCH

   Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO