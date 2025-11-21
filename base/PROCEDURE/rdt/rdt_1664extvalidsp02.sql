SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1664ExtValidSP02                                */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2016-09-30 1.0  ChewKP     SOS#WMS-428 Created                       */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1664ExtValidSP02] (    
   @nMobile         INT,               
   @nFunc           INT,               
   @cLangCode       NVARCHAR( 3),      
   @cStorerKey      NVARCHAR( 15),     
   @cMBOLKey        NVARCHAR( 10),     
   @cOrderKey       NVARCHAR( 10),     
   @cTrackNo        NVARCHAR( 18),     
   @nValid          INT            OUTPUT,      
   @nErrNo          INT            OUTPUT,      
   @cErrMsg         NVARCHAR( 20)  OUTPUT,      
   @cErrMsg1        NVARCHAR( 20)  OUTPUT,      
   @cErrMsg2        NVARCHAR( 20)  OUTPUT,      
   @cErrMsg3        NVARCHAR( 20)  OUTPUT,      
   @cErrMsg4        NVARCHAR( 20)  OUTPUT,      
   @cErrMsg5        NVARCHAR( 20)  OUTPUT      
)    
AS    
    
SET NOCOUNT ON         
SET QUOTED_IDENTIFIER OFF         
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF     
  
    
IF @nFunc = 1664    
BEGIN    
     
   DECLARE   @cRoute             NVARCHAR(10)  
            ,@cInterModalVehicle NVARCHAR(30)  
            ,@cOrderType         NVARCHAR(10)  
     
   SET @nValid             = 1    
   SET @cRoute             = ''  
   SET @cInterModalVehicle = ''  
   SET @cOrderType         = ''  
   SET @nErrNo             = 0  
   SET @cErrMsg            = ''  
     
   SELECT  @cRoute   = ISNULL(RTRIM(Route),'')   
         , @cInterModalVehicle = ISNULL(RTRIM(InterModalVehicle),'')   
         , @cOrderType    = ISNULL(RTRIM(Type),'')   
   FROM dbo.Orders WITH (NOLOCK)   
   WHERE OrderKey = @cOrderKey  
   AND StorerKey = @cStorerKey  
     
     
   -- Cannot Mix Route --   
   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)  
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey   
               WHERE MD.MBOLKey = @cMBOLKey  
               AND O.Route <> @cRoute )   
   BEGIN  
       SET @nErrNo = 104551              
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- RouteDiff          
       GOTO QUIT             
   END  
     

   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)  
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey   
               WHERE MD.MBOLKey = @cMBOLKey  
               AND ISNULL(O.InterModalVehicle,'') <> @cInterModalVehicle )   
   BEGIN  
       SET @nErrNo = 104352             
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InterModalDiff     
       GOTO QUIT             
   END  
     

   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)  
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey   
               WHERE MD.MBOLKey = @cMBOLKey  
               AND ISNULL(O.Type,'') <> @cOrderType )   
   BEGIN  
       SET @nErrNo = 104353             
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OrderTypeDiff     
       GOTO QUIT             
   END  
     
   
   
  
     
END    
    
QUIT:    
IF @nErrNo <> 0  
BEGIN  
   SET @nValid = 0    
   SET @cErrMsg1 = @nErrNo  
   SET @cErrMSg2 = @cErrMSg  
END  
  

GO