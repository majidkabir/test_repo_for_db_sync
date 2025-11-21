SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/***************************************************************************/      
/* Store procedure: rdt_727Inquiry07                                       */      
/*                                                                         */  
/* Purpose:                                                                */  
/* -Scan dropid to figure the zone,wave,sku and quantity                   */  
/*                                                                         */      
/* Modifications log:                                                      */     
/* Date       Rev  Author   Purposes                                       */      
/* 2019-09-30 1.0  YeeKung  WMS-100790 Created                             */    
/***************************************************************************/     
  
CREATE PROC [RDT].[rdt_727Inquiry07] (      
  @nMobile      INT,                 
  @nFunc        INT,                 
  @nStep        INT,                  
  @cLangCode    NVARCHAR( 3),        
  @cStorerKey   NVARCHAR( 15),        
  @cOption      NVARCHAR( 1),        
  @cParam1Label    NVARCHAR(20),   
  @cParam2Label    NVARCHAR(20),     
  @cParam3Label    NVARCHAR(20),     
  @cParam4Label    NVARCHAR(20),    
  @cParam5Label    NVARCHAR(20),    
  @cParam1         NVARCHAR(20),     
  @cParam2         NVARCHAR(20),     
  @cParam3         NVARCHAR(20),     
  @cParam4         NVARCHAR(20),     
  @cParam5         NVARCHAR(20),            
  @cOutField01   NVARCHAR(20) OUTPUT,      
  @cOutField02   NVARCHAR(20) OUTPUT,      
  @cOutField03   NVARCHAR(20) OUTPUT,      
  @cOutField04   NVARCHAR(20) OUTPUT,      
  @cOutField05   NVARCHAR(20) OUTPUT,      
  @cOutField06   NVARCHAR(20) OUTPUT,      
  @cOutField07   NVARCHAR(20) OUTPUT,      
  @cOutField08   NVARCHAR(20) OUTPUT,      
  @cOutField09   NVARCHAR(20) OUTPUT,      
  @cOutField10   NVARCHAR(20) OUTPUT,  
  @cOutField11   NVARCHAR(20) OUTPUT,  
  @cOutField12   NVARCHAR(20) OUTPUT,  
  @cFieldAttr02  NVARCHAR( 1) OUTPUT,    
  @cFieldAttr04  NVARCHAR( 1) OUTPUT,    
  @cFieldAttr06  NVARCHAR( 1) OUTPUT,    
  @cFieldAttr08  NVARCHAR( 1) OUTPUT,    
  @cFieldAttr10  NVARCHAR( 1) OUTPUT,          
  @nNextPage     INT          OUTPUT,      
  @nErrNo        INT          OUTPUT,          
  @cErrMsg       NVARCHAR( 20) OUTPUT      
)      
AS      
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cWaveKey       NVARCHAR(10)   
         ,@cDropID         NVARCHAR(20)  
         ,@cPutawayZone    NVARCHAR(10)  
  
   SET @nErrNo = 0   
            
        
   IF @nStep = 2   
   BEGIN  
      SET @cDropID = @cParam1   
  
      IF @cDropID = ''  
      BEGIN  
         SET @nErrNo = 145001   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq  
         GOTO QUIT   
      END  
   END  
        
   SELECT TOP 1  
         @cWaveKey  = WaveKey  
   FROM dbo.pickdetail WITH (NOLOCK)   
   WHERE dropid = @cdropid  
   AND  Status <= 5   
  
   SELECT @cPutawayZone=userdefine02  
   FROM wave WITH (NOLOCK)  
   WHERE wavekey=@cWaveKey  
  
   SET @cOutField01 = 'DropID:'  
   SET @cOutField02 = @cDropID  
   SET @cOutField03 = 'Wave     :' + @cWaveKey  
   SET @cOutField04 = 'PZone    :' + @cPutawayZone  
           
   SET @nNextPage = 0  
     
QUIT:  

GO