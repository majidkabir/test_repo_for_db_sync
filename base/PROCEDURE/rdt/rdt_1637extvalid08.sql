SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_1637ExtValid08                                  */      
/* Purpose: 1 container 1 palletkey                                     */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author     Purposes                                  */      
/* 2021-05-18 1.0  James      Add hoc fix                               */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_1637ExtValid08] (      
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
    
   IF @nInputKey = 1      
   BEGIN      
      IF @nStep = 3    
      BEGIN    
         --PalletID exists in Container  
         IF EXISTS (SELECT 1 FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
                    WHERE PalletKey = @cPalletKey)      
         BEGIN  
            SET @nErrNo = 167901  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Exist  
            GOTO Fail  
         END  
      END    
   END      
      
Fail: 

GO