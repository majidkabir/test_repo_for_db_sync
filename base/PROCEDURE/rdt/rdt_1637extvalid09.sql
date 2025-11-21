SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Store procedure: rdt_1637ExtValid09                                  */        
/* Purpose: 1 container 1 palletkey                                     */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Rev  Author     Purposes                                  */        
/* 2022-01-10 1.0  James      WMS-18657. Created                        */        
/************************************************************************/        
        
CREATE PROC [RDT].[rdt_1637ExtValid09] (        
   @nMobile                   INT,                 
   @nFunc                     INT,                 
   @cLangCode                 NVARCHAR( 3),        
   @nStep                     INT,                 
   @nInputKey                 INT,                 
   @cStorerkey                NVARCHAR( 15),       
   @cContainerKey             NVARCHAR( 10),       
   @cContainerNo              NVARCHAR( 20),       
   @cMBOLKey                  NVARCHAR( 10),       
   @cSSCCNo                   NVARCHAR( 20),       
   @cPalletKey                NVARCHAR( 18),       
   @cTrackNo                  NVARCHAR( 20),       
   @cOption                   NVARCHAR( 1),       
   @nErrNo                    INT           OUTPUT,        
   @cErrMsg                   NVARCHAR( 20) OUTPUT         
)        
AS        
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   DECLARE @cSeal02     NVARCHAR( 30) = ''  
   DECLARE @nPltCnt     INT = 0  
     
   IF @nStep = 1        
   BEGIN        
      IF @nInputKey = 1  
      BEGIN  
         SET @cMBOLKey = ''  
         SET @cContainerNo = ''  
           
         SELECT @cMBOLKey = MBOLKey,  
                @cContainerNo = ExternContainerKey,   
                @cSeal02 = Seal02  
         FROM dbo.CONTAINER WITH (NOLOCK)   
         WHERE ContainerKey = @cContainerKey  
         AND   OtherReference = @cStorerkey  
           
         IF @@ROWCOUNT = 0  
         BEGIN    
            SET @nErrNo = 180651    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rec Not Exist    
            GOTO Fail    
         END    
           
         IF NOT EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK)  
                         WHERE MbolKey = @cMBOLKey)  
         BEGIN  
            SET @nErrNo = 180652    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mbol Not Exist    
            GOTO Fail    
         END  
           
         IF ISNULL( @cContainerNo, '') = ''  
         BEGIN  
            SET @nErrNo = 180653    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn# Not Exist    
            GOTO Fail    
         END  
  
         IF ISNUMERIC( @cSeal02) = 0  
         BEGIN  
            SET @nErrNo = 180654    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Plt #     
            GOTO Fail    
         END            
      END  
   END  
     
   IF @nStep = 3      
   BEGIN      
      IF @nInputKey = 1  
      BEGIN  
         --PalletID exists in Container    
         IF EXISTS (SELECT 1   
                    FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)  
                    JOIN dbo.CONTAINER C WITH (NOLOCK) ON ( CD.ContainerKey = C.ContainerKey)  
                    WHERE C.OtherReference = @cStorerkey  
                    AND   CD.PalletKey = @cPalletKey)        
         BEGIN    
            SET @nErrNo = 180655    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Exist    
            GOTO Fail    
         END    
  
         SET @cMBOLKey = ''  
           
         SELECT @cMBOLKey = MBOLKey,   
                  @cSeal02 = Seal02  
         FROM dbo.CONTAINER WITH (NOLOCK)   
         WHERE ContainerKey = @cContainerKey  
         AND   OtherReference = @cStorerkey  
           
         DECLARE @tMBOL TABLE ( MBOLKey NVARCHAR( 10) NULL )  
           
         INSERT INTO @tMBOL ( MBOLKey )  
         SELECT DISTINCT MBOLKey  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey IN (  
            SELECT DISTINCT UserDefine02 FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE PalletKey = @cPalletKey)   
  
         IF @@ROWCOUNT = 0  
         BEGIN    
            SET @nErrNo = 180656    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltDtlNotExist    
            GOTO Fail    
         END    
           
         IF @@ROWCOUNT > 1  
         BEGIN    
            SET @nErrNo = 180657    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt >1 Mbol    
            GOTO Fail    
         END             
           
         IF NOT EXISTS ( SELECT 1 FROM @tMBOL WHERE MBOLKey = @cMBOLKey)  
         BEGIN    
            SET @nErrNo = 180658    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff MbolKey    
            GOTO Fail    
         END    
           
         SELECT @nPltCnt = COUNT( DISTINCT PalletKey)  
         FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)  
         JOIN dbo.CONTAINER C WITH (NOLOCK) ON ( CD.ContainerKey = C.ContainerKey)  
         WHERE C.ContainerKey = @cContainerKey  
         AND   C.OtherReference = @cStorerkey  
  
         IF ( @nPltCnt + 1) > CAST( @cSeal02 AS INT)  
         BEGIN    
            SET @nErrNo = 180659    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exceed PltCnt    
            GOTO Fail    
         END    
      END  
   END      
        
   IF @nStep = 6  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @cOption = '1'  
         BEGIN  
            SELECT @cSeal02 = Seal02  
            FROM dbo.CONTAINER WITH (NOLOCK)   
            WHERE ContainerKey = @cContainerKey  
            AND   OtherReference = @cStorerkey  
  
            SELECT @nPltCnt = COUNT( DISTINCT PalletKey)  
            FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)  
            JOIN dbo.CONTAINER C WITH (NOLOCK) ON ( CD.ContainerKey = C.ContainerKey)  
            WHERE C.ContainerKey = @cContainerKey  
            AND   C.OtherReference = @cStorerkey  
  
            IF @nPltCnt <> CAST( @cSeal02 AS INT)  
            BEGIN    
               SET @nErrNo = 180660    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltCnt X Match  
               GOTO Fail    
            END    
         END  
      END  
   END  
        
Fail:   

GO