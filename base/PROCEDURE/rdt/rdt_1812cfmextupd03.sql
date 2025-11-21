SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812CfmExtUpd03                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Add PackDetail (1 carton 1 Drop ID)                         */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-06-26   Ung       1.0   WMS-22681 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1812CfmExtUpd03]
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
   DECLARE @nQTY           INT
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @cFromLOC       NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cPickSlipNo    NVARCHAR(10) = ''

   -- Get task info
   SELECT
      @cStorerKey = StorerKey, 
      @cSKU = SKU,
      @nQTY = QTY, 
      @cDropID = DropID, 
      @cFromLOC = FromLOC,   
      @cOrderKey = OrderKey
   FROM TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskdetailKey
   
   -- Get PackHeader
   SELECT @cPickSlipNo = PickSlipNo 
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey 
   
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1812CfmExtUpd03

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
         SET @nErrNo = 203201
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

   -- Get LabelLine
   SELECT 
      @nCartonNo = CartonNo, 
      @cLabelLine = LabelLine
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo 
      AND LabelNo = @cDropID
      AND SKU = @cSKU
      
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
         (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID, 
         'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 203202
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
         SET @nErrNo = 203203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
         GOTO RollBackTran
      END
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
         SET @nErrNo = 203204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY)
      VALUES (@cPickSlipNo, @nCartonNo, @nQTY)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 203205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
         GOTO RollBackTran
      END
   END
   
   /***********************************************************************************************
                                            Pack confirm
   ***********************************************************************************************/
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
         SET @nErrNo = 203206
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


   /***********************************************************************************************
                                          Off light for the task
   ***********************************************************************************************/
   IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND LocationType = 'PTL')
   BEGIN  
      -- Get light of the task  
      DECLARE @cStation  NVARCHAR( 20)  
      DECLARE @cPosition NVARCHAR( 10)                    
      SELECT TOP 1   
          @cStation = DeviceID,   
          @cPosition = DevicePosition  
      FROM DeviceProfile WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
         AND LOC = @cFromLOC   
         AND LogicalName = 'FCP'  
  
      -- Turn off light of task  
      IF @@ROWCOUNT > 0  
      BEGIN  
         EXEC PTL.isp_PTL_TerminateModuleSingle  
            @cStorerKey  
           ,@nFunc  
           ,@cStation  
           ,@cPosition  
           ,@bSuccess   OUTPUT  
           ,@nErrNo     OUTPUT  
           ,@cErrMsg    OUTPUT  
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END  
   END
   
   COMMIT TRAN rdt_1812CfmExtUpd03 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1812CfmExtUpd03 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO