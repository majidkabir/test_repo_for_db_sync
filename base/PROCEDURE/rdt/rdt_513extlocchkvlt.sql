SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_513ExtLocChkVLT]                               */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: NOT allow to put pallet into location if maxpallet  <> 0    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-03-21 1.0  PPA374     Loc Check                                 */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513ExtLocChkVLT] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF


   DECLARE
      @LOCAvail         INT,
      @LOCCat           NVARCHAR(40),
      @LOCFlag          NVARCHAR(20),
      @LoseIDChk        INT,
      @SKUChk           INT,
      @TOZONE           NVARCHAR(20)

   IF @nFunc = 513
   BEGIN
      IF @nStep = 5 
      BEGIN
         IF isnull(@cToID,'')<>'' AND (len(replace(rtrim(ltrim(isnull(@cToID,''))),' ',''))<>10 OR CHARINDEX(' ',@cToId)>0)
         BEGIN   
            SET @nErrNo = 217901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --InvalidLength
         END
      END
      ELSE IF @nStep = 6
      BEGIN
         SELECT @LOCAvail = coalesce((SELECT TOP 1 MaxPallet FROM LOC WITH (NOLOCK) WHERE loc = @cToLoc)
                           -
                           (SELECT count(distinct id) FROM LOTxLOCxID WITH (NOLOCK) WHERE loc = @cToLoc AND qty+PendingMoveIN> 0),0)

         SELECT TOP 1 @LOCCat = locationcategory FROM LOC WITH (NOLOCK) WHERE loc = @cToLOC
         SELECT TOP 1 @LOCFlag = LocationFlag FROM loc WITH (NOLOCK) WHERE loc = @cToLOC
         SELECT TOP 1 @LoseIDChk = loseid FROM loc WITH (nolock) WHERE loc = @cToLOC

         SET @SKUChk = CASE WHEN @cSKu IN (SELECT sku FROM LOTxLOCxID WITH (nolock) WHERE loc = @cToLOC AND (qty > 0 OR PendingMoveIN > 0)) THEN 1 ELSE 0 END
         SET @TOZONE = CASE WHEN @cToLOC IN (SELECT loc FROM loc WITH (NOLOCK) WHERE PutawayZone IN (SELECT code FROM CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'HUSQZONE' AND Storerkey = 'HUSQ' AND short = 1)) THEN 1 ELSE 0 END

         IF @TOZONE = 0
         BEGIN
            SET @nErrNo = 217902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotAssign
         END
         ELSE IF (@LOCAvail < 1 OR @LOCAvail is null) 
            AND ((@LoseIDChk = 1 AND @SKUChk = 0) OR (@LoseIDChk = 0))
            AND @cToID NOT IN (SELECT id FROM LOTxLOCxID WITH (nolock) WHERE loc = @cToLOC AND (qty > 0 OR PendingMoveIN > 0) AND sku = @cSKU)
            AND @LOCCat IN (SELECT Code FROM codelkup WITH (NOLOCK) WHERE listname = 'MAXPALCHK' AND storerkey = @cStorerKey AND short = 1)
         BEGIN
            SET @nErrNo = 217903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --OverMaxPallet
         END

         ELSE IF isnull(@LOCFlag,'') NOT IN ('','NONE') OR @cToLOC IN (SELECT loc FROM INVENTORYHOLD WITH (NOLOCK) WHERE hold = 1 AND loc <>'')
         BEGIN
            SET @nErrNo = 217904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --LocOnHold
         END

         ELSE IF isnull(@cToID,'') = '' AND @LoseIDChk = 0 
         BEGIN
            SET @nErrNo = 217905
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedID
         END

         ELSE IF EXISTS
         (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE id = @cToID AND (qty > 0 OR PendingMoveIN > 0) AND id <> '' 
         AND ((loc <> @cToLoc AND @cToLoc NOT IN (SELECT loc FROM loc  WITH (NOLOCK) WHERE LocationType IN ('PICK','CASE'))) 
         OR sku <> @cSKU)AND (SELECT sum(qty) FROM LOTxLOCxID WITH (NOLOCK) WHERE ID = @cToID AND SKU = @cSKU ) <> @nQTY)
         BEGIN
            SET @nErrNo = 217906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateID
         END
         ELSE IF EXISTS
            (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE id = @cToID AND (qty > 0 OR PendingMoveIN > 0) AND id <> '' 
            AND ((loc <> @cToLoc AND @cToLoc NOT IN (SELECT loc FROM loc  WITH (NOLOCK) WHERE LocationType IN ('PICK','CASE'))) 
            OR sku <> @cSKU OR ((SELECT TOP 1 lot FROM lotxlocxid (NOLOCK) WHERE id = @cFromID AND qty > 0 AND loc = @cFromLOC) 
            NOT IN (SELECT lot FROM LOTxLOCxID (NOLOCK) WHERE id = @cToID AND qty > 0)
            AND (SELECT count(distinct lot) FROM lotxlocxid (NOLOCK) WHERE loc = @cFromLOC) > 1
            AND @cToLoc NOT IN (SELECT loc FROM loc  WITH (NOLOCK) WHERE LocationType IN ('PICK','CASE')))
            )AND (SELECT sum(qty) FROM LOTxLOCxID WITH (NOLOCK) WHERE ID = @cToID AND SKU = @cSKU ) <> @nQTY)
         BEGIN
            SET @nErrNo = 217907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DifferentLot
         END
         ELSE IF EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE (qty > 0 OR PendingMoveIN > 0) AND loc = @cToLoc AND @cSKU <> Sku AND loc NOT IN (SELECT loc FROM loc WITH (NOLOCK) WHERE CommingleSku = 1))
         BEGIN
            SET @nErrNo = 217908
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OtherSKULOC
         END
      END
   END
END

GO