SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_832Confirm01_DropID                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_CartonPack                                       */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-05-29   1.0  James    WMS9146 Created (rdt_834ExtPack02)        */
/* 2020-07-16   1.1  Ung      WMS-13699 Migrate to this SP              */
/* 2023-01-13   1.2  Ung      WMS-21489 Move Eventlog to sub SP         */
/************************************************************************/

CREATE PROC [RDT].[rdt_832Confirm01_DropID] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cType            NVARCHAR( 10),
   @tConfirm         VariableTable READONLY,
   @cDoc1Value       NVARCHAR( 20),
   @cCartonID        NVARCHAR( 20),
   @cCartonSKU       NVARCHAR( 20),
   @nCartonQTY       INT,
   @cPackInfo        NVARCHAR( 4),
   @cCartonType      NVARCHAR( 10),
   @fCube            FLOAT,
   @fWeight          FLOAT,
   @cPackInfoRefNo   NVARCHAR( 20),
   @cPickSlipNo      NVARCHAR( 10) OUTPUT,
   @nCartonNo        INT           OUTPUT,
   @cLabelNo         NVARCHAR( 20) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
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
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nQTY_PD        INT
   DECLARE @nPicked        INT
   DECLARE @nPacked        INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPackConfirm   NVARCHAR(1)
   DECLARE @cStatus        NVARCHAR(1)

   DECLARE @cGenLabelNo_SP     NVARCHAR( 20)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cUpdatePickDetail  NVARCHAR( 1)

   SET @nErrNo = 0

   -- Migrate rdt_834ExtValid02 to here
   BEGIN
      -- Get carton info
      SELECT @nCartonQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cCartonID

      -- Check carton valid
      IF @nCartonQTY = 0
      BEGIN
         SET @nErrNo = 159701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
         GOTO Quit
      END

      -- Get carton info
      SELECT TOP 1 
         @cStatus = Status,
         @cOrderKey = OrderKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cCartonID
      
      SELECT @cLoadkey = LoadKey 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

      -- Check carton shipped
      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 159702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton shipped
         GOTO Quit
      END

      -- Check carton scanned
      IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE UCCNo = @cCartonID)
      BEGIN
         SET @nErrNo = 159703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton scanned
         GOTO Quit
      END

      -- Get PickSlip
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      IF @cPickSlipNo = ''
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey

      -- Check pickslip valid
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 159704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNo NotFound
         GOTO Quit
      END

      -- Get PickSlip info
      SELECT
         @cZone = Zone,
         @cLoadKey = ExternOrderKey,
         @cOrderKey = OrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo
   END

   IF @cType = 'CHECK'
      GOTO Quit

   -- Storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_832Confirm01_DropID

   /***********************************************************************************************  
                                              PackHeader  
   ***********************************************************************************************/  
   -- PackHeader
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 159705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************  
                                        PackDetail, PickDetail 
   ***********************************************************************************************/  
   -- Loop PickDetail
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, SKU, QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cCartonID
         AND Status <> '4'
         AND Status < @cPickConfirmStatus
      ORDER BY 1
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get carton info
      SET @nCartonNo = 0
      SET @cLabelNo = ''
      SELECT TOP 1
         @nCartonNo = CartonNo,
         @cLabelNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE Pickslipno = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND DropID = @cCartonID

      -- New carton
      IF @nCartonNo = 0
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
            EXECUTE dbo.nsp_GenLabelNo
               @c_orderkey    = '',
               @c_storerkey   = @cStorerKey,
               @c_labelno     = @cLabelNo    OUTPUT,
               @n_cartonno    = @nCartonNo   OUTPUT,
               @c_button      = '',
               @b_success     = @bSuccess    OUTPUT,
               @n_err         = @nErrNo      OUTPUT,
               @c_errmsg      = @cErrMsg     OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 159706
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelFail
               GOTO Quit
            END
         END

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nQTY_PD,
            @cCartonID, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 159707
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
            GOTO RollBackTran
         END

         -- Get assigned carton no
         SELECT TOP 1
            @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cLabelNo
      END

      -- Existing carton
      ELSE
      BEGIN
         -- Get LabelLine
         SET @cLabelLine = ''
         SELECT @cLabelLine = LabelLine
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE Pickslipno = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND SKU = @cSKU

         -- New SKU in carton
         IF @cLabelLine = ''
         BEGIN
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQTY_PD,
               @cCartonID, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 159708
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PackDetail SET
               QTY = QTY + @nQTY_PD,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 159709
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END
         END
      END

      IF @cUpdatePickDetail = '1'
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = @cPickConfirmStatus,
            DropID = @cLabelNo,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 159710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
   END


   /***********************************************************************************************  
                                              PackInfo
   ***********************************************************************************************/  
   -- PackInfo
   IF EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
   BEGIN
      UPDATE dbo.PackInfo SET
         UCCNo = @cCartonID,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(),
         TrafficCop = NULL
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 159711
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************
                                              Pack confirm
   ***********************************************************************************************/
   -- Pack confirm
   IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')
   BEGIN
      SET @nPicked = 0
      SET @nPacked = 0
      SET @cPackConfirm = ''

      -- Calc pack QTY
      SELECT @nPacked = ISNULL( SUM( QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      -- Cross dock PickSlip
      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
                    FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                    WHERE RKL.PickSlipNo = @cPickSlipNo
                    AND   PD.Status < '5'
                    AND    PD.QTY > 0
                    AND   (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'

         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPicked = SUM( QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo

            IF @nPicked <> @nPacked
               SET @cPackConfirm = 'N'
         END
      END

      -- Discrete PickSlip
      ELSE IF ISNULL(@cOrderKey, '') <> ''
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
                    FROM dbo.PickDetail PD WITH (NOLOCK)
                    WHERE PD.OrderKey = @cOrderKey
                    AND   PD.Status < '5'
                    AND   PD.QTY > 0
                    AND  (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'

         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPicked = SUM( PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey

            IF @nPicked <> @nPacked
               SET @cPackConfirm = 'N'
         END
      END

      -- Conso picklist
      ELSE
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
                    FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                    WHERE LPD.LoadKey = @cLoadKey
                    AND   PD.Status < '5'
                    AND   PD.QTY > 0
                    AND  (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'

         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nPicked = SUM( PD.QTY)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey

            IF @nPicked <> @nPacked
               SET @cPackConfirm = 'N'
         END
      END

      -- Pack confirm
      IF @cPackConfirm = 'Y'
      BEGIN
         UPDATE dbo.PackHeader SET
            [Status] = '9',
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 159712
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
            GOTO RollBackTran
         END
      END
   END

   -- Event log
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '3',
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @cCartonID   = @cCartonID

   COMMIT TRAN rdt_832Confirm01_DropID
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_832Confirm01_DropID
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_832Confirm01_DropID
END

GO