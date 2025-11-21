SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_1819ExtValVLT]                                 */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: not allow to put pallet into location if maxpallet  <> 0    */
/*                                                                      */
/* Date       Rev  Author			                                    */
/* 2024-03-21 1.0  PPA374			                                    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtValVLT] (
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
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nStep = 1 and @nInputKey = 1
   BEGIN
      DECLARE
      @FromLOC NVARCHAR(20),
      @cFacility NVARCHAR(20),
      @cStorerKey NVARCHAR(20)

      select top 1 @cStorerKey = StorerKey from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
      select top 1 @cFacility = Facility from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
      select top 1 @FromLOC = LOC from LOTxLOCxID (NOLOCK) where id = @cFromID and qty > 0 and StorerKey = @cStorerKey

      BEGIN
      --If LPN is in more than one location, error is given, as it needs to be fixed first.
         IF exists
         (select 1 from LOTXLOCXID LLI (NOLOCK) where id = @cFromID and qty > 0 and StorerKey = @cStorerKey
         and exists (select 1 from LOTXLOCXID (NOLOCK) where id = @cFromID and qty > 0 and loc <> lli.loc and StorerKey = @cStorerKey))
         
         BEGIN
            SET @nErrNo = 217985
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN is in multi locs
         END
         
         --If source location is not PND and is not listed in the inbound location code lookup, then error is given.
         ELSE IF NOT EXISTS (SELECT 1 FROM loc (NOLOCK) WHERE loc = @FromLOC and FACILITY = @cFacility AND (LocationType IN (SELECT code FROM CODELKUP (NOLOCK) 
         WHERE LISTNAME = 'HUSQINBLOC' AND Storerkey = @cStorerKey) or LocationCategory = 'PND'))
      BEGIN
         SET @nErrNo = 217986
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LPN not in a PA loc
         END
      END
   END
END

GO