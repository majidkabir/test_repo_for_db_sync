SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593CartonLBL01_Confirm                                */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-04-13 1.0  Ung        WMS-1612 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593CartonLBL01_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cOrderKey     NVARCHAR( 10), 
   @cDropID       NVARCHAR( 20),
   @cPickSlipNo   NVARCHAR( 10) OUTPUT, 
   @nCartonNo     INT           OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cLabelNo       NVARCHAR(20)
   DECLARE @cLabelLine     NVARCHAR(5)
   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @nQTY           INT
   DECLARE @cPackStatus    NVARCHAR(1)
   DECLARE @cNewLine       NVARCHAR(1)
   DECLARE @cAutoPackConfirm NVARCHAR(1)
   DECLARE @cPickStatus    NVARCHAR(1)
   DECLARE @nPickQTY       INT
   DECLARE @nPackQTY       INT

   SET @cPickSlipNo = ''
   SET @nCartonNo = 0
   SET @cPickStatus = '5'
   SET @cPackStatus = ''
   
   -- Get PickHeader info
   SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_593CartonLBL01_Confirm
   
   -- Create PickHeader
   IF @cPickSlipNo = ''
   BEGIN
      -- Get new pickslip
      EXECUTE dbo.nspg_GetKey
         'PICKSLIP',
         9 ,
         @cPickSlipNo OUTPUT,
         @bSuccess    OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 107951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKey Fail
         GOTO RollBackTran
      END

      SET @cPickSlipNo = 'P' + @cPickSlipNo  
      
      INSERT INTO dbo.PickHeader (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)  
      VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE())  
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 107952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPickHdrFail
         GOTO RollBackTran
      END
   END

   -- Create PickingInfo
   IF NOT EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, AddWho) 
      VALUES ( @cPickSlipNo, GETDATE(), SUSER_SNAME()) 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 107953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKInf Fail
         GOTO RollBackTran
      END
   END      

   -- Get PackHeader info
   SELECT @cPackStatus = Status FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      
   -- Create PackHeader
   IF @@ROWCOUNT = 0
   BEGIN
      INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)
      SELECT 
         O.Route, O.OrderKey,'', O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE()
      FROM dbo.Orders O WITH (NOLOCK)
      WHERE O.Orderkey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 107954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
         GOTO RollBackTran
      END
   END      

   -- Get PackDetail info
   SET @nCartonNo = 0
   SET @cLabelNo = ''
   SELECT TOP 1 
      @nCartonNo = CartonNo, 
      @cLabelNo = LabelNo
   FROM PackDetail WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo 
      AND RefNo = @cDropID

   -- Create PackDetail
   IF @nCartonNo = 0
   BEGIN
      -- Generate LabelNo
      IF @cLabelNo = ''
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
               SET @nErrNo = 107955
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO RollBackTran
            END
         END
      END
      
      -- Loop PickDetail
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR SCROLL FOR
         SELECT PickDetailKey, SKU, QTY
         FROM dbo.Pickdetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND DropID = @cDropID
            AND Status <> '4'
         ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cNewLine = 'N'
         
         -- New carton
         IF @nCartonNo = 0
         BEGIN
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
         
         IF @cNewLine = 'Y'
         BEGIN
            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cLabelNo, @cDropID, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 107956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
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
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 107957
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
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
               AND SKU = @cSKU
               AND AddWho = 'rdt.' + SUSER_SNAME()
            ORDER BY CartonNo DESC -- max cartonno
         END   
      
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
      END

      -- Update PickDetail
      FETCH FIRST FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail SET 
            CaseID = @cLabelNo, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 107958
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPickDtlFail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
      END

      DECLARE @cUserName NVARCHAR(15)
      SET @cUserName = LEFT( SUSER_SNAME(), 15)
   
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
           @cActionType = '8', -- Packing
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cPickSlipNo = @cPickSlipNo, 
           @cDropID     = @cDropID
   END
   
   -- Pack confirm
   IF @cPackStatus <> '9'
   BEGIN
      -- Storer config
      SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   
      -- Auto pack confirm
      IF @cAutoPackConfirm = '1'
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick
            SET @cPackStatus = 'N'
         ELSE
            SET @cPackStatus = 'Y'
         
         -- Check fully packed
         IF @cPackStatus = 'Y'
         BEGIN
            SELECT @nPickQTY = SUM( PD.QTY) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cOrderKey
            
            IF @nPickQTY <> @nPackQTY
               SET @cPackStatus = 'N'
         END
         
         -- Pack confirm
         IF @cPackStatus = 'Y'
         BEGIN
            -- Pack confirm
            UPDATE PackHeader SET 
               Status = '9' 
            WHERE PickSlipNo = @cPickSlipNo
               AND Status <> '9'
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 107959
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
               GOTO RollBackTran
            END
         END
      END
   END
   
   COMMIT TRAN rdt_593CartonLBL01_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_593CartonLBL01_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO