SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: [rdt_513ExtValVLT]                                   */
/* Copyright: Maersk                                                     */
/*                                                                       */
/*                                                                       */
/* Date         Rev   Author   Purposes                                  */
/* 21/03/2024   1.0   PPA374   Check that LPN will NOT breach max pallet */
/* 15/07/2024   1.1   PPA374   Check pick, PA AND replen                 */
/* 18/10/2024   1.2   PPA374   Adding checks for shelf AND cons          */
/* 28/10/2024   1.3.0 WSE016   UWP-26437                                 */
/*************************************************************************/

CREATE   PROC [RDT].[rdt_513ExtValVLT] (
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR(  5),
   @cFromLOC   NVARCHAR( 10),
   @cFromID    NVARCHAR( 18),
   @cSKU       NVARCHAR( 20),
   @nQTY       INT,
   @cToID      NVARCHAR( 18),
   @cToLOC     NVARCHAR( 10),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @LOCAvail  INT,
      @LOCCat    NVARCHAR(40),
      @LOCFlag   NVARCHAR(20),
      @LoseIDChk INT,
      @SKUChk    INT,
      @TOZONE    NVARCHAR(20),
      @LOCType   NVARCHAR(20)

   IF @nFunc = 513
   BEGIN
      IF @nStep = 2
      BEGIN
         --LPN is IN multiple locations, should fix before moving.
         IF EXISTS (SELECT 1 FROM dbo.LOTXLOCXID LLI WITH(NOLOCK) WHERE id = @cFromID AND qty > 0 AND StorerKey = @cStorerKey AND id <> ''
         AND EXISTS (SELECT 1 FROM dbo.LOTXLOCXID WITH(NOLOCK) WHERE id = @cFromID AND qty > 0 AND loc <> lli.loc AND StorerKey = @cStorerKey))
         BEGIN
            SET @nErrNo = 217981
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN is IN multiple locations, should fix before moving.
         END

         --LPN got putaway task. Should NOT be moved.
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTXLOCXID WITH(NOLOCK) WHERE ID = @cFromID AND PendingMoveIN > 0 AND StorerKey = @cStorerKey AND ID <> '') AND 
            EXISTS (SELECT 1 FROM dbo.loc WITH(NOLOCK) WHERE loc = @cFromLOC AND FACILITY = @cFacility 
                     AND (EXISTS(SELECT 1 FROM dbo.CODELKUP (NOLOCK) 
                     WHERE LISTNAME = 'HUSQINBLOC' AND Storerkey = @cStorerKey AND LocationType = Code) OR LocationCategory = 'PND'))
         BEGIN
            SET @nErrNo = 217982 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN got putaway task. Should NOT be moved.
         END

         --LPN got replen task. Should NOT be moved.
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTXLOCXID WITH(NOLOCK) WHERE ID = @cFromID AND QtyReplen > 0 AND StorerKey = @cStorerKey AND ID <> '')
         BEGIN
            SET @nErrNo = 217983
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN got replen task. Should NOT be moved.
         END

         -- WS 28102024 - not allow to pick ID from TrolleyQC via Move by ID
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE loc = @cFromLOC and FACILITY = @cFacility 
            AND LocationType in ('TROLLEYIB','TROLLEYOB','TROLLEYQC'))
         BEGIN
            SET @nErrNo = 218043
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not allow to move ID from Trolley and TrolleyQC locs
         END
      END

     IF @nStep = 3
     BEGIN
        --Consumables should NOT be moved
        IF EXISTS (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = @cSKU AND Style = 'CON')
        BEGIN
            SET @nErrNo = 218014
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Consumable SKU LPN'
        END
     END

      IF @nStep = 5 
      BEGIN
         --Format or length of the target LPN is incorrect.
         IF ISNULL(@cToID,'')<>'' AND (len(replace(rtrim(ltrim(ISNULL(@cToID,''))),' ',''))<>10 OR CHARINDEX(' ',@cToId)>0)
         BEGIN   
            SET @nErrNo = 217901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --BadFormat/Len
         END
      END

      ELSE IF @nStep = 6
      BEGIN
        SELECT top 1 @LOCType = locationtype FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility
      
         SELECT @LOCAvail = coalesce((SELECT TOP 1 MaxPallet FROM dbo.LOC WITH(NOLOCK) WHERE loc = @cToLoc AND facility = @cFacility)
         -
         (SELECT COUNT(DISTINCT id) FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE storerkey = @cstorerkey AND loc = @cToLoc AND qty+PendingMoveIN> 0),0)

         SELECT TOP 1 @LOCCat = locationcategory FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility
         SELECT TOP 1 @LOCFlag = LocationFlag FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility
         SELECT TOP 1 @LoseIDChk = loseid FROM dbo.LOC WITH (NOLOCK) WHERE loc = @cToLOC AND Facility = @cFacility

         SET @SKUChk = CASE WHEN EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE @cSKu = sku AND StorerKey = @cStorerKey AND loc = @cToLOC AND (qty > 0 OR PendingMoveIN > 0)) THEN 1 ELSE 0 END
         SET @TOZONE = CASE WHEN EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE @cToLOC = loc AND Facility = @cFacility AND EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE PutawayZone = code AND LISTNAME = 'HUSQZONE' AND Storerkey = @cStorerKey AND short = 1)) THEN 1 ELSE 0 END

        --Target location is NOT IN the Husqvarna listed zone
         IF @TOZONE = 0
         BEGIN
            SET @nErrNo = 217902 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotAssign
         END

        --Maximum capacity is reached or target location is a pick location that got different SKU IN it.
         ELSE IF (@LOCAvail < 1 OR @LOCAvail IS NULL) 
            AND ((@LoseIDChk = 1 AND @SKUChk = 0) OR (@LoseIDChk = 0))
            AND NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE @cToID = id AND loc = @cToLOC AND (qty > 0 OR PendingMoveIN > 0) AND sku = @cSKU AND StorerKey = @cStorerKey)
            AND EXISTS (SELECT 1 FROM dbo.codelkup WITH (NOLOCK) WHERE @LOCCat = code AND listname = 'MAXPALCHK' AND storerkey = @cStorerKey AND short = 1)
         BEGIN
            SET @nErrNo = 217903 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --OverMaxPallet
         END

        --Target location got flag or is on hold.
         ELSE IF ISNULL(@LOCFlag,'') NOT IN ('','NONE') OR EXISTS (SELECT 1 FROM dbo.INVENTORYHOLD WITH (NOLOCK) WHERE @cToLOC = loc AND  hold = 1 AND loc <>'' AND Storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 217904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --LocOnHold
         END

        --If target location is NOT pick location then LPN ID is required.
         ELSE IF ISNULL(@cToID,'') = '' AND @LoseIDChk = 0 
         BEGIN
            SET @nErrNo = 217905
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedID
         END

        --If target LPN ID is same as the source AND location is different AND LPN ID is NOT blank AND target location is NOT pick location (with lose id)
        --or SKU is different than IN target location AND NOT full qty of the SKU is moved then it is a duplicate.
         ELSE IF EXISTS
            (SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE id = @cToID AND (qty > 0 OR PendingMoveIN > 0) AND id <> '' AND StorerKey = @cStorerKey 
            AND ((loc <> @cToLoc AND NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE @cToLoc = loc AND Facility = @cFacility AND LoseId = 1 AND LocationType IN ('PICK','CASE'))) 
            OR sku <> @cSKU) AND (SELECT SUM(qty) FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE ID = @cToID AND SKU = @cSKU AND StorerKey = @cStorerKey) <> @nQTY)
         BEGIN
            SET @nErrNo = 217906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateID
         END
            
         --If target LPN ID is NOT blank AND target location is NOT pick face AND lot on the target LPN of the SKU that is moved is different, than move
         --is NOT allowed to avoid creating LPNs with multiple lots on it.
         ELSE IF EXISTS
         (SELECT 1 FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE id = @cToID AND (qty > 0 OR PendingMoveIN > 0) AND id <> '' AND StorerKey = @cStorerKey 
         AND ((loc <> @cToLoc AND NOT EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE @cToLoc = loc AND Facility = @cFacility AND LocationType IN ('PICK','CASE'))) 
         OR sku <> @cSKU OR (NOT EXISTS (SELECT lot FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE 
         (SELECT TOP 1 lot FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE id = @cFromID AND qty > 0 AND loc = @cFromLOC AND StorerKey = @cStorerKey) = lot AND
         StorerKey = @cStorerKey AND id = @cToID AND qty > 0)
            AND (SELECT count(distinct lot) FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND loc = @cFromLOC) > 1
            AND NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE @cToLoc = loc AND Facility = @cFacility AND LoseId = 1 AND LocationType IN ('PICK','CASE')))
            )AND (SELECT SUM(qty) FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE ID = @cToID AND SKU = @cSKU AND StorerKey = @cStorerKey) <> @nQTY)
         BEGIN
            SET @nErrNo = 217907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DifferentLot
         END

         --Not allowing to move to target location if location is NOT commingle AND SKU count would become more than one.
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE (qty > 0 OR PendingMoveIN > 0) AND loc = @cToLoc AND @cSKU <> Sku AND StorerKey = @cStorerKey
            AND NOT EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE lotxlocxid.loc = loc AND CommingleSku = 1 AND Facility = @cFacility))
         BEGIN
            SET @nErrNo = 217908
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OtherSKULOC
         END

         ELSE IF NOT EXISTS (SELECT loc FROM dbo.SKUxLOC WITH(NOLOCK) WHERE QtyLocationLimit > 0 AND sku = @cSKU AND loc = @cToLOC AND StorerKey = @cStorerKey)
            AND @LOCType IN ('PICK','CASE') AND (SELECT TOP 1 Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'MVTOPFHUSQ' AND code = '513MV') = 0
         BEGIN
            SET @nErrNo = 217984
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Target location is a pick location with no SKU or different SKU setup than on the LPN.
         END

         --Shelf SKU should NOT be moved to non-shelf storage location
         ELSE IF EXISTS  
         (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = @cSKU AND Style = 'SHLV') AND EXISTS (Select 1 FROM dbo.LOC L WITH(NOLOCK) WHERE L.Loc = @cToLOC 
         AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE code = PutawayZone AND LISTNAME IN ('PICZONHUSQ','VNAZONHUSQ','WAZONEHUSQ')))
         BEGIN
            SET @nErrNo = 218016
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Not SHLV storage loc'
         END

         --Shelf SKU should NOT be moved to a shelf location NOT assigned to that SKU
         ELSE IF EXISTS (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = @cSKU AND Style = 'SHLV') AND EXISTS (Select 1 FROM dbo.LOC L WITH(NOLOCK) WHERE L.Loc = @cToLOC 
         AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE code = PutawayZone AND LISTNAME = ('SHLZONHUSQ'))) AND NOT EXISTS(SELECT 1 FROM dbo.SKUxLOC sl WITH(NOLOCK)
         WHERE sl.sku = @cSKU AND sl.Loc = @cToLOC AND sl.LocationType = 'PICK')
         BEGIN
            SET @nErrNo = 218017
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'SKU NOT set for loc'
         END

         --Non-shelf SKU should NOT be moved to shelf location
         ELSE IF EXISTS (SELECT 1 FROM dbo.SKU S WITH(NOLOCK) WHERE s.Sku = @cSKU AND Style <> 'SHLV') AND EXISTS (Select 1 FROM dbo.LOC L WITH(NOLOCK) WHERE L.Loc = @cToLOC 
         AND EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE code = PutawayZone AND LISTNAME = ('SHLZONHUSQ')))
         BEGIN
            SET @nErrNo = 218018
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'SKU NOT shelf type'
         END

         --Consumable location
         ELSE IF EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE facility = @cFacility AND loc = @cToLOC AND LocationType = 'CONS')
         BEGIN
            SET @nErrNo = 218015
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Loc is for Cons SKUs'
         END

        --Trolley Location
         ELSE IF EXISTS (SELECT 1 FROM loc (NOLOCK) WHERE facility = @cFacility AND loc = @cToLOC AND LocationType in ('TROLLEYIB','TROLLEYOB','TROLLEYQC'))
         BEGIN
            SET @nErrNo = 218041
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Loc is trolley'
         END
      END
   END
END

GO