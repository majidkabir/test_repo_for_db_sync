SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Store procedure: rdt_991ExtValidSP01                                 */          
/* Purpose: Validate                                                    */          
/*                                                                      */          
/* Modifications log:                                                   */          
/*                                                                      */          
/* Date       Rev  Author     Purposes                                  */          
/* 2019-11-21 1.0  YeeKung    WMS-11200 Created                         */            
/************************************************************************/          
      
CREATE PROC [RDT].[rdt_991ExtValidSP01] (          
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
   @nErrNo          INT           OUTPUT,         
   @cErrMsg         NVARCHAR( 20) OUTPUT        
)          
AS          
      
      
SET NOCOUNT ON        
SET QUOTED_IDENTIFIER OFF        
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF        
          
IF @nFunc = 991          
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

   IF @nStep=3
   BEGIN
      IF @nInputKey=1      
      BEGIN  
         IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                     WHERE STORERKEY=@cStorerKey 
                        AND STATUS='5'
                        AND DROPID=@cDropID
                        AND WAVEKEY<>@cWaveKey)
         BEGIN
            IF EXISTS( SELECT 1 from PICKDETAIL PD WITH (NOLOCK) 
                            JOIN  ORDERS O WITH (NOLOCK) 
                           ON O.OrderKey=PD.OrderKey
                           WHERE O.SOStatus<>'5' 
                              AND PD.Status='5' 
                              AND PD.WaveKey<>@cWavekey
                              AND PD.dropid =@cDropID)
            BEGIN
               SET @nErrNo = 146251       
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropidInUse'        
               GOTO QUIT
            END
         END
      END
   END
  
   IF @nStep=4      
   BEGIN      
      IF @nInputKey=1      
      BEGIN  
        
         IF NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)  
         WHERE LISTNAME='PickMatter' AND CODE2 =@cFacility  
         AND CODE='LOADPLAN' AND UDF01=  @cLoadPlan)  
         BEGIN   
      
            IF EXISTS (SELECT 1 FROM dbo.orders WITH (NOLOCK)       
             WHERE userdefine09=@cWaveKey       
            AND ORDERGROUP='MULTI'       
            AND STORERKEY=@cStorerKey      
            AND FACILITY=@cFacility)      
            BEGIN      
               IF EXISTS(Select 1 FROM PICKDETAIL WITH (NOLOCK)       
                        WHERE STORERKEY=@cStorerKey      
                           AND Wavekey=@cWaveKey       
                           AND DROPID=@cDropID       
                           AND SKU  <> @cSKU)      
               BEGIN      
                  SET @nErrNo = 146252        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDMissUse'        
                  GOTO QUIT         
               END      
            END    
            
            
         END  
         ELSE  
         BEGIN  
            IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK)   
                       WHERE WAVEKEY=@cWaveKey 
                        AND DROPID =@cDropID 
                        AND pickslipno <>@cPickSlipNo)  
            BEGIN  
               SET @nErrNo = 146253        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ORDERMxDropID'        
               GOTO QUIT     
            END  
         END    
      END      
   END      
END      
QUIT:    


GO