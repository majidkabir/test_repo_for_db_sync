SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-03-04   Ung       1.0   SOS346283 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal01]
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

   DECLARE @cFacility NVARCHAR(5)

   -- Change ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 1 -- FromID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get Facility
            SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

            -- Check ID in transit
            IF EXISTS( SELECT 1 
               FROM TaskDetail TD WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (LOC.LOC = TD.FromLOC)
               WHERE LOC.Facility = @cFacility
                  AND TD.TaskType = 'PA1'
                  AND TD.FromID = @cFromID
                  AND TD.Status <> '9')
            BEGIN
               SET @nErrNo = 52801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID in transit
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO