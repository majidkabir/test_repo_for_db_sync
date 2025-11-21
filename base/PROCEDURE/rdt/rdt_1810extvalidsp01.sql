SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1810ExtValidSP01                                */  
/* Purpose: Validate ToteID and Return Suggested WCSStation             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-05-08 1.0  ChewKP     Created                                   */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1810ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cDropID     NVARCHAR(20),  
   @cSuggWCSStation NVARCHAR(10) OUTPUT , 
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 1810  
BEGIN  
   
    
    DECLARE  @cDropIDType NVARCHAR(10)
           , @cStoreGroup   NVARCHAR(20)
           , @cConsigneeKey NVARCHAR(15)  
           , @cToLoc        NVARCHAR(10)
           , @cPutawayZone  NVARCHAR(10)
           , @cPickslipNo   NVARCHAR(10)
           , @cLoadKey      NVARCHAR(10)
           , @cWaveKey      NVARCHAR(10)


    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cDropIDType     = ''
    SET @cStoreGroup     = ''
    SET @cConsigneeKey   = ''
    SET @cSuggWCSStation = ''
    SET @cPickSlipNo     = ''
    SET @cLoadKey        = ''
    SET @cPutawayZone    = ''
    SET @cToLoc          = ''
    SET @cWaveKey        = ''
    
    
    
    IF LEN(@cDropID) > 8 
    BEGIN
      SET @cDropIDType = 'UCC'
    END
    ELSE 
    BEGIN
      SET @cDropIDType = 'TOTE'
    END

    IF @cDropIDType = 'UCC'
    BEGIN
       IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                       AND UCCNo = @cDropID ) 
       BEGIN
            SET @nErrNo = 87851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCNotExist'
            GOTO QUIT
       END
       

       
       SELECT TOP 1   @cStoreGroup = CASE WHEN O.Type = 'N' THEN O.OrderGroup + O.SectionKey ELSE 'OTHERS' END  
                   , @cConsigneeKEy = OD.UserDefine02 
                   , @cPickSlipNo = PD.PickSlipNo
                   , @cWaveKey    = O.UserDefine09
       FROM dbo.PickDetail PD WITH (NOLOCK)       
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey      
       INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey  
       WHERE PD.DropID  = @cDropID      
       AND PD.StorerKey = @cStorerKey   
       AND PD.Status = '3'

    
       
       SELECT @cToLoc = Loc   
       FROM StoreToLocDetail WITH (NOLOCK)  
       WHERE ConsigneeKey = @cConsigneeKey   
       AND StoreGroup = @cStoreGroup  


    
       SELECT @cPutawayZone = PutawayZone   
       FROM dbo.Loc WITH (NOLOCK)   
       WHERE Loc = @cToLoc  

     
       
       SELECT @cSuggWCSStation = ISNULL(RTRIM(Short), '')              
       FROM CODELKUP WITH (NOLOCK)              
       WHERE Listname = 'WCSSTATION'              
       AND   Code = @cPutawayZone  
       
       
     
        
    END
    ELSE IF @cDropIDType = 'TOTE'
    BEGIN
       IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                       WHERE DropID = @cDropID
                       AND Status = '5' ) 
       BEGIN
            SET @nErrNo = 87852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidTote'
            GOTO QUIT
       END
       
       SELECT @cPickSlipNo = PickSlipNo
            , @cLoadKey    = LoadKey
       FROM dbo.DropID WITH (NOLOCK)
       WHERE DropID = @cDropID
       AND Status = '5'
       
       SELECT TOP 1   @cStoreGroup = CASE WHEN O.Type = 'N' THEN O.OrderGroup + O.SectionKey ELSE 'OTHERS' END  
                   , @cConsigneeKEy = OD.UserDefine02 
                   , @cWaveKey      = O.UserDefine09
       FROM dbo.PickDetail PD WITH (NOLOCK)       
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey      
       INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey  
       WHERE PD.DropID  = @cDropID      
       AND PD.StorerKey = @cStorerKey  
       AND PD.PickSlipNo = @cPickSlipNo
       AND O.LoadKey     = @cLoadKey 
       AND PD.Status = '5'
       
       SELECT @cToLoc = Loc   
       FROM StoreToLocDetail WITH (NOLOCK)  
       WHERE ConsigneeKey = @cConsigneeKey   
       AND StoreGroup = @cStoreGroup  
    
       SELECT @cPutawayZone = PutawayZone   
       FROM dbo.Loc WITH (NOLOCK)   
       WHERE Loc = @cToLoc  
       
       SELECT @cSuggWCSStation = ISNULL(RTRIM(Short), '')              
       FROM CODELKUP WITH (NOLOCK)              
       WHERE Listname = 'WCSSTATION'              
       AND   Code = @cPutawayZone  
       
       
    END
               
   
END  
  
QUIT:  

 

GO