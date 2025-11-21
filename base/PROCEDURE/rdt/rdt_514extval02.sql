SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_514ExtVal02                                     */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-04-23 1.0  Ung        SOS340172 Created                         */  
/* 2019-03-26 1.1  James      WMS-8352 Add From ID (james01)            */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_514ExtVal02] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC           NVARCHAR( 20), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   IF @nFunc = 514  
   BEGIN  
      IF @nStep = 2 -- ToLOC
      BEGIN
         IF EXISTS( SELECT 1 
            FROM dbo.TaskDetail TD WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC AND LOC.LocationCategory = 'VNAKP')
            WHERE TaskType = 'PAF' 
               AND StorerKey = @cStorerKey 
               AND FromID = @cToID)
         BEGIN
            SET @nErrNo = 53901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet closed
            GOTO Quit
         END
      END
   END  
  
Quit:  

END

GO