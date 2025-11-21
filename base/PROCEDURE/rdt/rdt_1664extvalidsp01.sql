SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1664ExtValidSP01                                */  
/* Purpose: Validate Weight Cube                                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-07-23 1.0  ChewKP     SOS#313160 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1664ExtValidSP01] (  
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
   
   DECLARE   @cCarrierKey        NVARCHAR(30)
            ,@cUserDefine02      NVARCHAR(20)
            ,@cCCountry          NVARCHAR(30)
            ,@cOrderType         NVARCHAR(10)
   
   SET @nValid = 1  
   SET @cCarrierKey   = ''
   SET @cUserDefine02 = ''
   SET @cCCountry     = ''
   SET @cOrderType    = ''
   SET @nErrNo        = 0
   SET @cErrMsg       = ''
   
   SELECT  @cCarrierKey   = ISNULL(RTRIM(ShipperKey),'') 
         , @cUserDefine02 = ISNULL(RTRIM(UserDefine02),'') 
         , @cCCountry     = ISNULL(RTRIM(C_Country),'') 
         , @cOrderType    = ISNULL(RTRIM(Type),'') 
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey
   AND StorerKey = @cStorerKey
   
   
   -- Cannot Mix CarrierKey -- 
   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey 
               WHERE MD.MBOLKey = @cMBOLKey
               AND O.ShipperKey <> @cCarrierKey ) 
   BEGIN
       SET @nErrNo = 91101            
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CarrierKeyDifferent        
       GOTO QUIT           
   END
   
   -- Cannot Mix UserDefine02 -- 
   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey 
               WHERE MD.MBOLKey = @cMBOLKey
               AND ISNULL(O.UserDefine02,'') <> @cUserDefine02 ) 
   BEGIN
       SET @nErrNo = 91102           
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UserDefine02Different   
       GOTO QUIT           
   END
   
   -- Cannot Mix CCountry -- 
   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey 
               WHERE MD.MBOLKey = @cMBOLKey
               AND ISNULL(O.C_Country,'') <> @cCCountry ) 
   BEGIN
       SET @nErrNo = 91103           
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CCountryDifferent   
       GOTO QUIT           
   END
   
   -- Cannot Mix OrderType -- 
   IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK)
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey 
               WHERE MD.MBOLKey = @cMBOLKey
               AND ISNULL(O.Type,'') <> @cOrderType ) 
   BEGIN
       SET @nErrNo = 91104           
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OrderTypeDifferent   
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