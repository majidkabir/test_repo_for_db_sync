SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/************************************************************************/            
/* Store procedure: rdt_839ExtValidSP08                                 */            
/* Purpose: Validate                                                    */            
/*                                                                      */            
/* Modifications log:                                                   */            
/*                                                                      */            
/* Date       Rev  Author     Purposes                                  */            
/* 2021-08-02 1.0  YeeKung    WMS-17596 Created                         */
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/            
        
CREATE   PROC [RDT].[rdt_839ExtValidSP08] (            
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),        
   @nStep           INT,              
   @nInputKey       INT,        
   @cFacility       NVARCHAR( 5) ,           
   @cStorerKey      NVARCHAR( 15),        
   @cType           NVARCHAR( 10),           
   @cPickSlipNo     NVARCHAR( 10),           
   @cPickZone       NVARCHAR( 10),           
   @cDropID         NVARCHAR( 20),          
   @cLOC            NVARCHAR( 10),         
   @cSKU            NVARCHAR( 20),         
   @nQTY            INT,   
   @cPackData1      NVARCHAR( 30),
   @cPackData2      NVARCHAR( 30),
   @cPackData3      NVARCHAR( 30),                  
   @nErrNo          INT           OUTPUT,           
   @cErrMsg         NVARCHAR( 20) OUTPUT          
)            
AS            
        
        
SET NOCOUNT ON          
SET QUOTED_IDENTIFIER OFF          
SET ANSI_NULLS OFF          
SET CONCAT_NULL_YIELDS_NULL OFF          
            
IF @nFunc = 839            
BEGIN         
           
   DECLARE @cWaveKey      NVARCHAR(10),    
   @cLoadPlan             NVARCHAR(20),    
   @cOrderkey             NVARCHAR(20)       
           
   SET @nErrNo          = 0          
   SET @cErrMSG         = ''         
        
   SELECT @cOrderkey=Orderkey,@cWaveKey = Wavekey          
   FROM dbo.PickHeader WITH (NOLOCK)           
   WHERE PickHeaderKey = @cPickSlipNo         
    
   SELECT @cLoadPlan=a.loadplangroup     
   FROM dbo.Wave a WITH (NOLOCK) JOIN     
   dbo.WaveDetail b WITH (NOLOCK) ON a.wavekey=b.wavekey    
   WHERE b.orderkey=@cOrderkey    

IF @nStep=2  
   BEGIN  
      IF @nInputKey=1        
      BEGIN  
           
         IF EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK) JOIN PICKHEADER PH (NOLOCK)
                     ON PD.Pickslipno=PH.PickHeaderkey
                     WHERE PD.STORERKEY=@cStorerKey
                        AND PD.STATUS='5'
                        AND DROPID=@cDropID
                        AND PH.WAVEKEY<>@cWaveKey
                        AND NOT EXISTS (SELECT 1 FROM PACKHEADER PCH (NOLOCK)
                        WHERE PCH.OrderKey = PD.Orderkey
                        AND PCH.StorerKey = PD.Storerkey
                        AND PCH.Status = '9')
                        )  
         BEGIN  
            SET @nErrNo = 172651          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropidInUse'          
            GOTO QUIT  
         END  
      END  
   END      
END        
QUIT: 

GO