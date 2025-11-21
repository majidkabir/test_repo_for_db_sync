SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1180ExtValidSP02                                */    
/* Purpose: Validate  DropID                                            */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2016-08-29 1.0  ChewKP     SOS#375645 Created                        */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1180ExtValidSP02] (    
   @nMobile     INT,    
   @nFunc       INT,     
   @cLangCode   NVARCHAR(3),     
   @nStep       INT,     
   @cOption     NVARCHAR(1),     
   @cPalletID   NVARCHAR(20),    
   @cTruckID    NVARCHAR(20),    
   @cShipmentNo NVARCHAR(60),    
   @nErrNo      INT       OUTPUT,     
   @cErrMsg     CHAR( 20) OUTPUT  
)    
AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
    
IF @nFunc = 1180    
BEGIN    
      
    SET @nErrNo          = 0  
    SET @cErrMSG         = ''  
      
    IF @nStep = 1  
    BEGIN  
      -- Validate blank  
      IF @cTruckID = ''  
      BEGIN  
         SET @nErrNo = 103401  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TruckID req  
         GOTO QUIT  
      END  
        
--      IF @cShipmentNo = ''  
--      BEGIN   
--         SET @nErrNo = 95302  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipmentNo req  
--         GOTO QUIT  
--      END  
        
--      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)  
--                      WHERE ShipmentID = @cShipmentNo )  
--      BEGIN  
--         SET @nErrNo = 95303  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipmentIDNotExist  
--         GOTO QUIT  
--      END  
   END  
      
    IF @nStep = 2           
    BEGIN   
      IF @cOption <> '1'  
      BEGIN  
         IF @cPalletID = ''  
         BEGIN  
            SET @nErrNo = 103402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonID Req  
            GOTO QUIT  
         END  
        
         IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)  
                     WHERE    CaseID = @cPalletID  
                     AND     TruckID = @cTruckID     
                     AND   MUStatus IN ('1', '5', '8') )  
         BEGIN  
            SET @nErrNo = 103403  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltIDScanned  
            GOTO QUIT  
         END  
           
      END                
   END  
      
     
END    
    
QUIT:    

GO