SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_803PTL_Confirm08                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Accept QTY in CS-PCS, format 9-999                                */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 31-03-2021 1.0  yeekung    WMS-18729 Created                               */
/* 03-06-2022 1.1  Ung        WMS-19779 Change codelkup to printer group      */
/* 23-11-2022 1.2  yeekung    Add error trigger                               */
/* 22-12-2022 1.3  yeekung    WMS-21394 Add udf02 as loc (yeekung02)          */
/* 22-06-2023 1.4  yeekung    WMS-22930 Tune performance (yeekung03)          */
/******************************************************************************/

CREATE   PROC [PTL].[isp_803PTL_Confirm08] (
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
   DECLARE @nQTY_Pack      INT
   DECLARE @nExpectedQTY   INT
   DECLARE @nGroupKey      INT
   DECLARE @nCartonNo      INT
   DECLARE @cStation       NVARCHAR( 10)
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
   DECLARE @cPackLight     NVARCHAR( 4)
   DECLARE @cOrderLineNumber NVARCHAR( 5)
   DECLARE @cBatchKey      NVARCHAR( 10)
   DECLARE @cLoc           NVARCHAR(18)
   DECLARE @cShipLbl       NVARCHAR(20)
   DECLARE @cVasLbl        NVARCHAR(20)
   DECLARE @cDNotesLbl     NVARCHAR(20)
   DECLARE @cFacility      NVARCHAR(20)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @nSPErrNo       INT
   DECLARE @cSPErrMSG      NVARCHAR(20)
   
   DECLARE @cDisplay NVARCHAR(20)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   SET @nTranCount = @@TRANCOUNT
   SET @nFunc = 803 -- PTL piece (rdt.rdtfnc_PTLPiece)
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))

   -- Get light info
   DECLARE @cStorerKey NVARCHAR(15)
   SELECT TOP 1 
      @cStation = DeviceID, 
      @cStorerKey = StorerKey
   FROM PTL.LightStatus WITH (NOLOCK) 
   WHERE IPAddress = @cIPAddress 
      AND DevicePosition = @cPosition 

   SELECT TOP 1 
      @cLoc = Loc
   FROM DeviceProfile WITH (NOLOCK) 
   WHERE DevicePosition = @cPosition  
      AND DeviceID = @cStation     
      AND DeviceType = 'station'

   SELECT @cfacility=facility
   FROM rdt.RDTMOBREC (nolock)
   where V_String1=@cStation
   AND storerkey=@cstorerkey

   -- Get storer config
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
   SET @cShipLbl = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   SET @cVasLbl = rdt.RDTGetConfig( @nFunc, 'VASLabel', @cStorerKey)
   SET @cDNotesLbl = rdt.RDTGetConfig( @nFunc, 'DeliveryNotes', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)

   -- Get booking info
   SELECT 
      @cDropID = DropID, 
      @cOrderKey = OrderKey, 
      @cLoadKey = loadkey,
      @cSKU = SKU,
      @cWaveKey = wavekey
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND Position = @cPosition
   
   SET @cInputValue = RTRIM( LTRIM( @cInputValue)) 

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_803PTL_Confirm08 -- For rollback or commit only our own transaction   
      
   /***********************************************************************************************
                                              CONFIRM ORDER
   ***********************************************************************************************/
	IF @cInputValue = '1'
   BEGIN
      -- For calc balance

      SET @nQTY = CAST( @cInputValue AS INT)

      SET @nQTY_Bal = @nQTY

      -- Find PickDetail to offset
      SET @cPickDetailKey = ''
      SELECT TOP 1 
         @cPickDetailKey = PD.PickDetailKey, 
         @nQTY_PD = QTY
      FROM PickDetail PD WITH (NOLOCK)
         JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE PD.dropID = @cDropID
         AND O.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU
         AND PD.Status <= '5'
         AND PD.CaseID <> 'SORTED'
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
   
      -- Check blank
      IF @cPickDetailKey = ''
      BEGIN
         SET @nErrNo = 182951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
         GOTO Quit
      END
         
      -- Exact match
      IF @nQTY_PD = 1
      BEGIN
      	-- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            -- Status = '5',
            CaseID = 'SORTED',
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- PickDetail have more
   	ELSE IF @nQTY_PD > 1
      BEGIN
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
            SET @nErrNo = 182954
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
            OptimizeCop, Channel_ID)
         SELECT 
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            @cNewPickDetailKey, 
            @nQTY_PD - 1, -- QTY
            '1'   -- OptimizeCop
            , Channel_ID
         FROM dbo.PickDetail WITH (NOLOCK) 
   		WHERE PickDetailKey = @cPickDetailKey			            
         IF @@ERROR <> 0
         BEGIN
   			SET @nErrNo = 182955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END       
   
         -- Get RefKeyLookup info
         SELECT
            @cPickSlipNo = PickSlipNo, 
            @cOrderLineNumber = OrderLineNumber,
            @cLoadkey = Loadkey
         FROM RefKeyLookup WITH (NOLOCK) 
         WHERE PickDetailKey = @cPickDetailKey
   
         -- Split RefKeyLookup
         IF @@ROWCOUNT > 0
         BEGIN
            -- Insert into
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)
            VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 182956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END
         
         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            QTY = 1, 
            CaseID = 'SORTED', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(),
            TRAFFICCOP=NULL
         WHERE PickDetailKey = @cPickDetailKey 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 182957
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END

      -- PackDetail (One pickslip one carton)
      IF @cUpdatePackDetail = '1'
      BEGIN
         
         DECLARE @cLabelLine NVARCHAR(20)
         DECLARE @cLabelNo NVARCHAR(20)

         -- Get PickSlipNo
         SET @cPickSlipNo = ''
         SELECT @cPickslipno = PickSlipNo 
         FROM dbo.PackHeader WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         -- PackHeader
         IF @cPickSlipNo = ''
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
            
            IF @cPickSlipNo = ''
            BEGIN
               -- Generate PickSlipNo
               EXECUTE dbo.nspg_GetKey
                  'PICKSLIP',
                  9,
                  @cPickslipNo   OUTPUT,
                  @bSuccess      OUTPUT,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT  

               IF @nErrNo <> 0
                  GOTO RollBackTran
   
               SET @cPickslipNo = 'P' + @cPickslipNo
            END

            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey)
            VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101765
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
               GOTO RollBackTran
            END
         END
         -- Get carton no
         SET @nCartonNo = 0
         SELECT @nCartonNo = CartonNo,
                @cLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo

         -- PackDetail
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND SKU=@cSKU)
         BEGIN

            -- Get next LabelLine
            IF @nCartonNo = 0
            BEGIN
               SET @cLabelLine = '00001'

               EXEC isp_GenUCCLabelNo
                  @cStorerKey,
                  @cLabelNo      OUTPUT, 
                  @bSuccess      OUTPUT,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 100402
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PackDetail (NOLOCK)
               WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
            END
         
            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID,RefNo2 ) 
            VALUES
               (@cPickSlipNo, '1', @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @cDropID,@cLoc ) --yeekung02
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101766
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
               GOTO RollBackTran
            END     
         END
         ELSE
         BEGIN
            -- Update Packdetail
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
               QTY = QTY + @nQTY, 
               EditWho = 'rdt.' + SUSER_SNAME(), 
               EditDate = GETDATE(), 
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND SKU=@cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101767
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END
         END

         -- End order if fully sorted
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) 
							   WHERE OrderKey = @cOrderKey 
							   AND CaseID ='')
         BEGIN
             -- Pack confirm
            UPDATE PackHeader SET 
               Status = '9' 
            WHERE PickSlipNo = @cPickSlipNo
               AND Status <> '9'
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101768
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
               GOTO RollBackTran
            END

      	   SET @cPackLight = rdt.RDTGetConfig( @nFunc, 'PackLight', @cStorerKey)
      	   
            IF EXISTS(SELECT 1 FROM ORDERS(NOLOCK) 
                      WHERE orderkey=@cOrderKey
                      AND specialhandling<>'Y')
            BEGIN
               SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightModeEnd', @cStorerKey)
            END
            ELSE
            BEGIN
               SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightModeEnd2', @cStorerKey)
            END

			   EXEC  PTL.isp_PTL_TerminateModuleSingle
			   @cStorerKey
            ,@nFunc
            ,@cStation
			   ,@cPosition
			   ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

            IF @cPackLight = '1'
            BEGIN
         	   SELECT 
         	      @cPosition = DevicePosition,
         	      @cIPAddress = IPAddress
         	   FROM deviceProfile WITH (NOLOCK)
         	   WHERE deviceID = @cStation
         	   AND loc = @cLoc
         	   AND DeviceType = 'station'
         	   AND logicalName = 'Pack'

               SELECT @nQTY_Pack=SUM(qty)
               FROM PACKDETAIL (NOLOCK)
               where pickslipno=@cPickslipno

               SET @cDisplay ='P' + cast (@nQTY_Pack AS NVARCHAR(3))

         
               EXEC PTL.isp_PTL_LightUpLoc
                  @n_Func           = @nFunc
                 ,@n_PTLKey         = 0
                 ,@c_DisplayValue   = @cDisplay
                 ,@b_Success        = @bSuccess    OUTPUT    
                 ,@n_Err            = @nErrNo      OUTPUT  
                 ,@c_ErrMsg         = @cErrMsg     OUTPUT
                 ,@c_DeviceID       = @cStation
                 ,@c_DevicePos      = @cPosition
                 ,@c_DeviceIP       = @cIPAddress  
                 ,@c_LModMode       = @cLightMode
               IF @nErrNo <> 0
                  GOTO RollBackTran

               IF NOT EXISTS (SELECT 1 
                          FROM PICKDETAIL PD (NOLOCK)
                          JOIN ORDERS O (NOLOCK) ON PD.orderkey=O.Orderkey
                          WHERE O.loadkey=@cLoadKey
                          AND PD.storerkey=@cStorerKey
                          AND PD.caseid='')
               BEGIN
                  SELECT 
         	         @cPosition = DevicePosition,
         	         @cIPAddress = IPAddress
         	      FROM deviceProfile WITH (NOLOCK)
         	      WHERE deviceID = @cStation
         	      AND DeviceType = 'station'
         	      AND logicalName = 'BATCH'


                  EXEC PTL.isp_PTL_LightUpLoc
                     @n_Func           = @nFunc
                    ,@n_PTLKey         = 0
                    ,@c_DisplayValue   = 'ENDS' 
                    ,@b_Success        = @bSuccess    OUTPUT    
                    ,@n_Err            = @nErrNo      OUTPUT  
                    ,@c_ErrMsg         = @cErrMsg     OUTPUT
                    ,@c_DeviceID       = @cStation
                    ,@c_DevicePos      = @cPosition
                    ,@c_DeviceIP       = @cIPAddress  
                    ,@c_LModMode       = '99'
                    ,@c_DeviceModel    = 'BATCH'
                  IF @nErrNo <> 0
                     GOTO ROLLBACKTRAN
               END
            END
                       
         END
         ELSE
         BEGIN

			   EXEC  PTL.isp_PTL_TerminateModuleSingle
				   @cStorerKey
               ,@nFunc
               ,@cStation
				   ,@cPosition
				   ,@bSuccess    OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
 
            ---- Off all lights
            --EXEC PTL.isp_PTL_TerminateModule
            --    @cStorerKey
            --   ,@nFunc
            --   ,@cStation
            --   ,'STATION'
            --   ,@bSuccess    OUTPUT
            --   ,@nErrNo       OUTPUT
            --   ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      
      END
      COMMIT TRAN isp_803PTL_Confirm08
      GOTO Quit
   END
   ELSE IF SUBSTRING(@cInputValue,1,1) = 'P'
   BEGIN

      DECLARE  @cLabelPrinter NVARCHAR(20),
               @cPaperPrinter NVARCHAR(20),
               @cDPosition  NVARCHAR(20),
               @cDPIPAddress NVARCHAR(20),
               @cCartonNoS    NVARCHAR(20),
               @cCartonNoE    NVARCHAR(20)

      DECLARE @tShipLABEL VariableTable
      DECLARE @tVASLABEL VariableTable
      DECLARE @tDNotes VariableTable

      SELECT @cDPosition=deviceposition,
             @cDPIPAddress = ipaddress
      FROM DEVICEPROFILE (NOLOCK)
      WHERE loc=@cLoc
         AND storerkey=@cStorerkey
         AND deviceid=@cStation
         and DevicePosition<>@cPosition

         -- Get booking info
      SELECT 
         @cDropID = DropID, 
         @cOrderKey = OrderKey, 
         @cLoadKey = loadkey,
         @cSKU = SKU,
         @cWaveKey = wavekey
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      WHERE IPAddress = @cDPIPAddress
         AND Position = @cDPosition

      SELECT   @cPickSlipNo=PD.pickslipno,
               @cCartonNoS =PD.cartonno,
               @cCartonNoE =PD.cartonno
      FROM PACKHEADER PH (NOLOCK) 
      JOIN PACKDETAIL PD (NOLOCK) ON PH.pickslipno=PD.pickslipno
      WHERE ORDERKEY=@cOrderKey
         AND PD.storerkey=@cStorerKey

      /*
      SELECT @cLabelPrinter = udf01      
            ,@cPaperPrinter = udf02      
      FROM codelkup WITH (NOLOCK)      
      WHERE listname='PTLPrinter'
      AND CODE=@cStation
      AND storerkey=@cStorerKey
      */

      IF @cShipLbl <>''
      BEGIN 
         INSERT INTO @tShipLABEL (Variable, Value) VALUES 
            ( '@cPickslipno',    @cPickslipNo), 
            ( '@cCartonNoS',     @cCartonNoS), 
            ( '@cCartonNoE',     @cCartonNoE)  

         -- Print label
         EXEC RDT.rdt_Print '99', @nFunc, @cLangCode, '4', '1', @cFacility, @cStorerkey, @cStation, @cStation, --@cLabelPrinter, @cPaperPrinter, 
            @cShipLbl, -- Report type
            @tShipLABEL, -- Report params
            'isp_803PTL_Confirm08', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            '1',
            ''  
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      IF @cVasLbl <>''
      BEGIN 
          IF EXISTS(SELECT 1 FROM ORDERS(NOLOCK) 
                      WHERE orderkey=@cOrderKey
                      AND specialhandling='Y')
          BEGIN
            INSERT INTO @tVASLABEL (Variable, Value) VALUES ( '@cOrderkey',      @cOrderkey)  

            --Print label
            EXEC RDT.rdt_Print '99', @nFunc, @cLangCode, '4', '1', @cFacility, @cStorerkey, @cStation, @cStation, --@cLabelPrinter, @cPaperPrinter, 
               @cVasLbl, -- Report type
               @tVASLABEL, -- Report params
               'isp_803PTL_Confirm08', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               '1',
               ''  

            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END

      IF @cDNotesLbl <>''
      BEGIN  
         INSERT INTO @tDNotes (Variable, Value) VALUES ( '@cOrderKey',      @cOrderKey)  

         -- Print label
         EXEC RDT.rdt_Print '99', @nFunc, @cLangCode, '4', '1', @cFacility, @cStorerkey, @cStation, @cStation, --@cLabelPrinter, @cPaperPrinter, 
            @cDNotesLbl, -- Report type
            @tDNotes, -- Report params
            'isp_803PTL_Confirm08', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            '1',
            ''  
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      EXEC  PTL.isp_PTL_TerminateModuleSingle
			@cStorerKey
         ,@nFunc
         ,@cStation
			,@cPosition
			,@bSuccess    OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      IF NOT EXISTS (SELECT 1
                     FROM ptl.LightStatus LS (nolock)
                     JOIN deviceprofile DP (NOLOCK) ON LS.deviceid=DP.deviceid and LS.DevicePosition=DP.deviceposition
                     WHERE displayvalue<>''
                     AND DP.deviceid=@cStation
                     AND DP.LogicalName='PACK') 
         AND NOT EXISTS(SELECT 1
                     FROM PICKDETAIL PD (Nolock) JOIN
                           ORDERS O ON pd.orderkey=O.orderkey
                     WHERE O.loadkey=@cLoadkey
                     AND PD.storerkey=@cstorerkey
                     AND caseID = '')
      BEGIN
         DELETE rdt.rdtPTLPieceLog where Station=@cStation

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 101768
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
            GOTO RollBackTran
         END

         SELECT 
         	@cPosition = DevicePosition,
         	@cIPAddress = IPAddress
         FROM deviceProfile WITH (NOLOCK)
         WHERE deviceID = @cStation
         AND DeviceType = 'station'
         AND logicalName = 'BATCH'


         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
            ,@n_PTLKey         = 0
            ,@c_DisplayValue   = 'ENDP' 
            ,@b_Success        = @bSuccess    OUTPUT    
            ,@n_Err            = @nErrNo      OUTPUT  
            ,@c_ErrMsg         = @cErrMsg     OUTPUT
            ,@c_DeviceID       = @cStation
            ,@c_DevicePos      = @cPosition
            ,@c_DeviceIP       = @cIPAddress  
            ,@c_LModMode       = '99'
            ,@c_DeviceModel    = 'BATCH'
         IF @nErrNo <> 0
            GOTO ROLLBACKTRAN
      END

      COMMIT TRAN isp_803PTL_Confirm08
      GOTO Quit
   END
   ELSE
   BEGIN
      GOTO ROLLBACKTRAN 
   END
   GOTO Quit

