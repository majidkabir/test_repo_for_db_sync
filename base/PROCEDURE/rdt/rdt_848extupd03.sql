SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_848ExtUpd03                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-12-02  1.0  James       WMS-18457. Created                      */  
/* 2022-04-04  1.1  yeekung     WMS-19378 Add eventlog (yeekung01)      */
/* 2022-12-16  1.2 YeeKung      WMS-21260 Add palletid/taskdetail       */
/*                            (yeekung02)                               */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_848ExtUpd03] (  
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
  
   DECLARE @nTranCount       INT,  
           @cLabelLine        NVARCHAR( 5),  
           @nCartonNo         INT,
           @cUsername         NVARCHAR(20),
           @cFacility         NVARCHAR(20)
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_848ExtUpd03 -- For rollback or commit only our own transaction  
  
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
         WHERE DropID = @cDropID  
         AND   StorerKey = @cStorerKey  
  
         IF ISNULL( @cPickSlipNo, '') = ''  
         BEGIN  
            SET @nErrNo = 179651  
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
               SET @nErrNo = 179652  
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
  
   RollBackTran:  
      ROLLBACK TRAN rdt_848ExtUpd03  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END  

GO