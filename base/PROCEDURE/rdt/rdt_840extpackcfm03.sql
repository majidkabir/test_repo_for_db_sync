SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_840ExtPackCfm03                                 */    
/* Purpose: Pack cfm, stamp pickdetail.caseid/labelno and               */    
/*          middleware interface                                        */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author     Purposes                                 */    
/* 2023-04-12  1.0  James      WMS-22180. Created                       */    
/* 2023-05-18  1.1  James      Remove stamp pickdetail.caseid (james01) */    
/************************************************************************/    
    
CREATE    PROC [RDT].[rdt_840ExtPackCfm03] (    
   @nMobile          INT,    
   @nFunc            INT,    
   @cLangCode        NVARCHAR( 3),    
   @nStep            INT,    
   @nInputKey        INT,    
   @cStorerkey       NVARCHAR( 15),    
   @cPickslipno      NVARCHAR( 10),    
   @nErrNo           INT           OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT    
)    
AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nTranCount     INT    
   DECLARE @bSuccess       INT    
   DECLARE @cAutoMBOLPack  NVARCHAR( 1)    
   DECLARE @cFacility      NVARCHAR( 5)    
   DECLARE @cAssignPackLabelToOrd   NVARCHAR(1)    
   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @b_Success      INT    
   DECLARE @n_Err          INT    
   DECLARE @c_ErrMsg       NVARCHAR( 20)    
   DECLARE @ccurUpdPickDtl CURSOR    
   DECLARE @cPickDetailKey NVARCHAR( 10)    
   DECLARE @cCaseID        NVARCHAR( 20)    
       
   SELECT @cFacility = Facility    
   FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
    
   SELECT TOP 1 @cOrderKey = OrderKey    
   FROM dbo.PackHeader WITH (NOLOCK)    
   WHERE PickSlipNo = @cPickslipno    
   ORDER BY 1    
       
   SET @cAssignPackLabelToOrd = rdt.RDTGetConfig( @nFunc, 'AssignPackLabelToOrd', @cStorerKey)    
    
   SET @nTranCount = @@TRANCOUNT    
    
   SET @nErrNo = 0    
   EXEC nspGetRight    
         @c_Facility   = @cFacility    
      ,  @c_StorerKey  = @cStorerKey    
      ,  @c_sku        = ''    
      ,  @c_ConfigKey  = 'AutoMBOLPack'    
      ,  @b_Success    = @bSuccess             OUTPUT    
      ,  @c_authority  = @cAutoMBOLPack        OUTPUT    
      ,  @n_err        = @nErrNo               OUTPUT    
      ,  @c_errmsg     = @cErrMsg              OUTPUT    
    
   IF @nErrNo <> 0    
   BEGIN    
      SET @nErrNo = 199401    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetRightFail    
      GOTO RollBackTran    
   END    
    
   IF @cAutoMBOLPack = '1'    
   BEGIN    
      SET @nErrNo = 0    
      EXEC dbo.isp_QCmd_SubmitAutoMbolPack    
        @c_PickSlipNo= @cPickSlipNo    
      , @b_Success   = @bSuccess    OUTPUT    
      , @n_Err       = @nErrNo      OUTPUT    
      , @c_ErrMsg    = @cErrMsg     OUTPUT    
    
      IF @nErrNo <> 0    
      BEGIN    
         SET @nErrNo = 199402    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack    
         GOTO RollBackTran    
      END    
   END    
    
   IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)    
               WHERE PickSlipNo = @cPickSlipNo    
               AND STATUS = '0')    
   BEGIN    
      UPDATE dbo.PackHeader SET    
         STATUS = '9'    
      WHERE PickSlipNo = @cPickSlipNo    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 199403    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ConfPackFail    
         GOTO RollBackTran    
      END    
   END    
    
   SET @ccurUpdPickDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
   SELECT PickDetailKey    
   FROM dbo.PICKDETAIL WITH (NOLOCK)    
   WHERE OrderKey = @cOrderKey    
   ORDER BY 1    
   OPEN @ccurUpdPickDtl    
   FETCH NEXT FROM @ccurUpdPickDtl INTO @cPickDetailKey    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
   UPDATE dbo.PICKDETAIL SET     
      CaseID = DropID,    
      EditWho = SUSER_SNAME(),    
      EditDate = GETDATE()    
   WHERE PickDetailKey = @cPickDetailKey    
        
   IF @@ERROR <> 0    
     BEGIN    
        SET @nErrNo = 199404    
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd CaseId Fail    
        GOTO RollBackTran    
     END    
    
   FETCH NEXT FROM @ccurUpdPickDtl INTO @cPickDetailKey    
   END  
     
   -- (james01)    
   IF @cAssignPackLabelToOrd = '1'    
   BEGIN    
      -- Update packdetail.labelno = pickdetail.labelno    
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
       
   EXEC [dbo].[isp_Carrier_Middleware_Interface]            
     @c_OrderKey    = @cOrderKey         
   , @c_Mbolkey     = ''      
   , @c_FunctionID  = @nFunc          
   , @n_CartonNo    = 0      
   , @n_Step        = @nStep      
   , @b_Success     = @b_Success OUTPUT            
   , @n_Err         = @n_Err     OUTPUT            
   , @c_ErrMsg      = @c_ErrMsg  OUTPUT            
       
   IF @b_Success = 0    
   BEGIN    
      SET @nErrNo = 199405    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exec ITF Fail    
      GOTO RollBackTran    
   END    
    
   GOTO Quit    
    
   RollBackTran:    
         ROLLBACK TRAN rdt_PackByTrackNo_PackCfm    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
		 

GO