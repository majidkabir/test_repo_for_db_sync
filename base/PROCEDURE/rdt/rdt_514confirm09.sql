SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO


--DROP PROC [rdt].rdt_514Confirm09
--ET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
--            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
--            ' @cToID, @cToLoc, @cFromLoc, @cFromID, ' + 
--            ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, ' + 
--            ' @i OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

CREATE  PROC [rdt].rdt_514Confirm09 (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cFacility     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @i				int  output,
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
	select 1
end


GO