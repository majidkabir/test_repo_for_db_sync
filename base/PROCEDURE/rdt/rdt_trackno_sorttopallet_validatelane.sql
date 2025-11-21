SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Store procedure: rdt_TrackNo_SortToPallet_ValidateLane               */        
/* Copyright      : MAERSK                                              */        
/*                                                                      */        
/* Called from: rdtfnc_TrackNo_SortToPallet                             */        
/*                                                                      */        
/* Purpose: Validate Lane                                               */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2023-08-23  1.0  James    WMS-23471. Created                         */      
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_TrackNo_SortToPallet_ValidateLane] (        
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
       
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cValidLaneSP   NVARCHAR( 20)
   
   -- Get storer config
   SET @cValidLaneSP = rdt.RDTGetConfig( @nFunc, 'SortToPallet_ValidateLaneSP', @cStorerKey)
   IF @cValidLaneSP = '0'
      SET @cValidLaneSP = ''

   /***********************************************************************************************
                                       Custom Validate Lane
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cValidLaneSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cValidLaneSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLabelNo, ' +
         ' @tValidateLane, @cLane OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5) , ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cTrackNo       NVARCHAR( 40), ' +
         ' @cOrderKey      NVARCHAR( 10), ' +
         ' @cPalletKey     NVARCHAR( 20), ' +
         ' @cMBOLKey       NVARCHAR( 10), ' +
         ' @cLabelNo       NVARCHAR( 20), ' +
         ' @tValidateLane  VariableTable READONLY, ' +
         ' @cLane          NVARCHAR( 20) OUTPUT, ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLabelNo,
         @tValidateLane, @cLane OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END

   Quit:      
        
END 

GO