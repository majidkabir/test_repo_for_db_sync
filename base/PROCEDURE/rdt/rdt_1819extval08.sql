SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal08                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-04-27   James     1.0   WMS13037. Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal08]
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,           
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cFacility      NVARCHAR( 5)  
   DECLARE @cStorerKey     NVARCHAR( 15)
  
   -- Change ID  
   IF @nFunc = 1819  
   BEGIN  
      IF @nStep = 1 -- FromID  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Get Facility, Storer  
            SELECT @cFacility = Facility, 
                   @cStorerKey = StorerKey
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE Mobile = @nMobile  

            -- Check ID in inventory and with pendingmovein > 0
            IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                        WHERE LOC.Facility = @cFacility
                        AND   LLI.StorerKey = @cStorerKey
                        AND   LLI.Id = @cFromID
                        AND   LLI.PendingMoveIN > 0)
            BEGIN  
               SET @nErrNo = 151301  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Putaway  
               GOTO Quit  
            END  

            -- Check if Pallet already finish putaway
            IF EXISTS( SELECT 1   
                       FROM TaskDetail TD WITH (NOLOCK)   
                       JOIN LOC WITH (NOLOCK) ON ( LOC.LOC = TD.FromLOC)  
                       WHERE LOC.Facility = @cFacility  
                       AND   TD.TaskType = 'PA1'  
                       AND   TD.FromID = @cFromID  
                       AND   TD.Status = '9')  
            BEGIN  
               SET @nErrNo = 151302  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Task Exists  
               GOTO Quit  
            END  
            
            -- Check ID in transit  
            IF EXISTS( SELECT 1   
                       FROM TaskDetail TD WITH (NOLOCK)   
                       JOIN LOC WITH (NOLOCK) ON ( LOC.LOC = TD.FromLOC)  
                       WHERE LOC.Facility = @cFacility  
                       AND   TD.TaskType = 'PA1'  
                       AND   TD.FromID = @cFromID  
                       AND   TD.Status <> '9')  
            BEGIN  
               SET @nErrNo = 151303  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID in transit  
               GOTO Quit  
            END  
         END  
      END  
   END  

Quit:

END

GO