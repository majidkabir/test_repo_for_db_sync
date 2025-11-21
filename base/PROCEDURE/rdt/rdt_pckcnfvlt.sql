SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PckCnfVLT                                             */
/*                                                                            */
/* Date        Rev   Author      Purposes                                     */
/* 2024-05-22  1.0   PPA374      Deletes empty packdetail lines.              */
/*                               Inserts new line for each packing iteration. */
/* 2024-10-11  1.1   PXL009      FCR-778 Violet Pack Changes                  */
/* 2024-11-20  1.1.1 PXL009         DropId to LabelNo                         */
/* 2024-11-22  1.1.2 PXL009         Move pickdetail & inventory               */
/* 2024-12-13  1.1.3 PXL009         Move pickdetail improvement               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PckCnfVLT] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20) 
   ,@nQTY            INT
   ,@cUCCNo          NVARCHAR( 20) 
   ,@cSerialNo       NVARCHAR( 30) 
   ,@nSerialQTY      INT
   ,@cPackDtlRefNo   NVARCHAR( 20)
   ,@cPackDtlRefNo2  NVARCHAR( 20)
   ,@cPackDtlUPC     NVARCHAR( 30)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@nCartonNo       INT           OUTPUT
   ,@cLabelNo        NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@nBulkSNO        INT
   ,@nBulkSNOQTY     INT
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)
   ,@nUseStandard    INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DELETE FROM PackDetail
   WHERE PickSlipNo = @cPickSlipNo
      AND LabelNo = @cLabelNo
      AND CartonNo = @nCartonNo
      AND sku = ''
      AND qty = 0

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cConfirmSP     NVARCHAR(20) = ''

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @bSuccess    INT
   DECLARE @cLabelLine  NVARCHAR( 5)
   DECLARE @cNewLine    NVARCHAR( 1)
   DECLARE @cNewCarton  NVARCHAR( 1)
   DECLARE @cDropID     NVARCHAR( 20) = ''
   DECLARE @cRefNo      NVARCHAR( 20) = ''
   DECLARE @cRefNo2     NVARCHAR( 30) = ''
   DECLARE @cUPC        NVARCHAR( 30) = ''    
   
   DECLARE @cGenLabelNo_SP       NVARCHAR( 20)
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)
   DECLARE @cPackByFromDropID    NVARCHAR( 1)

   DECLARE
      @cLoadKey               NVARCHAR( 10),
      @cOrderKey              NVARCHAR( 10),
      @cZone                  NVARCHAR( 18),
      @cOrderConsigneeKey     NVARCHAR( 15),
      @cOrderC_Zip            NVARCHAR( 18),
      @cCustomerPalletType    NVARCHAR( 10),
      @cDefaultConsigneeKey   NVARCHAR( 15),
      @nSKUWeight             FLOAT,
      @nSKUCube               FLOAT,
      @cAddPackValidtn        NVARCHAR( 20),
      @cMoveQTYPack           NVARCHAR( 20),
      @nQTY_Move              INT,
      @nQTY_Bal               INT,
      @nQTY_PD                INT,
      @curPD                  CURSOR,
      @cSourceType            NVARCHAR( 30),
      @cPickDetailKey         NVARCHAR( 18),
      @cLOT                   NVARCHAR( 10),
      @cLOC                   NVARCHAR( 10),
      @cID                    NVARCHAR( 18),
      @cMoveRefKey            NVARCHAR( 10),
      @cPackKey               NVARCHAR( 10),
      @cPackUOM3              NVARCHAR( 10)

   SET @cSourceType = 'rdt_PckCnfVLT'
   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PckCnfVLT -- For rollback or commit only our own transaction

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- PackHeader
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)
   BEGIN      
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 226051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
         GOTO RollBackTran
      END
   END

   -- Storer configure
   SET @cPackByFromDropID = rdt.rdtGetConfig( @nFunc, 'PackByFromDropID', @cStorerKey)
   SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)
   IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE
      SET @cPackDetailCartonID = 'DropID'
   SET @cAddPackValidtn = [rdt].[RDTGetConfig]( @nFunc, N'AddPackValidtn', @cStorerKey)
   SET @cMoveQTYPack = [rdt].[RDTGetConfig]( @nFunc, N'MoveQTYPack', @cStorerKey)
   SET @cDefaultConsigneeKey = [rdt].[RDTGetConfig]( @nFunc, N'AddPackValidtnDefCNEE', @cStorerKey)
   IF ISNULL(@cDefaultConsigneeKey, N'') = N'' OR @cDefaultConsigneeKey = N'0'
   BEGIN
      SET @cDefaultConsigneeKey = N'0000000001'
   END

   -- Save decoded data to which column (initially it was carton ID only, hence the misleading PackDetailCartonID ConfigKey name)
   IF @cPackDetailCartonID = 'DropID'  SET @cDropID  = @cPackDtlDropID ELSE
   IF @cPackDetailCartonID = 'RefNo'   SET @cRefNo   = @cPackDtlRefNo  ELSE
   IF @cPackDetailCartonID = 'RefNo2'  SET @cRefNo2  = @cPackDtlRefNo2 ELSE
   IF @cPackDetailCartonID = 'UPC'     SET @cUPC     = @cPackDtlUPC

   -- Pack by drop ID, the drop ID must present in both PickDetail AND PackDetail, otherwise it can't do over pack checking.
   IF @cPackByFromDropID = '1'
      SET @cDropID = @cFromDropID   
   
   SET @cNewLine = 'N'
   SET @cNewCarton = 'N'
   
   -- New carton, generate labelNo
   IF @nCartonNo = 0 -- 
   BEGIN
      SET @cLabelNo = @cDropID
      
      IF @cUCCNo <> ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'DefaultUCCtoLabelNo', @cStorerkey) = '1'
            SET @cLabelNo = @cUCCNo
      END
      
      IF @cLabelNo = ''
      BEGIN
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
               SET @nErrNo = 226052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO RollBackTran
            END
         END
      END

      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 226053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
         GOTO RollBackTran
      END

      SET @cLabelLine = ''   
      SET @cNewLine = 'Y'
      SET @cNewCarton = 'Y'
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
         SELECT @cLabelLine = LabelLine
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo 
            AND SKU = ''
      
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

   SET @cNewLine = 'Y'

   IF @cNewLine = 'Y'
   BEGIN

      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo AND LabelLine = @cLabelLine AND StorerKey = @cStorerKey)
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
            DropID, RefNo, RefNo2, UPC,
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 
            @cDropID, 
            isnull(@cSerialNo,''),--@cRefNo, 
            @cFromDropID,--@cRefNo2, 
            @cUPC,
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
      END
      ELSE
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
            DropID, RefNo, RefNo2, UPC,
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, 
            (SELECT RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) 
            FROM dbo.PackDetail (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo),
            @cStorerKey, @cSKU, @nQTY, 
            @cDropID, 
            isnull(@cSerialNo,''),--@cRefNo, 
            @cFromDropID,--@cRefNo2,  
            @cUPC,
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
      END

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 226054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
         GOTO RollBackTran
      END

   END
   ELSE
   BEGIN
      -- Update Packdetail
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
         SKU = @cSKU, 
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
         SET @nErrNo = 226055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
         GOTO RollBackTran
      END
   END

   -- Get system assigned CartonoNo AND LabelNo
   IF @nCartonNo = 0
   BEGIN
      -- If insert cartonno = 0, system will auto assign max cartonno
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cLabelLine = LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND SKU = @cSKU
         AND AddWho = 'rdt.' + SUSER_SNAME()
      ORDER BY CartonNo DESC -- max cartonno
   END   

   -- Insert PackInfo
   IF @cUCCNo <> ''
   BEGIN
      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, UCCNo, QTY)
         VALUES (@cPickSlipNo, @nCartonNo, @cUCCNo, @nQTY)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET
            UCCNo = @cUCCNo, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO RollBackTran
         END
      END

      -- Mark UCC packed
      IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCNo AND Status < '5')
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
            SET @nErrNo = 226058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
            GOTO RollBackTran
         END
      END
   END

   --set @nBulkSNO = 0

   -- Many serial no
   IF @nBulkSNO = 1
   BEGIN
      DECLARE @nReceiveSerialNoLogKey INT
      
      -- Check SNO QTY
      IF (SELECT ISNULL( SUM( QTY), 0) 
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc) <> @nBulkSNOQTY
      BEGIN
         SET @nErrNo = 226059
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SN QTYNotTally
         GOTO RollBackTran
      END
      
      SET @nQTY_Bal = @nQTY
      
      -- Loop serial no      
      WHILE (1=1)
      BEGIN
         SELECT TOP 1 
            @nReceiveSerialNoLogKey = ReceiveSerialNoLogKey, 
            @cSerialNo = SerialNo, 
            @nSerialQTY = QTY
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc
         
         IF @@ROWCOUNT = 0
            BREAK

         -- Check serial no scanned
         IF NOT EXISTS( SELECT 1
            FROM PackSerialNo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND SerialNo = @cSerialNo)
         BEGIN
            -- Insert PackSerialNo 
            INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
            VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 226060
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackSNOFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 226061
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
            GOTO RollBackTran
         END

         DELETE rdt.rdtReceiveSerialNoLog 
         WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226062
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL TmpSN Fail
            GOTO RollBackTran
         END 

         SET @nQTY_Bal = @nQTY_Bal - @nSerialQTY
      END
         
      -- Check fully offset
      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 226063
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error 
         GOTO RollBackTran
      END 

      -- Check balance
      IF EXISTS( SELECT 1
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc)
      BEGIN
         SET @nErrNo = 226064
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error 
         GOTO RollBackTran
      END
   END

   -- Serial no
   ELSE IF @cSerialNo <> ''
   BEGIN
      -- Get serial no info
      DECLARE @nRowCount INT
      DECLARE @nPackSerialNoKey  INT
      DECLARE @cChkSerialSKU NVARCHAR( 20)
      DECLARE @nChkSerialQTY INT
      
      SELECT 
         @nPackSerialNoKey = PackSerialNoKey, 
         @cChkSerialSKU = SKU, 
         @nChkSerialQTY = QTY
      FROM PackSerialNo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo
      SET @nRowCount = @@ROWCOUNT
      
      -- New serial no
      IF @nRowCount = 0
      BEGIN

      IF NOT EXISTS (SELECT 1 FROM PackSerialNo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo AND LabelLine = @cLabelLine AND StorerKey = @cStorerKey)
      BEGIN
         -- Insert PackSerialNo 
         INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
         VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
      END
      ELSE
      BEGIN
      INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
        VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, 
      (SELECT RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
      FROM dbo.PackSerialNo (NOLOCK)
        WHERE Pickslipno = @cPickSlipNo
        AND CartonNo = @nCartonNo
        AND LabelNo = @cLabelNo)
      , @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
      END       
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226065
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail
            GOTO RollBackTran
         END
      END
      
      -- Check serial no scanned
      ELSE
      BEGIN
         SET @nErrNo = 226066
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
         GOTO RollBackTran
      END
   END
   
   -- Pack data
   IF @cPackData1 <> '' OR
      @cPackData2 <> '' OR
      @cPackData3 <> ''
   BEGIN
      DECLARE @nPackDetailInfoKey BIGINT
      
      -- Get PackDetailInfo
      SET @nPackDetailInfoKey = 0
      SELECT @nPackDetailInfoKey = PackDetailInfoKey
      FROM dbo.PackDetailInfo WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo 
         AND SKU = @cSKU
         AND UserDefine01 = @cPackData1
         AND UserDefine02 = @cPackData2
         AND UserDefine03 = @cPackData3
      
      IF @nPackDetailInfoKey = ''
      BEGIN
         -- Insert PackDetailInfo
         INSERT INTO dbo.PackDetailInfo (
            PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, UserDefine01, UserDefine02, UserDefine03, 
            AddWho, AddDate, EditWho, EditDate)
         VALUES (
            @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cPackData1, @cPackData2, @cPackData3, 
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226067
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDInfoFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Update PackDetailInfo
         UPDATE dbo.PackDetailInfo SET   
            QTY = QTY + @nQTY, 
            EditWho = 'rdt.' + SUSER_SNAME(), 
            EditDate = GETDATE(), 
            ArchiveCop = NULL
         WHERE PackDetailInfoKey = @nPackDetailInfoKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226068
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoFail
            GOTO RollBackTran
         END
      END
   END

   /**************************** Loop PickDetail ********************************/
   -- FCR-778
   IF @cMoveQTYPack = N'1'
   BEGIN
      IF @nQTY > 0
      BEGIN
         -- For calculation
         SET @nQTY_Bal = @nQTY

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
            SET @cSQL = 
               ' SELECT PD.PickDetailKey, PD.Lot, PD.Loc, PD.ID, PD.QTY ' + 
               ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK)' + 
                  ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)' + 
                  ' JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC=PD.LOC)'+
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
                  ' AND PD.DropID = @cDropID ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.QTY > 0' + 
                  ' AND PD.Status = ''5'''  + 
               ' ORDER BY CASE WHEN PD.DropID <> PD.ID THEN 1 ELSE 2 END ASC'

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
            SET @cSQL = 
               ' SELECT PD.PickDetailKey, PD.Lot, PD.Loc, PD.ID, PD.QTY ' + 
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                  ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE PD.OrderKey = @cOrderKey ' + 
                  ' AND PD.DropID = @cDropID ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.QTY > 0' + 
                  ' AND PD.Status = ''5''' + 
               ' ORDER BY CASE WHEN PD.DropID <> PD.ID THEN 1 ELSE 2 END ASC'

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
            SET @cSQL = 
               ' SELECT PD.PickDetailKey, PD.Lot, PD.Loc, PD.ID, PD.QTY ' + 
               ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
                  ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
                  ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE LPD.LoadKey = @cLoadKey ' + 
                  ' AND PD.DropID = @cDropID ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.QTY > 0' + 
                  ' AND PD.Status = ''5''' + 
               ' ORDER BY CASE WHEN PD.DropID <> PD.ID THEN 1 ELSE 2 END ASC'

         -- Custom PickSlip
         ELSE
            SET @cSQL = 
               ' SELECT PD.PickDetailKey, PD.Lot, PD.Loc, PD.ID, PD.QTY ' + 
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                  ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
                  ' AND PD.DropID = @cDropID ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.QTY > 0' + 
                  ' AND PD.Status = ''5''' + 
               ' ORDER BY CASE WHEN PD.DropID <> PD.ID THEN 1 ELSE 2 END ASC'

         -- Open cursor
         SET @cSQL = 
            ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
               @cSQL + 
            ' OPEN @curPD ' 
         
         SET @cSQLParam = 
            ' @curPD       CURSOR OUTPUT, ' + 
            ' @cPickSlipNo NVARCHAR( 10), ' + 
            ' @cOrderKey   NVARCHAR( 10), ' + 
            ' @cLoadKey    NVARCHAR( 10), ' +
            ' @cDropID     NVARCHAR( 20), ' +  
            ' @cSKU        NVARCHAR( 20)'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cFromDropID, @cSKU
               
         -- Loop PickDetail
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLot, @cLoc, @cID, @nQTY_PD
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Exact match
            IF @nQTY_PD = @nQTY_Bal
            BEGIN            
               SET @nQTY_Move = @nQTY_PD
               SET @nQTY_Bal = 0 -- Reduce balance
            END
            -- PickDetail have less
            ELSE IF @nQTY_PD < @nQTY_Bal
            BEGIN            
               SET @nQTY_Move = @nQTY_PD
               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
            END
            -- PickDetail have more
            ELSE IF @nQTY_PD > @nQTY_Bal
            BEGIN
               -- Have balance, need to split
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
                  SET @nErrNo = 226071
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                  GOTO RollBackTran
               END
      
               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PickDetail (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  PickDetailKey,
                  Status, 
                  QTY,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  @cNewPickDetailKey,
                  Status, 
                  @nQTY_PD - @nQTY_Bal, -- remain QTY
                  NULL,
                  '1' 
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 226072
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
                     SET @nErrNo = 226073
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                     GOTO RollBackTran
                  END
               END
      
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 226074
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            
               SET @nQTY_Move = @nQTY_Bal
               SET @nQTY_Bal = 0 -- Reduce balance
            END

            -- Move PickDetail
            IF @nQTY_Move > 0
            BEGIN
               -- Get SKU info
               SELECT 
                  @cPackKey = SKU.PackKey, 
                  @cPackUOM3 = Pack.PackUOM3
               FROM SKU WITH (NOLOCK)
                  JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
               
               -- Get new MoveRefKey
               EXECUTE dbo.nspg_GetKey
                  'MOVEREFKEY',
                  10 ,
                  @cMoveRefKey OUTPUT,
                  @bSuccess    OUTPUT,
                  @nErrNo      OUTPUT,
                  @cErrMsg     OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 226075
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END

               -- Move LOTxLOCxID
               EXEC dbo.nspItrnAddMove
                  @n_ItrnSysId     = NULL
                  , @c_StorerKey     = @cStorerKey
                  , @c_Sku           = @cSKU
                  , @c_Lot           = @cLOT
                  , @c_FromLoc       = @cLOC
                  , @c_FromID        = @cID
                  , @c_ToLoc         = @cLOC
                  , @c_ToID          = @cDropID
                  , @c_Status        = ''
                  , @c_lottable01    = ''
                  , @c_lottable02    = ''
                  , @c_lottable03    = ''
                  , @d_lottable04    = ''
                  , @d_lottable05    = ''
                  , @n_casecnt       = 0
                  , @n_innerpack     = 0
                  , @n_qty           = @nQTY_Move
                  , @n_pallet        = 0
                  , @f_cube          = 0
                  , @f_grosswgt      = 0
                  , @f_netwgt        = 0
                  , @f_otherunit1    = 0
                  , @f_otherunit2    = 0
                  , @c_SourceKey     = ''
                  , @c_SourceType    = @cSourceType
                  , @c_PackKey       = @cPackKey
                  , @c_UOM           = @cPackUOM3
                  , @b_UOMCalc       = 1
                  , @d_EffectiveDate = ''
                  , @c_itrnkey       = ''
                  , @b_Success       = @bSuccess   OUTPUT
                  , @n_err           = @nErrNo     OUTPUT
                  , @c_errmsg        = @cErrMsg    OUTPUT
                  , @c_MoveRefKey    = @cMoveRefKey
         
               SET @nErrNo = @@ERROR
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END
               
               -- Update inventory info
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID, 
                  ID = @cDropID, 
                  MoveRefKey = @cMoveRefKey, 
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 226076
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END

            END

            -- break loop when no balance
            IF @nQTY_Bal = 0
               BREAK

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLot, @cLoc, @cID, @nQTY_PD
         END
         
         CLOSE @curPD  --(yeekung02)
         DEALLOCATE @curPD
      END
   END
   
   /**************************** Loop PickDetail END ********************************/

   -- FCR-778
   IF @cAddPackValidtn = N'1'
   BEGIN

      SELECT TOP 1 @cOrderKey = [OrderKey]
      FROM [dbo].[PickDetail] WITH (NOLOCK)
      WHERE [StorerKey] = @cStorerKey
         AND [DropID] = @cFromDropID

      SELECT TOP 1 @cOrderConsigneeKey = [ConsigneeKey]
         ,@cOrderC_Zip        = [C_Zip]
      FROM [dbo].[ORDERS] WITH (NOLOCK)
      WHERE [Orderkey] = @cOrderKey
         AND [StorerKey] = @cStorerKey

      SELECT TOP 1 @cCustomerPalletType   = [Pallet]
      FROM [dbo].[STORER] WITH (NOLOCK)
      WHERE [Address1] = @cOrderConsigneeKey
         AND [ConsigneeFor] = @cStorerKey
         AND [Zip] = @cOrderC_Zip
         AND [Type] = 2

      SELECT @cCustomerPalletType   = CASE WHEN ISNULL(@cCustomerPalletType, N'') = N'' THEN [Pallet] ELSE @cCustomerPalletType END
      FROM [dbo].[STORER] WITH (NOLOCK)
      WHERE [StorerKey] = @cDefaultConsigneeKey
         AND [ConsigneeFor] = @cStorerKey
         AND [Type] = 2

      SELECT TOP 1
             @nSKUWeight  = [SKU].[STDGROSSWGT] * @nQTY
            ,@nSKUCube    = [PACK].[WidthUOM3] * [PACK].[LengthUOM3] * [PACK].[HeightUOM3] * @nQTY
      FROM  [dbo].[SKU]  WITH (NOLOCK)
         INNER JOIN [dbo].[PACK] WITH (NOLOCK) ON  [SKU].[PACKKey] = [PACK].[PackKey]
      WHERE  [SKU].[Sku]  = @cSKU

      IF NOT EXISTS (SELECT 1 FROM [dbo].[PALLET] (NOLOCK) WHERE [PalletKey] = @cPackDtlDropID)
      BEGIN
         INSERT [dbo].[PALLET] ([PalletKey],[StorerKey],[Status],[EffectiveDate],[AddDate],[AddWho],[EditDate],[EditWho],[TrafficCop],[ArchiveCop],[TimeStamp],[Length],[Width],[Height],[GrossWgt],[PalletType])
         VALUES(@cPackDtlDropID, @cStorerKey,NULL,GETDATE(),GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),NULL,NULL,NULL,0,0,@nSKUCube,@nSKUWeight,@cCustomerPalletType)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226069
            SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') --INS PALLET Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE [dbo].[PALLET] WITH (ROWLOCK)  SET
            [Height]       = [Height]   + @nSKUCube,
            [GrossWgt]     = [GrossWgt] + @nSKUWeight,
            [PalletType]   = @cCustomerPalletType,
            [EditWho]      = SUSER_NAME(),
            [EditDate]     = GETDATE()
         WHERE [PalletKey] = @cPackDtlDropID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 226070
            SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') --UPD PALLET Fail
            GOTO RollBackTran
         END
      END
   END

   --YeeKung      
   EXEC RDT.rdt_STD_EventLog           
   @cActionType         = '3',              
   @nMobileNo           = @nMobile,        
   @nFunctionID         = @nFunc,        
   @cFacility           = @cFacility,        
   @cStorerKey          = @cStorerkey,       
   @nQTY                = @nQTY,          
   @cUCC                = @cUCCNo,    
   @cOrderKey           = @cOrderKey,    
   @cSKU                = @cSKU,  
   @cRefNo1             = @nCartonNo,
   @cPickSlipNo         = @cPickSlipNo,   -- ZG01
   @cLabelNo            = @cLabelNo       -- ZG01

   COMMIT TRAN rdt_PckCnfVLT
   GOTO Quit

RollBackTran:
BEGIN
   ROLLBACK TRAN rdt_PckCnfVLT -- Only rollback change made here
   IF @cNewCarton = 'Y'
   BEGIN
      SET @nCartonNo = 0
      SET @cLabelNo = ''
   END
END

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO