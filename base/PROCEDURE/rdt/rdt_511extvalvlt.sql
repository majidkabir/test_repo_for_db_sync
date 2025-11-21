SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Store procedure: [rdt_511ExtValVLT]                                    */
/* Copyright: Maersk                                                      */
/*                                                                        */
/* Purpose: not allow to put pallet into location if maxpallet  <> 0      */
/*                                                                        */
/* Date         VER     Author   Purpose:                                 */
/* 21/03/2024   1.0     PPA374   Not allow to put LPN over max            */
/* 15/07/2024   1.1     PPA374   Adding pick check AND PA, Replen check   */
/* 18/10/2024   1.2     PPA374   Formatted, messages created              */
/* 28/10/2024   1.3.0   WSE016   UWP-26437 Exclude moves to TrolleyQC loc */
/**************************************************************************/

CREATE   PROC [RDT].[rdt_511ExtValVLT] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFromID         NVARCHAR( 18),
   @cFromLOC        NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cToID           NVARCHAR( 18),
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS

BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @LOCAvail      INT,
      @LOCCat        NVARCHAR(40),
      @LOCFlag       NVARCHAR(20),
      @LoseIDChk     INT,
      @SKUChk        INT,
      @SKUPickChk    INT,
      @TOZONE        NVARCHAR(20),
      @PNDPICKChk    INT,
      @cFacility     NVARCHAR(20),
      @FromLoc       NVARCHAR(20),
      @LOCType       NVARCHAR(20)
   
   SELECT TOP 1 @cFacility = Facility FROM rdt.rdtmobrec WITH(NOLOCK) WHERE Mobile = @nMobile
   SELECT TOP 1 @FromLoc = LOC FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE qty > 0 AND StorerKey = @cStorerKey AND id = @cFromID

   IF @nFunc = 511
   BEGIN
      IF @nStep = 1
      BEGIN
         --LPN is in multiple locations, should fix before moving.
         IF EXISTS (SELECT 1 FROM dbo.LOTXLOCXID LLI WITH(NOLOCK) WHERE id = @cFromID AND qty > 0 AND StorerKey = @cStorerKey
         AND EXISTS (SELECT 1 FROM dbo.LOTXLOCXID WITH(NOLOCK) WHERE id = @cFromID AND qty > 0 AND loc <> lli.loc AND StorerKey = @cStorerKey))
         BEGIN
            SET @nErrNo = 217973 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN is in multiple locations, should fix before moving
         END
   
         --LPN got putaway task. Should not be moved.
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTXLOCXID WITH(NOLOCK) WHERE ID = @cFromID AND PendingMoveIN > 0 AND StorerKey = @cStorerKey) AND 
            EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE loc = @FromLOC AND FACILITY = @cFacility AND (EXISTS (SELECT code FROM CODELKUP (NOLOCK) 
            WHERE LocationType = code AND LISTNAME = 'HUSQINBLOC' AND Storerkey = @cStorerKey) or LocationCategory = 'PND'))
         BEGIN
            SET @nErrNo = 217974 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN got putaway task. Should not be moved.
         END
   
         -- WS 28102024 - not allow to pick ID from TrolleyQC via Move by ID
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE loc = @FromLOC AND FACILITY = @cFacility 
         AND LocationType in ('TROLLEYIB','TROLLEYOB','TROLLEYQC'))
         BEGIN
            SET @nErrNo = 218042
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not allow to move ID from Trolley and TrolleyQC locs
         END

         --LPN got replen task. Should not be moved.
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTXLOCXID WITH(NOLOCK) WHERE ID = @cFromID AND QtyReplen > 0 AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 217975
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN got replen task. Should not be moved.
         END

        --Consumables should not be moved
        ELSE IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI WITH(NOLOCK) WHERE qty > 0 AND StorerKey = @cStorerKey AND id = @cFromID AND id <> '' AND EXISTS 
        (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = LLI.sku AND Style = 'CON'))
         BEGIN
            SET @nErrNo = 218012
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Consumable SKU LPN'
         END
      END

      IF @nStep = 3
      BEGIN
         SELECT @LOCAvail = coalesce((SELECT TOP 1 MaxPallet FROM dbo.LOC WITH(NOLOCK) WHERE loc = @cToLoc AND facility = @cfacility)
         -
         (SELECT COUNT(DISTINCT id) FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE storerkey = @cStorerkey AND loc = @cToLoc AND qty+PendingMoveIN> 0),0)

         SELECT TOP 1 @LOCCat = locationcategory FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility
         SELECT TOP 1 @LOCType = locationtype FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility
         SELECT TOP 1 @LOCFlag = LocationFlag FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility
         SELECT TOP 1 @LoseIDChk = loseid FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility

         SET @SKUChk = CASE WHEN EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE id = @cFromID AND qty > 0 AND loc = @cFromLOC AND StorerKey = @cStorerKey AND sku = any (SELECT sku FROM LOTxLOCxID WITH (NOLOCK) WHERE (qty > 0 or PendingMoveIN > 0) AND StorerKey = @cStorerKey AND loc = @cToLOC)) THEN 1 ELSE 0 END
         SET @TOZONE = CASE WHEN EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility AND EXISTS (SELECT code FROM CODELKUP WITH (NOLOCK) WHERE PutawayZone = code AND LISTNAME = 'HUSQZONE' AND Storerkey = @cStorerKey AND short = 1)) THEN 1 ELSE 0 END
         SET @PNDPICKChk = CASE WHEN --(SELECT TOP 1 LocationType FROM loc (NOLOCK) WHERE loc = @cFromLoc AND Facility = @cFacility AND loc like 'B_999%') = 'PND' AND 
              EXISTS(SELECT 1 FROM pickdetail WITH(NOLOCK) WHERE id = @cFromID AND status = 5 AND dropid <> '' AND Storerkey = @cStorerKey)  THEN 1 ELSE 0 END
         SET @SKUPickChk = CASE WHEN EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND id = @cFromID AND qty > 0 AND loc = @cFromLOC AND sku = any (SELECT sku FROM SKUxLOC WITH (NOLOCK) WHERE loc = @cToLOC AND QtyLocationLimit > 0 AND StorerKey = @cStorerKey)) THEN 1 ELSE 0 END

         --Target location is not in the Husqvarna listed zone
         IF @TOZONE = 0
         BEGIN
            SET @nErrNo = 217976
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Target location is not in the Husqvarna listed zone
         END

         --Maximum capacity is reached or target location is a pick location that got different SKU in it.
         ELSE IF (@LOCAvail < 1 or @LOCAvail is null)
            AND ((@LoseIDChk = 1 AND @SKUChk = 0) or (@LoseIDChk = 0))
            AND EXISTS (SELECT 1 FROM dbo.codelkup WITH(NOLOCK) WHERE @LOCCat = code AND listname = 'MAXPALCHK' AND storerkey = @cStorerKey AND short = 1)
         BEGIN
            SET @nErrNo = 217977 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Maximum capacity is reached or target location is a pick location that got different SKU in it.
         END

         --Target location got flag or is on hold.
         ELSE IF ISNULL(@LOCFlag,'') NOT IN ('','NONE') 
            OR EXISTS (SELECT 1 FROM dbo.INVENTORYHOLD WITH(NOLOCK) WHERE hold = 1 AND loc=@cToLOC AND Storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 217978
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Target location got flag enabled or is on hold.
         END

        --LPN is picked AND needs to be moved to the marshalling lane.
         ELSE IF @PNDPICKChk = 1 
            AND NOT EXISTS (SELECT 1 FROM dbo.LOC L WITH(NOLOCK) WHERE loc = @cToLOC 
            AND EXISTS (SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'VASZONHUSQ' AND L.PutawayZone = Code AND Storerkey = @cStorerKey))
            AND @cToLOC <> 
               (SELECT TOP 1 OtherReference FROM dbo.mbol WITH(NOLOCK) WHERE Facility = @cFacility 
                  AND mbolkey = (SELECT TOP 1 mbolkey FROM dbo.orders WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND orderkey = 
                  (SELECT TOP 1 OrderKey FROM dbo.pickdetail WITH(NOLOCK) WHERE Storerkey = @cStorerKey AND id = @cFromID)))
        BEGIN
            SET @nErrNo = 217979
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN is picked AND needs to be moved to the marshalling lane.
        END

         --Target location is a pick location WITH no SKU setup or a different SKU setup than the SKU on the LPN.
         ELSE IF @LOCType in ('PICK','CASE') AND @SKUPickChk = 0 
            AND (SELECT TOP 1 short FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'MVTOPFHUSQ' AND code = '511MV' AND Storerkey = @cStorerKey) = 0
         BEGIN
            SET @nErrNo = 217980
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Target location is a pick location WITH no SKU or different SKU setup than on the LPN.
         END

        --Shelf SKU should not be moved to non-shelf storage location
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI WITH(NOLOCK) WHERE qty > 0 AND StorerKey = @cStorerKey AND id = @cFromID AND id <> '' AND EXISTS 
            (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = LLI.sku AND Style = 'SHLV' AND StorerKey = @cStorerKey) 
            AND EXISTS (Select 1 FROM dbo.LOC L WITH(NOLOCK) WHERE Facility = @cFacility AND L.Loc = @cToLOC 
            AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE Storerkey = @cStorerKey AND code = PutawayZone AND LISTNAME in ('PICZONHUSQ','VNAZONHUSQ','WAZONEHUSQ'))))
         BEGIN
            SET @nErrNo = 218009
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Not SHLV storage loc'
          END

         --Shelf SKU should not be moved to a shelf location not assigned to that SKU
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI WITH(NOLOCK) WHERE qty > 0 AND StorerKey = @cStorerKey AND id = @cFromID AND id <> '' 
            AND EXISTS (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = LLI.sku AND Style = 'SHLV' AND StorerKey = @cStorerKey) 
            AND EXISTS (Select 1 FROM dbo.LOC L WITH(NOLOCK) WHERE Facility = @cFacility AND L.Loc = @cToLOC 
            AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE code = PutawayZone AND Storerkey = @cStorerKey AND LISTNAME = ('SHLZONHUSQ'))) 
            AND NOT EXISTS(SELECT 1 FROM dbo.SKUxLOC sl WITH(NOLOCK) WHERE sl.sku = lli.Sku AND sl.Loc = @cToLOC AND sl.LocationType = 'PICK'))
         BEGIN
            SET @nErrNo = 218010
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'SKU not SET for loc'
         END

         --Non-shelf SKU should not be moved to shelf location
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI WITH(NOLOCK) WHERE qty > 0 AND StorerKey = @cStorerKey AND id = @cFromID AND id <> '' 
            AND EXISTS (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = LLI.sku AND Style <> 'SHLV' AND StorerKey = @cStorerKey) 
            AND EXISTS (Select 1 FROM dbo.LOC L WITH(NOLOCK) WHERE L.Loc = @cToLOC AND Facility = @cFacility
            AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE code = PutawayZone AND Storerkey = @cStorerKey AND LISTNAME = ('SHLZONHUSQ'))))
         BEGIN
            SET @nErrNo = 218011
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'SKU not shelf type'
          END

        --Consumable location
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE facility = @cFacility AND loc = @cToLOC AND LocationType = 'CONS')
         BEGIN
            SET @nErrNo = 218013
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Loc is for Cons SKUs'
         END
        
        --Trolley Location (WS 2810204 - added LocationType = TROLLEYQC )
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE facility = @cFacility AND loc = @cToLOC AND LocationType in ('TROLLEYIB','TROLLEYOB','TROLLEYQC'))
         BEGIN
            SET @nErrNo = 218040
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Loc is trolley'
         END
      END
   END
END

GO