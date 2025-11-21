SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CartonPack_Confirm                              */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: full carton pack                                            */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-05-29   1.0  James    WMS9064. Created                          */
/* 2019-09-11   1.1  Ung      WMS-9064 Carton manifest after pack info  */
/*                            Clean up source                           */
/* 2019-09-30   1.2  Ung      WMS-10638 Add multi SKU carton ID         */
/* 2020-01-10   1.3  Ung      WMS-9064 Fix PackHeader create            */
/* 2021-08-23   1.4  James    WMS-17751 Add AssignPackLabelToOrdCfg     */
/* 2023-01-13   1.5  Ung      WMS-21489 Update PackInfo                 */
/* 2023-01-30   1.6  Ung      WMS-21570 Add @cPrintPackList param       */ 
/************************************************************************/

CREATE   PROC [RDT].[rdt_CartonPack_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @cType            NVARCHAR( 10), --CHECK/CONFIRM
   @tConfirm         VariableTable READONLY, 
   @cDoc1Value       NVARCHAR( 20),
   @cCartonID        NVARCHAR( 20),
   @cCartonSKU       NVARCHAR( 20),
   @nCartonQTY       INT, 
   @cPackInfo        NVARCHAR( 4)  = '', 
   @cCartonType      NVARCHAR( 10) = '',
   @fCube            FLOAT         = 0,
   @fWeight          FLOAT         = 0,
   @cPackInfoRefNo   NVARCHAR( 20) = '',
   @cPickSlipNo      NVARCHAR( 10) OUTPUT,
   @nCartonNo        INT           OUTPUT,
   @cLabelNo         NVARCHAR( 20) OUTPUT,
   @cPrintPackList   NVARCHAR( 1)  OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   DECLARE @cSQL       NVARCHAR( MAX)
   DECLARE @cSQLParam  NVARCHAR( MAX)
   DECLARE @cConfirmSP NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT

   -- Get storer config
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''  

   /***********************************************************************************************
                                         Custom check / confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, @tConfirm, ' + 
            ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @fCube, @fWeight, @cPackInfoRefNo, ' + 
            ' @cPickSlipNo OUTPUT, @nCartonNo OUTPUT, @cLabelNo OUTPUT, @cPrintPackList OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,                    ' +
            '@nFunc           INT,                    ' +
            '@cLangCode       NVARCHAR( 3),           ' +
            '@nStep           INT,                    ' + 
            '@nInputKey       INT,                    ' + 
            '@cStorerKey      NVARCHAR( 15),          ' +
            '@cFacility       NVARCHAR( 5),           ' + 
            '@cType           NVARCHAR( 10),         ' +
            '@tConfirm        VariableTable READONLY, ' +
            '@cDoc1Value      NVARCHAR( 20),          ' + 
            '@cCartonID       NVARCHAR( 20),          ' + 
            '@cCartonSKU      NVARCHAR( 20),          ' + 
            '@nCartonQTY      INT,                    ' + 
            '@cPackInfo       NVARCHAR( 4),           ' + 
            '@cCartonType     NVARCHAR( 10),          ' + 
            '@fCube           FLOAT,                  ' + 
            '@fWeight         FLOAT,                  ' + 
            '@cPackInfoRefNo  NVARCHAR( 20),          ' + 
            '@cPickSlipNo     NVARCHAR( 10) OUTPUT,   ' + 
            '@nCartonNo       INT           OUTPUT,   ' + 
            '@cLabelNo        NVARCHAR( 20) OUTPUT,   ' + 
            '@cPrintPackList  NVARCHAR( 1)  OUTPUT,   ' + 
            '@nErrNo          INT           OUTPUT,   ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT    '
         
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, @tConfirm, 
            @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @fCube, @fWeight, @cPackInfoRefNo, 
            @cPickSlipNo OUTPUT, @nCartonNo OUTPUT, @cLabelNo OUTPUT, @cPrintPackList OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
         GOTO Quit
      END
   END


   /***********************************************************************************************
                                             Standard check
   ***********************************************************************************************/
   DECLARE @nRowCount      INT
   DECLARE @bSuccess       INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 10) = ''
   DECLARE @cOrderKey      NVARCHAR( 10) = ''
   DECLARE @cLoadKey       NVARCHAR( 10) = ''
   DECLARE @cPickFilter    NVARCHAR( MAX) = ''

   DECLARE @cMultiSKUCartonID    NVARCHAR( 1)
   DECLARE @cUpdatePickDetail    NVARCHAR( 1)
   DECLARE @cPickDetailCartonID  NVARCHAR( 20)
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)
   DECLARE @cPackHeaderTypeSP    NVARCHAR( 20)
   DECLARE @cPackHeaderTypeDetacted NVARCHAR( 10) = ''
   DECLARE @cAssignPackLabelToOrd   NVARCHAR(1)
      
   -- Storer configure
   SET @cMultiSKUCartonID = rdt.RDTGetConfig( @nFunc, 'MultiSKUCartonID', @cStorerKey) 
   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey) 

   SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)
   IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE
      SET @cPackDetailCartonID = 'DropID'
   SET @cPackHeaderTypeSP = rdt.RDTGetConfig( @nFunc, 'PackHeaderTypeSP', @cStorerKey)
   IF @cPackHeaderTypeSP = '0'
      SET @cPackHeaderTypeSP = ''
   SET @cPickDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PickDetailCartonID', @cStorerKey)
   IF @cPickDetailCartonID NOT IN ('DropID', 'CaseID')
      SET @cPickDetailCartonID = 'DropID'

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

   -- Check carton valid
   SET @cSQL = 
      ' SELECT TOP 1 ' + 
         ' @cOrderKey = OrderKey ' + 
      ' FROM dbo.PickDetail PD (NOLOCK) ' + 
      ' WHERE PD.StorerKey = @cStorerKey ' + 
         ' AND PD.Status <= ''5'' ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND PD.QTY > 0 ' + 
         ' AND PD.' + TRIM( @cPickDetailCartonID) + ' = @cCartonID ' + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
   
   SET @cSQLParam = 
      ' @cStorerKey  NVARCHAR( 15),        ' + 
      ' @cCartonID   NVARCHAR( 20),        ' + 
      ' @cOrderKey   NVARCHAR( 10) OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam
      ,@cStorerKey
      ,@cCartonID 
      ,@cOrderKey OUTPUT

   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 144201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invaild carton
      GOTO Quit
   END

   SET @cPickSlipNo = '' 

   -- Get PickSlipNo (customize)
   IF @cPackHeaderTypeSP <> 'ORDER' AND
      @cPackHeaderTypeSP <> 'LOAD'  AND
      @cPackHeaderTypeSP <> ''      
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cPackHeaderTypeSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackHeaderTypeSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, @tConfirm, ' + 
            ' @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @fCube, @fWeight, @cPackInfoRefNo, ' + 
            ' @cOrderKey, @cPackHeaderTypeSP OUTPUT, @cPickSlipNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile            INT,                    ' +
            '@nFunc              INT,                    ' +
            '@cLangCode          NVARCHAR( 3),           ' +
            '@nStep              INT,                    ' + 
            '@nInputKey          INT,                    ' + 
            '@cStorerKey         NVARCHAR( 15),          ' +
            '@cFacility          NVARCHAR( 5),           ' + 
            '@cType              NVARCHAR( 10),         ' +
            '@tConfirm           VariableTable READONLY, ' +
            '@cDoc1Value         NVARCHAR( 20),          ' + 
            '@cCartonID          NVARCHAR( 20),          ' + 
            '@cCartonSKU         NVARCHAR( 20),          ' + 
            '@nCartonQTY         INT,                    ' + 
            '@cPackInfo          NVARCHAR( 4),           ' + 
            '@cCartonType        NVARCHAR( 10),          ' + 
            '@fCube              FLOAT,                  ' + 
            '@fWeight            FLOAT,                  ' + 
            '@cPackInfoRefNo     NVARCHAR( 20),          ' + 
            '@cOrderKey          NVARCHAR( 10),          ' + 
            '@cPackHeaderTypeSP  NVARCHAR( 10) OUTPUT,   ' + 
            '@cPickSlipNo        NVARCHAR( 10) OUTPUT,   ' + 
            '@nErrNo             NVARCHAR( 20) OUTPUT,   ' +
            '@cErrMsg            NVARCHAR( 20) OUTPUT    ' 
         
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, @tConfirm, 
            @cDoc1Value, @cCartonID, @cCartonSKU, @nCartonQTY, @cPackInfo, @cCartonType, @fCube, @fWeight, @cPackInfoRefNo, 
            @cOrderKey, @cPackHeaderTypeSP OUTPUT, @cPickSlipNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   
   -- Get PickSlipNo (discrete)
   IF @cPickSlipNo = '' 
   BEGIN
      IF @cPackHeaderTypeSP IN ('', 'ORDER')
      BEGIN
         SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
         IF @cPickSlipNo = ''  
            SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Auto detact, and found, mark as detacted
         IF @cPackHeaderTypeSP = '' AND @cPickSlipNo <> '' 
            SET @cPackHeaderTypeDetacted = 'ORDER'
      END
   END
   
   -- Get PickSlipNo (conso)
   IF @cPickSlipNo = '' 
   BEGIN
      IF @cPackHeaderTypeSP IN ('', 'LOAD')
      BEGIN
         SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey         
         IF @cLoadKey = '' 
         BEGIN
            SET @nErrNo = 144202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No LoadKey
            GOTO Quit
         END

         SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = ''
         IF @cPickSlipNo = ''  
            SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey AND OrderKey = ''

         -- Auto detact, and found, mark as detacted
         IF @cPackHeaderTypeSP = '' AND @cPickSlipNo <> '' 
            SET @cPackHeaderTypeDetacted = 'LOAD'
      END
   END
   
   -- Check PickSlip
   IF @cPickSlipNo = '' 
   BEGIN
      IF @cPackHeaderTypeSP = '' -- Auto detact, but not create
      BEGIN
         SET @nErrNo = 144203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickSlipNo
         GOTO Quit
      END
   END
   
   -- Check carton packed
   SET @nRowcount = 0
   SELECT @nRowcount = ISNULL( 
      CASE @cPackDetailCartonID 
         WHEN 'DropID'  THEN (SELECT TOP 1 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cCartonID)
         WHEN 'LabelNo' THEN (SELECT TOP 1 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cCartonID)
         WHEN 'RefNo'   THEN (SELECT TOP 1 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND RefNo = @cCartonID)
         WHEN 'RefNo2'  THEN (SELECT TOP 1 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND RefNo2 = @cCartonID)
         WHEN 'UPC'     THEN (SELECT TOP 1 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UPC = @cCartonID)
      END, 0)
   IF @nRowCount = 1
   BEGIN
      SET @nErrNo = 144204
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton packed
      GOTO Quit
   END

   IF @cType = 'CHECK'
      GOTO Quit

   /***********************************************************************************************
                                              Standard confirm
   ***********************************************************************************************/
   BEGIN TRAN
   SAVE TRAN rdt_CartonPack_Confirm

   -- Get PickSlipNo  
   IF @cPickSlipNo = '' 
   BEGIN
      EXECUTE dbo.nspg_GetKey  
         'PICKSLIP',  
         9,  
         @cPickSlipNo   OUTPUT,  
         @bSuccess      OUTPUT,  
         @nErrNo        OUTPUT,  
         @cErrMsg       OUTPUT    
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      SET @cPickSlipNo = 'P' + @cPickSlipNo  
   END
   
   -- PickHeader
   IF NOT EXISTS( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
   BEGIN
      -- Specified as ORDER, or auto detacted as ORDER
      IF @cPackHeaderTypeSP = 'ORDER' OR @cPackHeaderTypeDetacted = 'ORDER'
      BEGIN
         INSERT INTO dbo.PickHeader (PickHeaderKey, StorerKey, OrderKey, ExternOrderKey, Priority, Type, Zone, LoadKey)
         VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, '', '5', '5', '3', '')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144205
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END

      -- Specified as LOAD, or auto detacted as LOAD
      ELSE IF @cPackHeaderTypeSP = 'LOAD' OR @cPackHeaderTypeDetacted = 'LOAD'
      BEGIN
         INSERT INTO dbo.PickHeader (PickHeaderKey, StorerKey, OrderKey, ExternOrderKey, Priority, Type, Zone, LoadKey)
         VALUES (@cPickSlipNo, @cStorerKey, '', @cLoadKey, '5', '5', '5', @cLoadKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144206
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END
   END

   -- PackHeader
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      -- Specified as ORDER, or auto detacted as ORDER
      IF @cPackHeaderTypeSP = 'ORDER' OR @cPackHeaderTypeDetacted = 'ORDER'
      BEGIN
         DECLARE @cConsigneeKey NVARCHAR( 15)
         SELECT @cConsigneeKey = ConsigneeKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
         IF @cLoadKey = ''
            SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey         

         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, ConsigneeKey, LoadKey)
         VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cConsigneeKey, @cLoadKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END

      -- Specified as LOAD, or auto detacted as LOAD
      ELSE IF @cPackHeaderTypeSP = 'LOAD' OR @cPackHeaderTypeDetacted = 'LOAD'
      BEGIN
         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, ConsigneeKey, LoadKey)
         VALUES (@cPickSlipNo, @cStorerKey, '', '', @cLoadKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144208
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
            GOTO RollBackTran
         END
      END
   END

   -- PickingInfo (scan-in)
   IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo)
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
         SET @nErrNo = 144209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************
                                              PackDetail
   ***********************************************************************************************/
   DECLARE @cSKU       NVARCHAR( 20) = ''
   DECLARE @nSKUCount  INT = 0
   DECLARE @nQTY       INT = 0
   DECLARE @cLabelLine NVARCHAR( 5)

   -- GET SKU, QTY
   SET @cSQL = 
      ' SELECT ' + 
         ' @cSKU = SKU, ' + 
         ' @nQTY = ISNULL( SUM( PD.QTY), 0) ' + 
      ' FROM dbo.PickDetail PD (NOLOCK) ' + 
      ' WHERE PD.StorerKey = @cStorerKey ' + 
         ' AND PD.Status <= ''5'' ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND PD.QTY > 0 ' + 
         ' AND PD.' + TRIM( @cPickDetailCartonID) + ' = @cCartonID ' + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
      ' GROUP BY PD.SKU ' + 
      ' SET @nSKUCount = @@ROWCOUNT '
   
   SET @cSQLParam = 
      ' @cStorerKey  NVARCHAR( 15),        ' + 
      ' @cCartonID   NVARCHAR( 20),        ' + 
      ' @cSKU        NVARCHAR( 20) OUTPUT, ' + 
      ' @nQTY        INT           OUTPUT, ' + 
      ' @nSKUCount   INT           OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam
      ,@cStorerKey
      ,@cCartonID 
      ,@cSKU      OUTPUT
      ,@nQTY      OUTPUT 
      ,@nSKUCount OUTPUT

   -- Check carton valid
   IF @nSKUCount = 0
   BEGIN
      SET @nErrNo = 144210
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
      GOTO RollBackTran
   END

   -- Check multi SKU
   IF @nSKUCount > 1
   BEGIN
      -- Multi SKU carton ID not allowed
      IF @cMultiSKUCartonID <> '1'
      BEGIN
         SET @nErrNo = 144211
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUCarton
         GOTO RollBackTran
      END
   END

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
         DECLARE @cGenLabelNo_SP NVARCHAR( 20)
         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
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
               SET @nErrNo = 144212
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO RollBackTran
            END
         END
      END

      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 144213
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
      SET @nErrNo = 144214
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

   -- Multi SKU carton ID
   IF @cMultiSKUCartonID = '1' AND @nSKUCount > 1
   BEGIN
      -- GET SKU, QTY (exclude the 1st SKU)
      SET @cSQL = 
         ' INSERT INTO dbo.PackDetail ' + 
            ' (PickSlipNo, CartonNo, LabelNo, StorerKey, DropID, RefNo, RefNo2, UPC, ' +  
            ' AddWho, AddDate, EditWho, EditDate, ' + 
            ' LabelLine, SKU, QTY)' + 
         ' SELECT @cPickSlipNo, @nCartonNo, @cLabelNo, @cStorerKey, @cDropID, @cRefNo, @cRefNo2, @cUPC, ' + 
            ' ''rdt.'' + SUSER_SNAME(), GETDATE(), ''rdt.'' + SUSER_SNAME(), GETDATE(), ' +
            ' RIGHT( ''0000'' + CAST( ROW_NUMBER() OVER (ORDER BY SKU) + 1 AS NVARCHAR(5)), 5), ' + 
            ' PD.SKU, ISNULL( SUM( PD.QTY), 0) ' + 
         ' FROM dbo.PickDetail PD (NOLOCK) ' + 
         ' WHERE PD.StorerKey = @cStorerKey ' + 
            ' AND PD.Status <= ''5'' ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.SKU <> @cSKU ' + 
            ' AND PD.' + TRIM( @cPickDetailCartonID) + ' = @cCartonID ' + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
         ' GROUP BY PD.SKU ' + 
         ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
      
      SET @cSQLParam = 
         ' @cPickSlipNo NVARCHAR( 10), ' + 
         ' @nCartonNo   INT,           ' + 
         ' @cLabelNo    NVARCHAR( 20), ' + 
         ' @cStorerKey  NVARCHAR( 15), ' + 
         ' @cDropID     NVARCHAR( 20), ' + 
         ' @cRefNo      NVARCHAR( 20), ' + 
         ' @cRefNo2     NVARCHAR( 30), ' + 
         ' @cUPC        NVARCHAR( 30), ' + 
         ' @cCartonID   NVARCHAR( 20), ' +
         ' @cSKU        NVARCHAR( 20), ' + 
         ' @nRowCount   INT OUTPUT,    ' +
         ' @nErrNo      INT OUTPUT     '

      SET @nRowCount = 0

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam
         ,@cPickSlipNo = @cPickSlipNo 
         ,@nCartonNo   = @nCartonNo   
         ,@cLabelNo    = @cLabelNo    
         ,@cStorerKey  = @cStorerKey  
         ,@cDropID     = @cDropID     
         ,@cRefNo      = @cRefNo      
         ,@cRefNo2     = @cRefNo2     
         ,@cUPC        = @cUPC        
         ,@cCartonID   = @cCartonID   
         ,@cSKU        = @cSKU        
         ,@nRowCount   = @nRowCount OUTPUT
         ,@nErrNo      = @nErrNo    OUTPUT
         
      IF @nErrNo <> 0 OR @nRowCount = 0
      BEGIN
         SET @nErrNo = 144215
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
         GOTO RollBackTran
      END
   END


   /***********************************************************************************************
                                              UCC
   ***********************************************************************************************/
   DECLARE @cUCCNo NVARCHAR(20) = ''
   DECLARE @cUCCStatus NVARCHAR(1) = ''
   
   -- Get UCC info
   SELECT TOP 1
      @cUCCNo = UCCNo, 
      @cUCCStatus = Status
   FROM UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND UCCNo = @cCartonID
         
   -- Mark UCC packed
   IF @cUCCNo <> '' AND @cUCCStatus < '5'
   BEGIN
      UPDATE UCC SET
         Status = '6', 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE(), 
         TrafficCop = NULL
      WHERE StorerKey = @cStorerKey 
         AND UCCNo = @cUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 144216
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END
   END


   /***********************************************************************************************
                                              PackInfo
   ***********************************************************************************************/
   IF @cPackInfo <> ''
   BEGIN
      -- Get PackDetail info
      DECLARE @nPackInfoQTY INT
      SELECT @nPackInfoQTY = SUM( QTY) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo         

      IF EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         UPDATE dbo.PackInfo SET
            CartonType = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN CartonType ELSE @cCartonType    END, 
            Cube       = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN Cube       ELSE @fCube          END, 
            Weight     = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN Weight     ELSE @fWeight        END, 
            RefNo      = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN RefNo      ELSE @cPackInfoRefNo END, 
            UCCNo      = @cUCCNo, 
            QTY        = @nPackInfoQTY, 
            EditDate   = GETDATE(), 
            EditWho    = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144217
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY, Weight, Cube, CartonType, RefNo, UCCNo)
         VALUES (@cPickSlipNo, @nCartonNo, @nQTY, @fWeight, @fCube, @cCartonType, @cPackInfoRefNo, @cUCCNo)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144218
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO RollBackTran
         END
      END
   END


   /***********************************************************************************************
                                              PickDetail
   ***********************************************************************************************/
   IF @cUpdatePickDetail = '1'
   BEGIN
      DECLARE @cPickConfirmStatus NVARCHAR( 1)
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus NOT IN ('3', '5')
         SET @cPickConfirmStatus = '5'

      -- Loop PickDetail
      DECLARE @curPD CURSOR 
      SET @cSQL = 
         ' SELECT PD.PickDetailKey ' + 
         ' FROM dbo.PickDetail PD (NOLOCK) ' + 
         ' WHERE PD.StorerKey  = @cStorerKey ' + 
            ' AND PD.Status < ''5'' ' + 
            ' AND PD.Status <> @cPickConfirmStatus ' +  
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.' + TRIM( @cPickDetailCartonID) + ' = @cCartonID ' + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END

      -- Open cursor
      SET @cSQL = 
         ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
            @cSQL + 
         ' OPEN @curPD ' 
      
      SET @cSQLParam = 
         ' @curPD       CURSOR OUTPUT, ' + 
         ' @cStorerKey  NVARCHAR( 15), ' + 
         ' @cCartonID   NVARCHAR( 20), ' + 
         ' @cPickConfirmStatus NVARCHAR( 1) '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @curPD OUTPUT, @cStorerKey, @cCartonID, @cPickConfirmStatus

      -- OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail SET
            Status = @cPickConfirmStatus, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144219
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OffSetPDtlFail
            GOTO RollBackTran
         END   
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
   END   


   /***********************************************************************************************
                                              Pack confirm
   ***********************************************************************************************/
   -- Pack confirm
   IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')
   BEGIN
      -- Pack confirm
      EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo
         ,'' --@cFromDropID
         ,'' --@cPackDtlDropID
         ,'' --@cPrintPackList OUTPUT
         ,@nErrNo         OUTPUT
         ,@cErrMsg        OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cAssignPackLabelToOrd = rdt.RDTGetConfig( @nFunc, 'AssignPackLabelToOrd', @cStorerKey)

      IF @cAssignPackLabelToOrd = '1'
      BEGIN
         -- Update packdetail.labelno = pickdetail.caseid
         -- Get storer config
         DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            '', --@c_sku
            'AssignPackLabelToOrdCfg',
            @bSuccess                 OUTPUT,
            @cAssignPackLabelToOrdCfg OUTPUT,
            @nErrNo                   OUTPUT,
            @cErrMsg                  OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

         -- Assign
         IF @cAssignPackLabelToOrdCfg = '1'
         BEGIN
            -- Update PickDetail, base on PackDetail.DropID
            EXEC isp_AssignPackLabelToOrderByLoad
                @cPickSlipNo
               ,@bSuccess OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
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
      @cPickSlipNo = @cPickSlipNo,
      @cCartonID   = @cCartonID,
      @cLabelNo    = @cLabelNo,
      @nCartonNo   = @nCartonNo,
      @cSKU        = @cSKU,
      @nQTY        = @nQTY,
      @cUCC        = @cUCCNo,
      @cRefNo2     = @cDoc1Value

   COMMIT TRAN rdt_CartonPack_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_CartonPack_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO