SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_841ExtValidSP02                                 */  
/* Purpose: Validate Weight Cube                                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-10-06 1.0  ChewKP     SOS#353352 Created                        */  
/* 2021-04-01 1.1  YeeKung    WMS-16718 Add serialno and serialqty      */
/*                            Params (yeekung02)                        */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_841ExtValidSP02] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cDropID     NVARCHAR(20),  
   @cSKU        NVARCHAR(20), 
   @cPickSlipNo NVARCHAR(10),
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT, 
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON       
SET QUOTED_IDENTIFIER OFF       
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF   

  
IF @nFunc = 841  
BEGIN  
   
   DECLARE @nSUM_PackQTY INT
         , @nSUM_PickQTY INT
         , @cDropIDType  NVARCHAR(10) 
         , @cOrderType   NVARCHAR(10) 
         , @cOrderKey    NVARCHAR(10)
         , @cLoadKey     NVARCHAR(10) 
   
   
   SET @nErrNo = 0 
   SET @cErrMSG = ''
   SET @cOrderType = ''
   SET @cOrderKey  = ''
   SET @cLoadKey   = ''
   
   SELECT @cDropIDType  = ISNULL(RTRIM(DropIDType),'')            
         ,@cLoadKey     = LoadKey
   FROM dbo.DROPID WITH (NOLOCK)             
   WHERE DropId = @cDropID  
   AND Status = '5'           
   AND PickSlipNo = @cPickSlipNo
               
   -- invalid dropidtype            
   IF ISNULL(RTRIM(@cDropIDType),'') <> 'SINGLES' 
   AND ISNULL(RTRIM(@cDropIDType),'') <> 'MULTIS'            
   BEGIN            
      SET @nErrNo = 94302            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote            
      GOTO QUIT              
   END  
         
   
   IF @nStep = 1
   BEGIN
         IF  ISNULL(RTRIM(@cDropIDType),'') = 'MULTIS' 
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                        INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
                        WHERE PD.Status = '0' 
                        AND PH.PickHeaderKey = @cPickSlipNo ) 
            BEGIN
                SET @nErrNo = 94306            
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteNotPicked    
                GOTO QUIT         
            END
         END
               
         SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0  
         
         SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)  
         FROM dbo.PackDetail PD WITH (NOLOCK)   
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         INNER JOIN dbo.PickHeader PickH WITH (NOLOCK) ON PickH.PickHeaderKey = PH.PickSlipNo
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PickH.OrderKey
         WHERE PD.StorerKey = @cStorerKey  
            AND PD.DropID = @cDropID  
            --AND PD.PickSlipNo = @cPickSlipNo
            AND O.LoadKey = @cLoadKey 
            AND O.Status = '5'   -- (james01)

         SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)   
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey  
         WHERE PD.StorerKey = @cStorerKey  
           AND PD.DropID = @cDropID  
           AND PD.Status IN ('5'  ) 
           --AND PH.PickHeaderKey = @cPickSlipNo
           AND O.LoadKey = @cLoadKey  
           
    
           
         
         IF @nSUM_PackQTY = @nSUM_PickQTY  
         BEGIN            
            SET @nErrNo = 94301            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted            
            GOTO QUIT              
         END         
         

         
               
    
         
   END
   
   IF @nStep = 2
   BEGIN
--      SELECT @cDropIDType  = ISNULL(RTRIM(DropIDType),'')            
--      FROM dbo.DROPID WITH (NOLOCK)             
--      WHERE DropId = @cDropID  
--      AND Status = '5'           
--      AND PickSlipNo = @cPickSlipNo
         
      SELECT Top 1  @cOrderType  = O.Type  
                   ,@cOrderKey   = O.OrderKey
      FROM dbo.Orders O WITH (NOLOCK)  
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey 
      INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
      WHERE PD.DropID = @cDropID
      AND O.StorerKey = @cStorerKey  
      --AND PH.PickHeaderKey = @cPickSlipNo 
      AND O.LoadKey = @cLoadKey
      
      IF ISNULL(@cOrderType,'')  = 'TMALL' AND ISNULL(RTRIM(@cDropIDType),'') = 'MULTIS'
      BEGIN
            --Check if Order.SOStatus = 'HOLD'      
         IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                    INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                        WHERE O.Orderkey = @cOrderkey      
                        AND O.Storerkey = @cStorerkey      
                        AND CL.Listname = 'SOStatus'      
                        AND CL.Code = 'HOLD'      
                        )      
         BEGIN      
             SET @nErrNo =  94303      
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Hold!      
             GOTO QUIT    
         END      
               
         -- (ChewKP03)      
         --Check if Order.SOStatus = 'PENDCANC'      
         IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                    INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                        WHERE O.Orderkey = @cOrderkey      
                        AND O.Storerkey = @cStorerkey      
                        AND CL.Listname = 'SOStatus'      
                        AND CL.Code = 'PENDCANC'      
                        )      
         BEGIN      
             SET @nErrNo =  94304      
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Waiting Cancel!      
             GOTO QUIT      
         END      
           
         -- (ChewKP05)      
         --Check if Order.SOStatus = 'PENDCANC'      
         IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                    INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                        WHERE O.Orderkey = @cOrderkey      
                        AND O.Storerkey = @cStorerkey      
                        AND CL.Listname = 'SOStatus'      
                        AND CL.Code = 'CANC'      
                        )      
         BEGIN      
             SET @nErrNo =  94305      
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Cancelled    
             GOTO QUIT   
         END    
      END
      
   END

   
END  
  
QUIT:  

 

GO