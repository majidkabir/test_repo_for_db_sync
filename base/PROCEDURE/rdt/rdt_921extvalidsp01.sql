SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_921ExtValidSP01                                 */  
/* Purpose: Validate  LabelNo                                           */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-09-30 1.1  ChewKP     Unity Seal Tote Validation                */  
/* 2016-04-21 1.2  Ung        SOS368362 Change param                    */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_921ExtValidSP01] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5), 
   @cDropID        NVARCHAR( 20), 
   @cLabelNo       NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cCartonNo      NVARCHAR( 5), 
   @cPickSlipNo    NVARCHAR( 10), 
   @cCartonType    NVARCHAR( 10), 
   @cCube          NVARCHAR( 20), 
   @cWeight        NVARCHAR( 20), 
   @cLength        NVARCHAR( 10),
   @cWidth         NVARCHAR( 10),
   @cHeight        NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
IF @nFunc = 921  
BEGIN  
   
    
--    DECLARE  @cDropID       NVARCHAR(15)
--           , @cPalletConsigneeKey NVARCHAR(15)
--           , @cChildID            NVARCHAR(20)

    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    

       
    IF @nStep = '1'
    BEGIN

       IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                       WHERE DropID = @cDropID
                       AND Status = '9' ) 
       BEGIN
         SET @nErrNo = 91901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDNotClose'
         GOTO QUIT
       END  
    END
    
    IF @nStep = '2'
    BEGIN
      
      IF EXISTS ( SELECT 1 FROM dbo.PackInfo PI WITH (NOLOCK) 
                  INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = PI.PickSlipNo 
                  WHERE PI.RefNo = @cRefNo
                  AND PD.StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 91902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DuplicateSealNo'
         GOTO QUIT
      END
    END
                   
    
    

   
END  
  
QUIT:  

 

GO