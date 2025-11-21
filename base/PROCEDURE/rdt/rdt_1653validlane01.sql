SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Store procedure: rdt_1653ValidLane01                                 */        
/* Copyright      : MAERSK                                              */        
/*                                                                      */        
/* Called from: rdt_TrackNo_SortToPallet_ValidateLane                   */        
/*                                                                      */        
/* Purpose: Validate Lane                                               */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2023-08-23  1.0  James    WMS-23471. Created                         */      
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_1653ValidLane01] (        
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,    
   @nInputKey      INT,    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cTrackNo       NVARCHAR( 40),    
   @cOrderKey      NVARCHAR( 20),    
   @cPalletKey     NVARCHAR( 20),    
   @cMBOLKey       NVARCHAR( 10),    
   @cLabelNo       NVARCHAR( 20),
   @tValidateLane  VariableTable READONLY,    
   @cLane          NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT            
) AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
       
   DECLARE @cB2CNoLane        NVARCHAR( 1)    
   DECLARE @cPreMBOLChk       NVARCHAR( 1)
   
   IF @nStep = 2    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         SET @cB2CNoLane = rdt.RDTGetConfig( @nFunc, 'B2CNOLANE', @cStorerkey)

         SET @cPreMBOLChk = rdt.RDTGetConfig( @nFunc, 'PREMBOLCHK', @cStorerkey)
         
         IF @cB2CNoLane = '1'
         BEGIN
         	IF EXISTS ( SELECT 1
         	            FROM dbo.ORDERS WITH (NOLOCK)
         	            WHERE OrderKey = @cOrderKey
         	            AND   [Type] = 'B2C')
   	         SET @cLane = @cPalletKey
   	      ELSE
   	      	-- Other orders type use back what user key in
   	      	SELECT @cLane = I_Field04
   	      	FROM RDT.RDTMOBREC WITH (NOLOCK)
   	      	WHERE Mobile = @nMobile
            
            GOTO Quit
         END
      
         IF @cPreMBOLChk = '1'
         BEGIN
   	      SET @cLane = @cPalletKey
   	      
   	      GOTO Quit
         END
      END     
   END    

   GOTO Quit    
       
   Quit:      
        
END 

GO