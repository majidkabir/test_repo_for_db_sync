SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PackByTrackNo_PackCfm                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Pack confirm                                                */
/*                                                                      */
/* Called From: rdtfnc_PackByTrackNo                                    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-09-10 1.0  James      WMS-15010 Created                         */  
/* 2021-04-19 1.1  James      WMS-16841 Add AssignPackLabelToOrdCfg     */
/*                            when config turn on (james01)             */
/* 2021-06-23 1.2  James      WMS-16955 Add ExtendedPackCfmSP (james02) */
/* 2021-04-01 1.3  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */ 
/************************************************************************/

CREATE PROC rdt.rdt_PackByTrackNo_PackCfm (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cPickslipno               NVARCHAR( 10),
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,  
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)

   -- Get extended putaway
   DECLARE @cExtendedPackCfmSP NVARCHAR(20)
   SET @cExtendedPackCfmSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPackCfmSP', @cStorerKey)
   IF @cExtendedPackCfmSP = '0'
      SET @cExtendedPackCfmSP = ''  

   -- Extended putaway
   IF @cExtendedPackCfmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPackCfmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPackCfmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cPickslipno, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile          INT,             ' +
            '@nFunc            INT,             ' +
            '@cLangCode        NVARCHAR( 3),    ' +
            '@nStep            INT,             ' +
            '@nInputKey        INT,             ' +
            '@cStorerkey       NVARCHAR( 15),   ' + 
            '@cPickslipno      NVARCHAR( 10),   ' +
            '@nErrNo           INT           OUTPUT, ' +
            '@cErrMsg          NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cPickslipno, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   ELSE
   BEGIN
      DECLARE @nTranCount     INT
      DECLARE @bSuccess       INT
      DECLARE @cAutoMBOLPack  NVARCHAR( 1)
      DECLARE @cFacility      NVARCHAR( 5)
      DECLARE @cAssignPackLabelToOrd   NVARCHAR(1)
   
      SELECT @cFacility = Facility
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
   
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
         SET @nErrNo = 158851  
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
            SET @nErrNo = 158852  
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
            SET @nErrNo = 158853        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ConfPackFail    
            GOTO RollBackTran  
         END 
      END

      -- (james01)
      IF @cAssignPackLabelToOrd = '1'
      BEGIN
         -- Update packdetail.labelno = pickdetail.caseid
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
   
      GOTO Quit
   
      RollBackTran:  
       
            ROLLBACK TRAN rdt_PackByTrackNo_PackCfm  
      Quit:  
         WHILE @@TRANCOUNT > @nTranCount  
            COMMIT TRAN  
   END

GO