RollBackTran:  
   ROLLBACK TRAN isp_803PTL_Confirm08 -- Only rollback change made here  
  
END TRY
BEGIN CATCH

   SET @nSPErrNo = @nErrNo
   SET @cSPErrMSG = @cErrMsg

      -- Check error that cause trans become uncommitable, that need to rollback
   IF XACT_STATE() = -1 --(yeekung03)
      ROLLBACK TRAN

   IF isnull(@cInputValue,'')=''
      SET @cInputValue='1'

   -- RelightUp
   EXEC PTL.isp_PTL_LightUpLoc
      @n_Func           = @nFunc
     ,@n_PTLKey         = 0
     ,@c_DisplayValue   = @cInputValue
     ,@b_Success        = @bSuccess    OUTPUT
     ,@n_Err            = @nErrNo      OUTPUT
     ,@c_ErrMsg         = @cErrMsg     OUTPUT
     ,@c_DeviceID       = @cStation
     ,@c_DevicePos      = @cPosition
     ,@c_DeviceIP       = @cIPAddress
     ,@c_LModMode       = '99'

   IF ISNULL(@nSPErrNo , 0 ) <> '0'  AND ISNULL(@nErrNo , 0 ) = '0'
   BEGIN
      SET @nErrNo = @nSPErrNo
      SET @cErrMsg = @cSPErrMSG
   END

END CATCH

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO