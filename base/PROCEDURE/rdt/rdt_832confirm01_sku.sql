SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832Confirm01_SKU                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_CartonPack                                       */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-10-29   1.0  James    WMS-10774 Created (rdt_832ExtPack01)      */
/* 2020-07-16   1.1  Ung      WMS-13699 Migrate to this SP              */
/************************************************************************/

CREATE PROC [RDT].[rdt_832Confirm01_SKU] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cType           NVARCHAR( 10),
   @tConfirm        VariableTable READONLY,
   @cDoc1Value      NVARCHAR( 20),
   @cCartonID       NVARCHAR( 20),
   @cCartonSKU      NVARCHAR( 20),
   @nCartonQTY      INT,
   @cPackInfo       NVARCHAR( 4),
   @cCartonType     NVARCHAR( 10),
   @fCube           FLOAT,
   @fWeight         FLOAT,
   @cPackInfoRefNo  NVARCHAR( 20),   
   @cPickSlipNo     NVARCHAR( 10) OUTPUT,
   @nCartonNo       INT           OUTPUT,
   @cLabelNo        NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @n_err          INT
   DECLARE @c_errmsg       NVARCHAR( 20)

   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cPSType        NVARCHAR( 10)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nQTY_PD        INT
   DECLARE @nQTYToPick     INT = 0
   DECLARE @cSKUStatus     NVARCHAR( 10) = ''
   DECLARE @nSKUCnt        INT

   DECLARE @cGenLabelNo_SP       NVARCHAR( 20)
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)  
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cPickFilter          NVARCHAR( MAX) = ''
   DECLARE @cUpdatePickDetail    NVARCHAR( 1)
      
   SET @nErrNo = 0
   SET @nTranCount = @@TRANCOUNT

   -- Storer configure  
   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey) 

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey) 
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''  
   SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)  
   IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE  
      SET @cPackDetailCartonID = 'DropID'  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus IN ( '', '0')
      SET @cPickConfirmStatus = '5'
      
   -- Get pick filter  
   SELECT @cPickFilter = ISNULL( Long, '')  
   FROM CodeLKUP WITH (NOLOCK)   
   WHERE ListName = 'PickFilter'  
      AND Code = @nFunc   
      AND StorerKey = @cStorerKey  
      AND Code2 = @cFacility

   -- Parameter mapping
   SET @cPickSlipNo = @cDoc1Value
   SET @cSKU = @cCartonID

   -- Check blank
   IF @cPickSlipNo = ''
   BEGIN
      SET @nErrNo = 144901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PKSlip
      GOTO Fail
   END
      
   -- Get pickslip info
   SELECT 
      @cZone = Zone, 
      @cLoadKey = ExternOrderKey,
      @cOrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo
      
   -- Check pickslip valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 144902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PKSlip
      GOTO Fail
   END

   -- Get SKU count
   SET @nSKUCnt = 0
   EXEC RDT.rdt_GETSKUCNT
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @bSuccess      OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT
      ,@cSKUStatus  = @cSKUStatus

   -- Check SKU valid
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 144903
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      GOTO Fail
   END

   -- Check multi SKU barcode
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 144904
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
      GOTO Fail
   END

   -- Get SKU
   EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU          OUTPUT
      ,@bSuccess    = @bSuccess      OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT
      ,@cSKUStatus  = @cSKUStatus

   -- Get SKU info
   SELECT @nQTY = CaseCnt
   FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
   WHERE SKU.SKU = @cSKU
      AND SKU.StorerKey = @cStorerKey            

   -- Check case count
   IF ISNULL( @nQTY, 0) = 0
   BEGIN
      SET @nErrNo = 144905
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CaseCnt
      GOTO Quit
   END

   -- Get PickSlip type
   IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
      SET @cPSType = 'XD'
   ELSE IF @cOrderKey <> ''
      SET @cPSType = 'DISCRETE'
   ELSE IF @cLoadKey <> ''
      SET @cPSType = 'CONSO'
   ELSE
      SET @cPSType = 'CUSTOM'

   -- Crossdock picklist   
   If @cPSType = 'XD' 
   BEGIN    
      SET @cSQL =   
         ' SELECT @nQTYToPick = ISNULL( SUM( Qty), 0) ' +   
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +   
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) ' +   
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +   
            ' AND PD.StorerKey = @cStorerKey ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND PD.Status <> ''4'' ' +   
            ' AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
   END
   
   -- Discrete PickSlip
   ELSE IF @cPSType = 'DISCRETE' 
   BEGIN
      SET @cSQL =   
         ' SELECT @nQTYToPick = ISNULL( SUM( Qty), 0) ' +   
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.OrderKey = @cOrderKey ' + 
            ' AND PD.StorerKey = @cStorerKey ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND PD.Status <> ''4'' ' +   
            ' AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
   END
   
   -- Conso PickSlip
   ELSE IF @cPSType = 'CONSO' 
   BEGIN
      SET @cSQL =   
         ' SELECT @nQTYToPick = ISNULL( SUM( Qty), 0) ' +   
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
         ' WHERE LPD.LoadKey = @cLoadKey ' +
            ' AND PD.StorerKey = @cStorerKey ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND PD.Status <> ''4'' ' +   
            ' AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      SET @cSQL =   
         ' SELECT @nQTYToPick = ISNULL( SUM( Qty), 0) ' +   
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.StorerKey = @cStorerKey ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND PD.Status <> ''4'' ' +   
            ' AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  
   END

   SET @nQTYToPick = 0

   SET @cSQLParam =   
      ' @cStorerKey  NVARCHAR( 15), ' +   
      ' @cLoadKey    NVARCHAR( 10), ' +   
      ' @cOrderKey   NVARCHAR( 10), ' + 
      ' @cPickSlipNo NVARCHAR( 10), ' + 
      ' @cSKU        NVARCHAR( 20), ' + 
      ' @cPickConfirmStatus   NVARCHAR( 1), ' +
      ' @nQTYToPick  INT   OUTPUT '
  
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam  
      ,@cStorerKey  
      ,@cLoadKey   
      ,@cOrderKey 
      ,@cPickSlipNo
      ,@cSKU
      ,@cPickConfirmStatus
      ,@nQTYToPick   OUTPUT

   -- Check over pack
   IF @nQTYToPick = 0 OR ( @nQTYToPick < @nQTY)
   BEGIN
      SET @nErrNo = 144906
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Pack
      GOTO Quit
   END

   IF @cType = 'CHECK'  
      GOTO Quit  
  
   /***********************************************************************************************  
                                              Standard confirm  
   ***********************************************************************************************/  
   BEGIN TRAN  
   SAVE TRAN rdt_832Confirm01_SKU  
  
   -- Scan-in  
   IF EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo AND ScanInDate IS NULL)  
   BEGIN  
      DECLARE @cUserName NVARCHAR( 18)
      SET @cUserName = SUSER_SNAME()  
        
      -- Scan in pickslip  
      EXEC dbo.isp_ScanInPickslip  
         @c_PickSlipNo  = @cPickSlipNo,  
         @c_PickerID    = @cUserName,  
         @n_err         = @nErrNo      OUTPUT,  
         @c_errmsg      = @cErrMsg     OUTPUT  
  
      IF @nErrNo <> 0  
      BEGIN  
         SET @nErrNo = 144907  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in  
         GOTO RollBackTran  
      END  
   END  
  
   -- PackHeader  
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
   BEGIN  
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)  
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 144908  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail  
         GOTO RollBackTran  
      END  
   END  
  
   /***********************************************************************************************  
                                              PackDetail  
   ***********************************************************************************************/  
  
   DECLARE @cDropID  NVARCHAR( 20) = ''  
   DECLARE @cRefNo   NVARCHAR( 20) = ''  
   DECLARE @cRefNo2  NVARCHAR( 30) = ''  
   DECLARE @cUPC     NVARCHAR( 30) = ''  
  
   SET @cLabelNo = ''  

   IF @cPackDetailCartonID = 'LabelNo' SET @cLabelNo = @cCartonID ELSE  
   IF @cPackDetailCartonID = 'DropID'  SET @cDropID  = @cCartonID ELSE  
   IF @cPackDetailCartonID = 'RefNo'   SET @cRefNo   = @cCartonID ELSE  
   IF @cPackDetailCartonID = 'RefNo2'  SET @cRefNo2  = @cCartonID ELSE  
   IF @cPackDetailCartonID = 'UPC'     SET @cUPC     = @cCartonID  

   -- Generate labelNo  
   IF @cLabelNo = ''  
   BEGIN  
      DECLARE @cDocType NVARCHAR(1) = ''  
      SELECT @cDocType = DocType FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
        
      IF @cDocType = 'E'  
      BEGIN  
         -- Get current carton no  
         DECLARE @nCurrCartonNo INT  
         SELECT @nCurrCartonNo = ISNULL( MAX( CartonNo), 1)  
         FROM PackDetail WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickslipNo  
            AND QTY > 0  
           
         EXEC isp_EPackCtnTrack03  
             @c_PickSlipNo = @cPickslipNo  
            ,@n_CartonNo   = @nCurrCartonNo -- Current CartonNo  
            ,@c_CTNTrackNo = @cLabelNo OUTPUT  
            ,@b_Success    = @bSuccess OUTPUT  
            ,@n_err        = @nErrNo   OUTPUT  
            ,@c_errmsg     = @cErrMsg  OUTPUT  
      END  
      ELSE  
      BEGIN  
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
               SET @nErrNo = 144909  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
               GOTO RollBackTran  
            END  
         END  
      END  
  
      IF @cLabelNo = ''  
      BEGIN  
         SET @nErrNo = 144910  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
         GOTO RollBackTran  
      END  
   END  
  
   SET @nCartonNo = 0  
   SET @cLabelLine = '00000'  
  
   -- Insert PackDetail  
   INSERT INTO dbo.PackDetail  
      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, RefNo2, UPC,   
      AddWho, AddDate, EditWho, EditDate)  
   VALUES  
      (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID, @cRefNo, @cRefNo2, @cUPC,
      'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 144911  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
      GOTO RollBackTran  
   END  
  
   -- Get system assigned CartonoNo and LabelNo  
   IF @nCartonNo = 0  
   BEGIN  
      -- If insert cartonno = 0, system will auto assign max cartonno  
      SELECT TOP 1   
         @nCartonNo = CartonNo,   
         @cLabelNo = LabelNo  
      FROM PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
         AND SKU = @cSKU  
         AND AddWho = 'rdt.' + SUSER_SNAME()  
      ORDER BY CartonNo DESC -- max cartonno  
   END  

  
   /***********************************************************************************************  
                                              PickDetail  
   ***********************************************************************************************/  
   IF @cUpdatePickDetail = '1'  
   BEGIN  
      -- conso picklist   
      IF @cPSType = 'XD' 
      BEGIN
         SET @cSQL =   
            ' SELECT PD.PickDetailKey, PD.QTY ' +   
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +   
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) ' +   
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +   
               ' AND PD.StorerKey  = @cStorerKey ' +   
               ' AND PD.Status < ''5'' ' +   
               ' AND PD.Status <> @cPickConfirmStatus ' +    
               ' AND PD.Status <> ''4'' ' +   
               ' AND PD.QTY > 0 ' +   
               ' AND PD.SKU = @cSKU ' +   
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END  +
            ' ORDER BY PD.SKU ' 
      END
      
      -- Discrete PickSlip
      ELSE IF @cPSType = 'DISCRETE' 
      BEGIN
         SET @cSQL =   
            ' SELECT PD.PickDetailKey, PD.QTY ' +   
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' WHERE PD.OrderKey = @cOrderKey ' + 
               ' AND PD.StorerKey = @cStorerKey ' +
               ' AND PD.Status < ''5'' ' +            
               ' AND PD.Status <> @cPickConfirmStatus ' +
               ' AND PD.QTY > 0 ' +            
               ' AND PD.Status <> ''4'' ' +   
               ' AND PD.SKU = @cSKU ' +
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END +
            ' ORDER BY PD.SKU ' 
      END
      
      -- CONSO PickSlip
      ELSE IF @cPSType = 'CONSO' 
      BEGIN
         SET @cSQL =   
            ' SELECT PD.PickDetailKey, PD.QTY ' +   
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
            ' WHERE LPD.LoadKey = @cLoadKey ' +
               ' AND PD.StorerKey = @cStorerKey ' +
               ' AND PD.Status < ''5'' ' +
               ' AND PD.Status < @cPickConfirmStatus ' +
               ' AND PD.QTY > 0 ' +
               ' AND PD.Status <> ''4'' ' +   
               ' AND PD.SKU = @cSKU ' +
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END +
            ' ORDER BY PD.SKU ' 
      END
      
      -- Custom PickSlip
      ELSE
      BEGIN
         SET @cSQL =   
            ' SELECT PD.PickDetailKey, PD.QTY ' +   
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
               ' AND PD.StorerKey = @cStorerKey ' +
               ' AND PD.Status < ''5'' ' +
               ' AND PD.Status < @cPickConfirmStatus ' +
               ' AND PD.QTY > 0 ' +
               ' AND PD.Status <> ''4'' ' +   
               ' AND PD.SKU = @cSKU ' +
               CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END +
            ' ORDER BY PD.SKU ' 
      END
   
      -- Open cursor  
      SET @cSQL =   
         ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +   
            @cSQL +   
         ' OPEN @curPD '   
        
      SET @cSQLParam =   
         ' @curPD       CURSOR OUTPUT, ' +   
         ' @cStorerKey     NVARCHAR( 15), ' +   
         ' @cPickSlipNo    NVARCHAR( 10), ' +
         ' @cLoadKey       NVARCHAR( 10), ' +
         ' @cOrderKey      NVARCHAR( 10), ' +
         ' @cSKU           NVARCHAR( 20), ' +   
         ' @cPickConfirmStatus NVARCHAR( 1) '  
  
      DECLARE @curPD CURSOR
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
         @curPD OUTPUT, @cStorerKey, @cPickSlipNo, @cLoadKey, @cOrderKey, @cSKU, @cPickConfirmStatus  
  
      -- OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Exact match
         IF @nQTY_PD = @nQTY
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail SET
               Status = @cPickConfirmStatus,
               DropID = @cLabelNo, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 144912
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY = @nQTY - @nQTY_PD -- Reduce balance
         END
         
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQTY
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail SET
               Status = @cPickConfirmStatus, 
               DropID = @cLabelNo, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 144913
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            ELSE

            SET @nQTY = @nQTY - @nQTY_PD -- Reduce balance
         END
         
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nQTY
         BEGIN
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 144914
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetDetKeyFail
               GOTO RollBackTran
            END

            -- Create a new PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
               @nQTY_PD - @nQTY, -- QTY
               NULL, --TrafficCop,
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 144915
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
               GOTO RollBackTran
            END

            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
            BEGIN
               -- Insert into
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
               FROM RefKeyLookup WITH (NOLOCK) 
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 144916  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail  
                  GOTO RollBackTran  
               END  
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail SET
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 144917
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END

            -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail SET
               Status = @cPickConfirmStatus, 
               DropID = @cLabelNo, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME() 
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 144918
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY = 0 -- Reduce balance
         END

         IF @nQTY = 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
      END  
   END     
  
  
   /***********************************************************************************************  
                                              Pack confirm  
   ***********************************************************************************************/  
   -- Pack confirm  
   IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')  
   BEGIN
      DECLARE @cPackConfirm NVARCHAR(1)
      DECLARE @nPickQTY     INT = 0
      DECLARE @nPackQTY     INT = 0

      -- Calc pack QTY
      SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

      -- Cross dock PickSlip
      IF @cPSType = 'XD'
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
         
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( QTY) 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END

      -- Discrete PickSlip
      ELSE IF @cPSType = 'DISCRETE'
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
         
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cOrderKey
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END
      
      -- Conso PickSlip
      ELSE IF @cPSType = 'CONSO'
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
         
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM PickDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'

         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM PickDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackConfirm = 'N'
         END
      END

      -- Pack confirm
      IF @cPackConfirm = 'Y'
      BEGIN      
         UPDATE PackHeader SET 
            Status = '9', 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()            
         WHERE PickSlipNo = @cPickSlipNo

         SET @nErrNo = @@ERROR 
         IF @nErrNo <> 0
         BEGIN
            -- SET @nErrNo = 0
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')
            GOTO RollBackTran
         END
      END
   END  
  
   -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '3',  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerkey,  
      @cDropID     = @cCartonID, -- CartonID need to add as standard  
      @cPickSlipNo = @cPickSlipNo,  
      @cLabelNo    = @cLabelNo,  
      @cSKU        = @cSKU,  
      @nQTY        = @nQTY,  
      @cRefNo1     = @nCartonNo, -- CartonNo need to add as standard  
      @cRefNo2     = @cDoc1Value  
  
   COMMIT TRAN rdt_832Confirm01_SKU  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_832Confirm01_SKU  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
Fail:

END

GO