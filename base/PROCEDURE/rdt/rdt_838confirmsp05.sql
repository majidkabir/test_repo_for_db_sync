SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ConfirmSP05                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 12-04-2019  1.0  Ung         WMS-8134 Created. Based on rdt_838ConfirmSP04 */
/* 23-05-2019  1.1  Ung         WMS-9191 Update PickDetail                    */
/* 03-07-2019  1.2  Ung         WMS-9191 Fix cannot get track no              */
/* 13-08-2019  1.3  James       WMS-10030 Update dropid to pickdetail and     */
/*                              packdetail (james01)                          */
/* 16-04-2021  1.4  James       WMS-16024 Standard use of TrackingNo (james02)*/
/******************************************************************************/

CREATE PROC [RDT].[rdt_838ConfirmSP05] (
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
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess       INT,
           @cSQL           NVARCHAR(MAX),
           @cSQLParam      NVARCHAR(MAX),
           @cLabelLine     NVARCHAR( 5),
           @cNewLine       NVARCHAR( 1),
           @cGenLabelNo_SP NVARCHAR( 20),
           @cOrders_UDF04  NVARCHAR( 20),
           @cCarrierName   NVARCHAR( 15),
           @cKeyName       NVARCHAR( 30),
           @cTrackingNo    NVARCHAR( 20),
           @cPickDetailKey NVARCHAR( 10),
           @cLoadKey       NVARCHAR( 10),
           @cOrderKey      NVARCHAR( 10),
           @cDocType       NVARCHAR( 1),
           @nPackQty       INT,
           @nQTY_PD        INT,
           @nFirst_Ctn     INT,
           @b_success      INT
   DECLARE @nQTY_Bal INT


   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_838ConfirmSP05 -- For rollback or commit only our own transaction

   SET @cOrderKey = ''
   SET @cLoadKey = ''

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo
         
   -- PackHeader
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)
   BEGIN
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 137701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
         GOTO RollBackTran
      END
   END
   
   -- Get order info
   SELECT 
      @cDocType = DocType, 
      --@cOrders_UDF04 = UserDefine04,
      @cOrders_UDF04 = TrackingNo,  -- (james02)
      @cCarrierName = ShipperKey
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   -- ECOMM order
   IF @cDocType = 'E' 
   BEGIN
      -- Check 1st carton tracking no exist
      IF ISNULL( @cOrders_UDF04, '') = ''
      BEGIN
         SET @nErrNo = 137702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No UDF04
         GOTO RollBackTran
      END
   END
   
   SET @cNewLine = 'N'
   
   -- New carton, generate labelNo
   IF @nCartonNo = 0 -- 
   BEGIN
      IF @cUCCNo <> ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'DefaultUCCtoLabelNo', @cStorerkey) = '1'
            SET @cLabelNo = @cUCCNo
      END
      
      IF @cLabelNo = ''
      BEGIN
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
                  SET @nErrNo = 137704
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
                  GOTO RollBackTran
               END
            END
         END
      END

      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 137705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
         GOTO RollBackTran
      END

      SET @cLabelLine = ''   
      SET @cNewLine = 'Y'
   END
   ELSE
   BEGIN
      -- Get existing label no
      SELECT TOP 1 
         @cLabelNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      
      -- Get LabelLine
      SET @cLabelLine = ''
      SELECT @cLabelLine = LabelLine
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo 
         AND SKU = @cSKU
         AND RefNo = @cPackDtlRefNo
      
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
   
   IF @cNewLine = 'Y'
   BEGIN
      -- Insert PackDetail
      INSERT INTO dbo.PackDetail
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo, DropID,
         AddWho, AddDate, EditWho, EditDate)
      VALUES
         (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cPackDtlRefNo, @cPackDtlDropID,
         'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 137706
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
         SET @nErrNo = 137707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
         GOTO RollBackTran
      END
   END

   -- Get system assigned CartonoNo and LabelNo
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
            SET @nErrNo = 137708
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
            SET @nErrNo = 137709
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
            SET @nErrNo = 137710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
            GOTO RollBackTran
         END
      END
   END

   -- Bulk serial no
   IF @nBulkSNO = 1
   BEGIN
      DECLARE @nReceiveSerialNoLogKey INT
      
      -- Check SNO QTY
      IF (SELECT ISNULL( SUM( QTY), 0) 
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc) <> @nBulkSNOQTY
      BEGIN
         SET @nErrNo = 137711
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
               SET @nErrNo = 137712
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackSNOFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 137713
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
            GOTO RollBackTran
         END

         DELETE rdt.rdtReceiveSerialNoLog 
         WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137714
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL TmpSN Fail
            GOTO RollBackTran
         END 

         SET @nQTY_Bal = @nQTY_Bal - @nSerialQTY
      END
         
      -- Check fully offset
      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 137715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error 
         GOTO RollBackTran
      END 

      -- Check balance
      IF EXISTS( SELECT 1
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc)
      BEGIN
         SET @nErrNo = 137716
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
         -- Insert PackSerialNo 
         INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
         VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137717
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail
            GOTO RollBackTran
         END
      END
      
      -- Check serial no scanned
      ELSE
      BEGIN
         SET @nErrNo = 137718
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
            SET @nErrNo = 137719
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
            SET @nErrNo = 137720
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoFail
            GOTO RollBackTran
         END
      END
   END   

   SET @nQTY_Bal = @nQTY

   -- PickDetail
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
      SELECT PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.Status = '0'
         AND PD.Status <> '4'
         --AND (PD.UOM = '7' OR
         --    (PD.UOM = '2' AND PD.QTY < Pack.CaseCNT))
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
            DropID = @cPackDtlDropID,
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME() 
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137721
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
            DropID = @cPackDtlDropID,
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME() 
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137722
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END

         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
      END
      
      -- PickDetail have more
		ELSE IF @nQTY_PD > @nQTY_Bal
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
            SET @nErrNo = 137723
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
				SET @nErrNo = 137724
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
               SET @nErrNo = 137725
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
            SET @nErrNo = 137726
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END

         -- Confirm orginal PickDetail with exact QTY
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Status = '5',
            DropID = @cPackDtlDropID,
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME() 
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137727
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         
         SET @nQTY_Bal = 0 -- Reduce balance
      END

      -- Exit condition
      IF @nQTY_Bal = 0
         BREAK

      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
   END
   
   -- Check offset
   IF @nQTY_Bal <> 0
   BEGIN
      SET @nErrNo = 137703
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset error
      GOTO RollBackTran
   END
   
   COMMIT TRAN rdt_838ConfirmSP05
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838ConfirmSP05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO