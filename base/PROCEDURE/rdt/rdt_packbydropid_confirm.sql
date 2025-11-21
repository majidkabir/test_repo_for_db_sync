SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PackByDropID_Confirm                            */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 04-03-2019 1.0  Ung         WMS-8034 Created                         */
/* 29-06-2021 1.1  Chermaine   WMS-17288 Add ConfirmSP config (cc01)    */
/* 22-06-2022 1.2  Ung         WMS-19989 Add force use standard logic   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PackByDropID_Confirm] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nCartonNo       INT           OUTPUT
   ,@cLabelNo        NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@nUseStandard    INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @nRowCount      INT
   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cLabelLine     NVARCHAR(5)
   DECLARE @cNewLine       NVARCHAR(1)
   DECLARE @cGenLabelNo_SP NVARCHAR(20)
   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @nQTY           INT
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cUOM           NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cConfirmSP     NVARCHAR( 20)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get storer configure  --(cc01)
   IF @nUseStandard = 0
   BEGIN
      SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
      IF @cConfirmSP = '0'
         SET @cConfirmSP = ''
   END
   
   /***********************************************************************************************
                                                Custom confirm
   ***********************************************************************************************/
   -- Custom confirm logic
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo , @cDropID, ' +
            ' @nCartonNo OUTPUT, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile        INT,            ' +
            '@nFunc          INT,            ' +
            '@cLangCode      NVARCHAR( 3),   ' +
            '@nStep          INT,            ' +
            '@nInputKey      INT,            ' +
            '@cFacility      NVARCHAR( 5),   ' +
            '@cStorerKey     NVARCHAR( 15),  ' +
            '@cPickSlipNo    NVARCHAR( 10),  ' +
            '@cDropID        NVARCHAR( 20),  ' +
            '@nCartonNo      INT   OUTPUT,   ' +
            '@cLabelNo       NVARCHAR( 20) OUTPUT,  ' +
            '@nErrNo         INT   OUTPUT,   ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo , @cDropID,
            @nCartonNo OUTPUT, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END
   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/

   SET @nTranCount = @@TRANCOUNT

   -- Get PickDetail info
   SELECT
      @cUOM = UOM,
      @cStatus = Status
   FROM PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND DropID = @cDropID
      AND Status <> '4'
      AND Status < '5'
   ORDER BY Status DESC

   SET @nRowCount = @@ROWCOUNT

   -- Check DropID valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 135351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
      GOTO Quit
   END

   -- Check not yet pick
   IF @cUOM IN ('6', '7') AND -- Loose carton
      @cStatus = '0'          -- Not yet pick
   BEGIN
      SET @nErrNo = 135352
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick not done
      GOTO Quit
   END

   -- Check DropID packed
   IF EXISTS( SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo AND DropID = @cDropID)
   BEGIN
      SET @nErrNo = 135353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID packed
      GOTO Quit
   END

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.DropID = @cDropID
            AND PD.Status < '5'
            AND PD.Status <> '4')
      BEGIN
         SET @nErrNo = 135354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
         GOTO Quit
      END
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.DropID = @cDropID
            AND PD.Status < '5'
            AND PD.Status <> '4')
      BEGIN
         SET @nErrNo = 135355
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
         GOTO Quit
      END
   END

   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.DropID = @cDropID
            AND PD.Status < '5'
            AND PD.Status <> '4')
      BEGIN
         SET @nErrNo = 135356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
         GOTO Quit
      END
   END

   -- Custom PickSlip
   ELSE
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.DropID = @cDropID
            AND PD.Status < '5'
            AND PD.Status <> '4')
      BEGIN
         SET @nErrNo = 135357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
         GOTO Quit
      END
   END

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PackByDropID_Confirm -- For rollback or commit only our own transaction

   -- PackHeader
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)
   BEGIN
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
         GOTO RollBackTran
      END
   END

   -- Loop PickDetail
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, SKU, QTY
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cDropID
         AND Status <> '4'
         AND Status < '5'
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cNewLine = 'N'

      -- New carton, generate labelNo
      IF @nCartonNo = 0 --
      BEGIN
         SET @cLabelNo = ''

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
               SET @nErrNo = 135360
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO RollBackTran
            END
         END

         IF @cLabelNo = ''
         BEGIN
            SET @nErrNo = 135361
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

      -- PackDetail
      IF @cNewLine = 'Y'
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 135362
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
            SET @nErrNo = 135363
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
            @cLabelNo = LabelNo
         FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND AddWho = 'rdt.' + SUSER_SNAME()
         ORDER BY CartonNo DESC -- max cartonno
      END

      -- Confirm PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = '5',
         CaseID = @cDropID,
         DropID = @cLabelNo,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135359
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END

      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
   END

   COMMIT TRAN rdt_PackByDropID_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PackByDropID_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO