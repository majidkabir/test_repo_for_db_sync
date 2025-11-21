SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_TrackNo_SortToPallet_SplitMbol                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet_CloseLane                   */    
/*                                                                      */    
/* Purpose: Create Pallet and MBOL record                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-09-15  1.0  James    WMS-20667. Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_TrackNo_SortToPallet_SplitMbol] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cLane          NVARCHAR( 20) OUTPUT,
   @tSplitMBOLVar  VariableTable READONLY,
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
   DECLARE @cSplitMbolSP  NVARCHAR( 20)

   -- Get storer config
   SET @cSplitMbolSP = rdt.RDTGetConfig( @nFunc, 'SortToPallet_SplitMbolSP', @cStorerKey)
   IF @cSplitMbolSP = '0'
      SET @cSplitMbolSP = ''

   /***********************************************************************************************
                                        Custom split mbol
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cSplitMbolSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cSplitMbolSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cLane OUTPUT, @tSplitMBOLVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5) , ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cLane          NVARCHAR( 20) OUTPUT, ' +
         ' @tSplitMBOLVar  VariableTable READONLY, ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cLane OUTPUT, @tSplitMBOLVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END
   
   Quit:
END

GO