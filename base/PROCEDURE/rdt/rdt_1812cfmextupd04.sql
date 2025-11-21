SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812CfmExtUpd04                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Add PackDetail (1 carton 1 Drop ID)                         */
/*                                                                      */
/* Modifications log:                                                   */
/* Date         Author    Ver.  Purposes                                */
/* 2024-08-28   Ung       1.0   WMS-26122 base rdt_1812CfmExtUpd03      */
/* 2024-09-19   James     1.1   Add PackInfo misc update (james01)      */
/* 2024-11-11   PXL009    1.2   FCR-1125 Merged 1.0, 1.1 from v0 branch */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1812CfmExtUpd04
    @nMobile            INT
   ,@nFunc              INT
   ,@cLangCode          NVARCHAR( 3)
   ,@cTaskdetailKey     NVARCHAR( 10)
   ,@cNewTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo             INT           OUTPUT
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT

   DECLARE @cStorerKey     NVARCHAR(15)
   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @cUCCSKU        NVARCHAR(20)
   DECLARE @nQTY           INT
   DECLARE @nUCCQTY        INT
   DECLARE @nUCC_RowRef    INT
   DECLARE @cUCCNo         NVARCHAR(20) = ''
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @cFromLOC       NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cPickSlipNo    NVARCHAR(10) = ''
   DECLARE @cUserDefined01    NVARCHAR( 15)
   DECLARE @cUserDefined02    NVARCHAR( 15)
   DECLARE @cUserDefined03    NVARCHAR( 20)
   DECLARE @cUserDefined04    NVARCHAR( 30)
   DECLARE @curPackDtl        CURSOR
   DECLARE @curUpdUCC         CURSOR


   -- Get task info
   SELECT
      @cStorerKey = StorerKey,
      @cSKU = SKU,
      @nQTY = QTY,
      @cDropID = DropID,
      @cFromLOC = FromLOC
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey

   -- Get UCC (1 task 1 UCC)
   SELECT @cUCCNo = UCCNo
   FROM rdt.rdtFCPLog WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Get order info (1 pallet 1 order)
   SELECT TOP 1 @cOrderKey = OrderKey
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Get PackHeader
   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1812CfmExtUpd04

   /***********************************************************************************************
                                               PackHeader
   ***********************************************************************************************/
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
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

      DECLARE @cLoadKey NVARCHAR( 10) = ''
      SELECT @cLoadKey = LoadKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, ConsigneeKey, LoadKey)
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, '', @cLoadKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************
                                                PackDetail
   ***********************************************************************************************/
   DECLARE @nCartonNo   INT = 0
   DECLARE @cLabelLine  NVARCHAR(5) = ''
   DECLARE @cNewLine    NVARCHAR(1)

   SET @curPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT SKU, ISNULL( SUM( Qty), 0)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   UCCNo = @cUCCNo
   GROUP BY SKU
   OPEN @curPackDtl
   FETCH NEXT FROM @curPackDtl INTO @cUCCSKU, @nUCCQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get LabelLine
      SELECT
         @nCartonNo = CartonNo,
         @cLabelLine = LabelLine
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND LabelNo = @cDropID
         AND SKU = @cUCCSKU

      IF @cLabelLine = ''
      BEGIN
         SET @cNewLine = 'Y'

         SELECT @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cDropID

         IF @nCartonNo = 0
            SET @cLabelLine = '00000'
         ELSE
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND LabelNo = @cDropID
      END

      IF @cNewLine = 'Y'
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID,
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cUCCNo, @cLabelLine, @cStorerKey, @cUCCSKU, @nUCCQTY, @cDropID,
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221752
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
            AND LabelNo = @cDropID
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 221753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM @curPackDtl INTO @cUCCSKU, @nUCCQty
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

   /***********************************************************************************************
                                                PackInfo
   ***********************************************************************************************/
   IF EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
   BEGIN
      UPDATE dbo.PackInfo SET
         QTY        = QTY + @nQTY,
         EditDate   = GETDATE(),
         EditWho    = SUSER_SNAME()
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      SELECT TOP 1
         @cUserDefined01 = UserDefined01,
         @cUserDefined02 = UserDefined02,
         @cUserDefined03 = UserDefined03,
         @cUserDefined04 = UserDefined04
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCCNo
      ORDER BY 1

      INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY,
                               [Length],
                               Width,
                               Height,
                               [Weight],
                               CartonType)
      VALUES (@cPickSlipNo, @nCartonNo, @nQTY,
                              CAST(@cUserDefined01 AS FLOAT),
                              CAST(@cUserDefined02 AS FLOAT),
                              CAST(@cUserDefined03 AS FLOAT),
                              CAST(@cUserDefined04 AS FLOAT),
                              'CTN')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************
                                            UCC confirm
   ***********************************************************************************************/
   SET @curUpdUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT UCC_RowRef
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   UCCNo = @cUCCNo
   AND   [Status] = '3'
   OPEN @curUpdUCC
   FETCH NEXT FROM @curUpdUCC INTO @nUCC_RowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.UCC SET
         [Status] = '5',
         EditWho = 'rdt.' + SUSER_SNAME(),
         EditDate = GETDATE()
      WHERE UCC_RowRef = @nUCC_RowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC FAIL
         GOTO RollBackTran
      END

      FETCH NEXT FROM @curUpdUCC INTO @nUCC_RowRef
   END

   /***********************************************************************************************
                                            Pack confirm
   ***********************************************************************************************/
   /*
   DECLARE @cFacility NVARCHAR( 5)
   DECLARE @nStep INT
   DECLARE @nInputKey INT

   -- Get session info
   SELECT
      @cFacility = Facility,
      @nStep = Step,
      @nInputKey = InputKey
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- PickHeader (needed by the rdt_Pack_PackConfirm in below)
   IF NOT EXISTS( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
   BEGIN
      INSERT INTO dbo.PickHeader (PickHeaderKey, OrderKey)
      VALUES (@cPickSlipNo, @cOrderKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 221756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPKHdrFail
         GOTO RollBackTran
      END
   END

   -- Pack confirm
   EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cPickSlipNo
      ,'' -- @cFromDropID
      ,'' -- @cPackDtlDropID
      ,'' -- @cPrintPackList
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran
   */


   /***********************************************************************************************
                                          Interface
   ***********************************************************************************************/
   EXEC isp_Carrier_Middleware_Interface
       @cOrderKey
      ,'' -- @cMBOLKey
      ,@nFunc
      ,@nCartonNo
      ,5  -- @nStep
      ,@bSuccess  OUTPUT
      ,@nErrNo    OUTPUT
      ,@cErrMsg   OUTPUT
   IF @bSuccess = 0
   BEGIN
      SET @nErrNo = 221757
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipLabel fail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_1812CfmExtUpd04 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1812CfmExtUpd04 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO