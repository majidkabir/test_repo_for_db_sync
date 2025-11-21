SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_521ExtUpd01                                     */  
/* Purpose: Extended update for H&M UCC Putaway (UNLOCK pendingmovein)  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-10-05 1.0  James      SOS#353559                                */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_521ExtUpd01] (  
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,        
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cUCCNo          NVARCHAR( 18), 
   @cSuggestedLOC   NVARCHAR( 10), 
   @cToLOC          NVARCHAR( 10), 
   @nErrNo          INT OUTPUT,    
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE  @cUserName     NVARCHAR( 18), 
            @cFromLOC      NVARCHAR( 10), 
            @cID           NVARCHAR( 18)

   -- For H&M, if suggestedloc not found then suggest a dummy loc
   -- Then user key in desired loc but the dummy loc need to unlock
   -- the pendingmovein qty as well
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get LOC, ID
   SET @cFromLOC = ''
   SET @cID = ''
   SELECT TOP 1 
      @cFromLOC = LOC, 
      @cID = ID
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   UCCNo = @cUCCNo
   AND   Status = '1'

   SELECT @cUserName = UserName 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE MOBILE = @nMobile

   -- Unlock SuggestedLOC  
   EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'  
      ,''   
      ,@cID   
      ,@cSuggestedLOC  
      ,@cStorerKey  
      ,@nErrNo  OUTPUT  
      ,@cErrMsg OUTPUT  

   IF @nErrNo <> 0  
      GOTO Quit

QUIT:  

 

GO