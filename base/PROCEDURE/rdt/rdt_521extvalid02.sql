SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_521ExtValid02                                   */  
/* Purpose: Validate From loc must be staging                           */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-08-16 1.0  James      SOS#373949                                */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_521ExtValid02] (  
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,        
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cUCCNo          NVARCHAR( 20), 
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

   DECLARE  @cFromLOC      NVARCHAR( 10), 
            @cFacility     NVARCHAR( 5)

   SET @nErrNo = 0
   SET @cErrMSG = ''

   SELECT @cFacility = Facility 
   FROM rdt.rdtMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         SET @cFromLOC = ''

         SELECT TOP 1 @cFromLOC = LOC
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   Status = '1'

         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                         WHERE Facility = @cFacility
                         AND   LOC = @cFromLOC
                         AND   LocationCategory = 'STAGING')
         BEGIN
            INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3) VALUES ('521', GETDATE(), @cFacility, @cFromLOC, @cUCCNo)
            SET @nErrNo = 102901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid TO LOC'
            GOTO Quit
         END
      END
   END
  
QUIT:  

 

GO