SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_848ExtUpd04                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2022-05-10  1.0  YeeKung     WMS-19631. Created                      */
/* 2022-12-16  1.1  YeeKung     WMS-21260 Add palletid/taskdetail       */
/*                              (yeekung02)                             */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_848ExtUpd04] (  
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),
   @cID          NVARCHAR( 18), 
   @cTaskdetailKey NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTranCount INT 
   DECLARE @cFacility NVARCHAR(20)
   DECLARE @cUsername NVARCHAR(20)
   DECLARE @nCartonNo NVARCHAR(20)
   DECLARE @cLabelLine NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_848ExtUpd04 -- For rollback or commit only our own transaction  
  
   IF @nFunc = 848  
   BEGIN  
      IF @nStep = 4  
      BEGIN  
         SELECT @cFacility=facility,
               @cUsername=username
         FROM RDT.RDTMOBREC (NOLOCK)
         WHERE Mobile=@nMobile
         
         -- Get Orders info  
         SELECT TOP 1 @cPickSlipNo = PickSlipNo   
         FROM dbo.PackDetail WITH (NOLOCK)   
         WHERE labelno = @cDropID  
         AND   StorerKey = @cStorerKey  
  
         IF ISNULL( @cPickSlipNo, '') = ''  
         BEGIN  
            SET @nErrNo = 186651   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip  
            GOTO RollBackTran  
         END  
  
         DECLARE CUR_DELPACKD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
         SELECT CartonNo, LabelLine  
         FROM dbo.PackDetailInfo WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
         AND   LabelNo = @cDropID  
         AND   (( @cSKU = '') OR ( SKU = @cSKU))  
         OPEN CUR_DELPACKD  
         FETCH NEXT FROM CUR_DELPACKD INTO @nCartonNo, @cLabelLine  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            DELETE FROM dbo.PackDetailInfo   
            WHERE PickSlipNo = @cPickSlipNo  
            AND   CartonNo = @nCartonNo  
            AND   LabelNo = @cDropID  
            AND   LabelLine = @cLabelLine  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 186652  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PackD Fail  
               CLOSE CUR_DELPACKD  
               DEALLOCATE CUR_DELPACKD  
               GOTO RollBackTran                    
            END  
  
            FETCH NEXT FROM CUR_DELPACKD INTO @nCartonNo, @cLabelLine  
         END  
         CLOSE CUR_DELPACKD  
         DEALLOCATE CUR_DELPACKD
         
          EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3', -- insert Function
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @nStep         = @nStep,
           @cCartonID     = @cDropID,
           @cDropID       = @cDropID
      END  
  
   END  
  
   GOTO Quit  

ROLLBACKTRAN:
   ROLLBACK TRAN
QUIT:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    

END  

GO