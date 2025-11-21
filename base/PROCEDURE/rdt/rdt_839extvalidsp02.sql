SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
        
/************************************************************************/            
/* Store procedure: rdt_839ExtValidSP02                                 */            
/* Purpose: Validate                                                    */            
/*                                                                      */            
/* Modifications log:                                                   */            
/*                                                                      */            
/* Date       Rev  Author     Purposes                                  */            
/* 2019-07-16 1.0  YeeKung    WMS-10112 Created                         */
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/            
        
CREATE   PROC [RDT].[rdt_839ExtValidSP02] (            
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
    
   IF @nStep=3        
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
	               SET @nErrNo = 142401          
	               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDNoAllow'          
	               GOTO QUIT           
	            END        
         	END      
         END    
         ELSE    
         BEGIN    
            IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK)     
                       WHERE wavekey=@cWaveKey AND dropid =@cDropID and pickslipno <>@cPickSlipNo)    
            BEGIN    
               SET @nErrNo = 142402          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OrderMxuse'          
               GOTO QUIT       
            END    
         END      
      END        
   END        
END        
QUIT: 

GO