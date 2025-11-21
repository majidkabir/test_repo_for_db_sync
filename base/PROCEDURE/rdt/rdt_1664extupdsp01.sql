SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1664ExtUpdSP01                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: ANF Scan To MBOL Logic                                      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-08-20  1.0  ChewKP   Created                                    */    
/* 2015-04-22  1.1  ChewKP   SOS#339560 Add ExtendedUpSP on Step5       */
/*                           (ChewKP08)                                 */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1664ExtUpdSP01] (    
   @nMobile     INT,    
   @nFunc       INT,    
   @cLangCode   NVARCHAR( 3),    
   @cUserName   NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cStorerKey  NVARCHAR( 15),    
   @cTrackNo    NVARCHAR( 20),    
   @cMBOLKey    NVARCHAR( 20),  
   @nStep       INT,  
   @cOrderKey   NVARCHAR( 10),  
   @cLabelNo    NVARCHAR( 20), -- (ChewKP01) 
   @nErrNo      INT           OUTPUT,    
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @nTranCount        INT  
          ,@nTotalWeight      FLOAT
          ,@cPickSlipNo       NVARCHAR(10)
          ,@cUseSequence      INT
     
   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   SET @nTotalWeight = 0 
   SET @cPickSlipNo  = 0 
 
     
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_1664ExtUpdSP01  
     
     
   IF @nStep = 2  
   BEGIN  
         
         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey 
         
         SELECT @nTotalWeight = ISNULL(SUM(SKU.STDGROSSWGT * PD.Qty ) , 0 ) 
         FROM dbo.PackDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey
         WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.StorerKey = @cStorerKey
         
         UPDATE dbo.MBOLDetail
         SET Weight = @nTotalWeight
         WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey 
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 91601  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdMBOLDetFail'  
            --SET @cErrMsg = 'GenLblSPNotFound'  
            GOTO RollBackTran  
         END
         
   END  
     
        
              

  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_1664ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1664ExtUpdSP01  
    
  
END    

GO