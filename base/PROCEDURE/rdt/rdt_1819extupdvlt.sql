SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/***********************************************************************/
/* Store procedure: [rdt_1819ExtUpdVLT]                                */
/* Copyright: Maersk                                                   */
/*                                                                     */
/*                                                                     */
/* Date         Author   Purpose                                       */
/* 21/03/2024   PPA374   To check that alternative location is valid   */
/* 08/08/2024   PPA374   Amended as per review comments                */
/***********************************************************************/

CREATE       PROC [RDT].[rdt_1819ExtUpdVLT] (
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

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE 
@cFacility      NVARCHAR(20),
@cFromLOC       NVARCHAR(20),
@CurrentLocType NVARCHAR(20),
@cStorerkey     NVARCHAR(20),
@SKU            NVARCHAR(20),
@Style          NVARCHAR(10),
@ABC            NVARCHAR(3),
@Class          NVARCHAR(10)

IF @nStep = 2 and (@nInputKey = 0 or @cToLOC = @cSuggLOC) 
BEGIN   
   select top 1 @cFacility = Facility from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @cStorerkey = Storerkey from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @cFromLOC = V_LOC from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @CurrentLocType = LocationType from LOC (NOLOCK) where loc = @cFromLOC and Facility = @cFacility


   IF @CurrentLocType <> 'PnD'
   BEGIN
      update LOTxLOCxID 
      set PendingMoveIN = 0
      where ID = @cFromID and PendingMoveIN > 0 and ID <> '' and StorerKey = @cStorerkey
   END
END

IF @nStep = 99 and @nInputKey = 1
BEGIN
	declare @nScn int

	select @nScn = Scn From rdt.RDTMOBREC with(nolock) where Mobile = @nMobile

	IF @nScn = 4115
	BEGIN

		DECLARE @jackmsg nvarchar(4000)
		SET @JACKMSG = CONCAT_WS(',', '1819ExtScn02Call', '')
		INSERT INTO dbo.DocInfo
	   (TableName, Key1, Key2, Key3, StorerKey, LineSeq, Data, DataType, StoredProc, ArchiveCop)
		VALUES
	   ('JCH507', @nMobile, @nFunc, '', @cStorerKey, 0, @JACKMSG, '', '', NULL)
	   GOTO QUIT
	END
	/*
   DECLARE 
   @cUserName NVARCHAR(20),
   @NewLocType NVARCHAR(20)

   select top 1 @cFacility = Facility from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @cStorerkey = Storerkey from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @cUserName = UserName from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @cFromLOC = V_LOC from rdt.rdtmobrec (NOLOCK) where Mobile = @nMobile
   select top 1 @CurrentLocType = LocationType from LOC (NOLOCK) where loc = @cFromLOC
   select top 1 @NewLocType = LocationType from LOC (NOLOCK) where loc = @cToLOC
   select top 1 @SKU = SKU from LOTxLOCxID (NOLOCK) where qty > 0 and StorerKey = @cStorerkey and ID = @cFromID and Loc = @cToLOC
   select top 1 @Style = Style, @ABC = ABC, @Class = CLASS from SKU (NOLOCK) where Sku = @SKU and StorerKey = @cStorerkey
   
   --Establish LPN type
   DECLARE @LPNPATYPE           NVARCHAR(20)
   DECLARE @AvailableLocList as TABLE (AvailableLocList NVARCHAR(20))

   --Battery
   IF @Style = 'B'
   BEGIN
      set @LPNPAType = 'Battery' 
   END

   --VelocityA
   ELSE IF @ABC = 'A'
   BEGIN
      set @LPNPAType = 'VelocityA' 
   END

   --VelocityB
   ELSE IF @ABC = 'B'
   BEGIN
      set @LPNPAType = 'VelocityB' 
   END

   --VelocityC
   ELSE IF @ABC = 'C'
   BEGIN
      set @LPNPAType = 'VelocityC' 
   END
	
   --VelocityE
   ELSE IF @ABC = 'E'
   BEGIN
      set @LPNPAType = 'VelocityE' 
   END
	
   ELSE	--Error if LPN type could not be established
   BEGIN
      SET @nErrNo = 218001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Unknown PA LPN type'
      GOTO Quit
   END

   --FLYMO check
   DECLARE @Flymo int
   set @Flymo = 0

   IF @Class = 'FLY'
   BEGIN
      set @Flymo = 1
   END

   IF not exists (select 1 from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'VNA' and Storerkey = @cStorerKey)
   BEGIN
      goto SkipVNA
   END
   
   --Creating the list of available PnD Aisles
   DECLARE @AvailablePnDAisle as TABLE (AvailablePnDAisle NVARCHAR(20))

   insert into @AvailablePnDAisle
   select LocAisle from
   (select MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey and id <> @cFromID) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
   L.Loc, LocationType, LocationFlag, LocationCategory, L.Cube, WeightCapacity, Status, PutawayZone, LocAisle,
   isnull(TotalWeight,0)TotalWeight, isnull(TotalCube,0)TotalCube, --This is from T1 table which calculate how much weight and cube is in the location based on SKU qty.
   IDWeight, IDCube
   from LOC L (NOLOCK)

   left join
   (
   select sum((lli.qty+PendingMoveIN) * STDGROSSWGT) TotalWeight, sum((lli.qty+PendingMoveIN) * (WidthUOM3 * LengthUOM3 * HeightUOM3)) TotalCube, --Fnding how much weight and cube is in the location based on SKU qty.
   Loc

   from LOTxLOCxID LLI (NOLOCK)
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where (lli.qty+PendingMoveIN)> 0
   and LLI.StorerKey = @cStorerKey
   group by loc
   )T1
   ON L.Loc = T1.Loc

   cross join
   (select isnull(sum(lli.qty * STDGROSSWGT),0) IDWeight, isnull(sum(lli.qty * (WidthUOM3 * LengthUOM3 * HeightUOM3)),0) IDCube from lotxlocxid LLI(NOLOCK) 
   join SKU S (NOLOCK)	on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cFromID and loc = @cToLOC)T2

   where facility = @cFacility
   and PutawayZone in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNAZONHUSQ' and storerkey = @cStorerKey)
   and LocationCategory = 'PND'
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T1

   where MaxPallet - SpaceTaken > 0 and 
   case when 
   (1 not in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQCHKPND' and storerkey = @cStorerKey) 
   or 0 in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQCHKPND' and storerkey = @cStorerKey))
   then 1 
   when Cube - TotalCube - IDCube >= 0 and WeightCapacity - TotalWeight - IDWeight >= 0 then 1 else 0
   end = 1

   --Creating list of available VNA locations
   DECLARE @AvailableLocVNA as TABLE
   (AvailableLocVNA NVARCHAR(20),
   LocAisle NVARCHAR(20),
   LocType NVARCHAR(20),
   PALogicalLoc NVARCHAR(20))

   insert into @AvailableLocVNA
   select Loc, LocAisle, 'VNA', PALogicalLoc From
   (select substring(L.Loc,6,1) LocLevel, MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey and id <> @cFromID) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
   L.Loc, LocationType, LocationFlag, LocationCategory, L.Cube, WeightCapacity, Status, PutawayZone, LocAisle,
   isnull(TotalWeight,0)TotalWeight, isnull(TotalCube,0)TotalCube, --This is from T1 table which calculate how much weight and cube is in the location based on SKU qty.
   IDWeight, IDCube, PALogicalLoc
   from LOC L (NOLOCK)

   left join
   (
   select sum((lli.qty+PendingMoveIN) * STDGROSSWGT) TotalWeight, sum((lli.qty+PendingMoveIN) * (WidthUOM3 * LengthUOM3 * HeightUOM3)) TotalCube, --Fnding how much weight and cube is in the location based on SKU qty.
   Loc

   from LOTxLOCxID LLI (NOLOCK)
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where (lli.qty+PendingMoveIN)> 0
   and LLI.StorerKey = @cStorerKey
   group by loc
   )T1
   ON L.Loc = T1.Loc

   cross join
   (select isnull(sum(lli.qty * STDGROSSWGT),0) IDWeight, isnull(sum(lli.qty * (WidthUOM3 * LengthUOM3 * HeightUOM3)),0) IDCube from lotxlocxid LLI(NOLOCK) 
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cFromID and loc = @cToLOC)T2

   where facility = @cFacility
   and (PutawayZone in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNAZONHUSQ' and storerkey = @cStorerKey))
   and (LocationCategory in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNACATHUSQ' and storerkey = @cStorerKey))
   and (LocationType in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNATYPHUSQ' and storerkey = @cStorerKey))
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and LocAisle in (select AvailablePnDAisle from @AvailablePnDAisle)
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T3

   where MaxPallet - SpaceTaken > 0 and Cube - TotalCube - IDCube > 0 and WeightCapacity - TotalWeight - IDWeight > 0
	
   --Filter by product type
   and ((@Flymo = 1 and LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = 'Flymo' and short = 'VNA' and Storerkey = @cStorerKey))or @Flymo <> 1)
   and ((LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'VNA' and Storerkey = @cStorerKey)))

   --Creating the list of available PnD Locations
   DECLARE @AvailableLocPnD as TABLE
   (AvailableLocPnD NVARCHAR(20),
   LocAisle NVARCHAR(20),
   LocType NVARCHAR(20))
	
   insert into @AvailableLocPnD
   select Loc, LocAisle, 'PnD' from
   (select MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey and id <> @cFromID) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
   L.Loc, LocationType, LocationFlag, LocationCategory, L.Cube, WeightCapacity, Status, PutawayZone, LocAisle,
   isnull(TotalWeight,0)TotalWeight, isnull(TotalCube,0)TotalCube, --This is from T1 table which calculate how much weight and cube is in the location based on SKU qty.
   IDWeight, IDCube
   from LOC L (NOLOCK)

   left join
   (
   select sum((lli.qty+PendingMoveIN) * STDGROSSWGT) TotalWeight, sum((lli.qty+PendingMoveIN) * (WidthUOM3 * LengthUOM3 * HeightUOM3)) TotalCube, --Fnding how much weight and cube is in the location based on SKU qty.
   Loc

   from LOTxLOCxID LLI (NOLOCK)
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where (lli.qty+PendingMoveIN)> 0
   and LLI.StorerKey = @cStorerKey
   group by loc
   )T1
   ON L.Loc = T1.Loc

   cross join
   (select isnull(sum(lli.qty * STDGROSSWGT),0) IDWeight, isnull(sum(lli.qty * (WidthUOM3 * LengthUOM3 * HeightUOM3)),0) IDCube from lotxlocxid LLI(NOLOCK) 
   join SKU S (NOLOCK)	on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cFromID and loc = @cToLOC)T2

   where facility = @cFacility
   and PutawayZone in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNAZONHUSQ' and storerkey = @cStorerKey)
   and LocationCategory = 'PND'
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T1

   where MaxPallet - SpaceTaken > 0 
   and LocAisle in (select LocAisle from @AvailableLocVNA)
   and case when 
   (1 not in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQCHKPND' and storerkey = @cStorerKey) 
   or 0 in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQCHKPND' and storerkey = @cStorerKey))
   then 1 
   when Cube - TotalCube - IDCube >= 0 and WeightCapacity - TotalWeight - IDWeight >= 0 then 1 else 0
   end = 1

   SkipVNA:
   --Creating list of available Wide Aisle locations
   DECLARE @AvailableLocWA as TABLE
   (AvailableLocWA NVARCHAR(20),
   LocAisle NVARCHAR(20),
   LocType NVARCHAR(20))

   IF not exists (select 1 from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'WA' and Storerkey = @cStorerKey)
   BEGIN
      goto SkipWA
   END
   
   Insert into @AvailableLocWA
   select Loc, LocAisle, 'WA' From
   (select substring(L.Loc,6,1) LocLevel, MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey and id <> @cFromID) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
   L.Loc, LocationType, LocationFlag, LocationCategory, L.Cube, WeightCapacity, Status, PutawayZone, LocAisle,
   isnull(TotalWeight,0)TotalWeight, isnull(TotalCube,0)TotalCube, --This is from T1 table which calculate how much weight and cube is in the location based on SKU qty.
   IDWeight, IDCube, PALogicalLoc
   from LOC L (NOLOCK)

   left join
   (
   select sum((lli.qty+PendingMoveIN) * STDGROSSWGT) TotalWeight, sum((lli.qty+PendingMoveIN) * (WidthUOM3 * LengthUOM3 * HeightUOM3)) TotalCube, --Fnding how much weight and cube is in the location based on SKU qty.
   Loc

   from LOTxLOCxID LLI (NOLOCK)
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where (lli.qty+PendingMoveIN)> 0
   and LLI.StorerKey = @cStorerKey
   group by loc
   )T1
   ON L.Loc = T1.Loc

   cross join
   (select isnull(sum(lli.qty * STDGROSSWGT),0) IDWeight, isnull(sum(lli.qty * (WidthUOM3 * LengthUOM3 * HeightUOM3)),0) IDCube from lotxlocxid LLI(NOLOCK) 
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cFromID and loc = @cToLOC)T2

   where facility = @cFacility
   and (PutawayZone in (select code from CODELKUP (NOLOCK) where LISTNAME = 'WAZONEHUSQ' and storerkey = @cStorerKey))
   and (LocationCategory in (select code from CODELKUP (NOLOCK) where LISTNAME = 'WACATHUSQ' and storerkey = @cStorerKey))
   and (LocationType in (select code from CODELKUP (NOLOCK) where LISTNAME = 'WATYPEHUSQ' and storerkey = @cStorerKey))
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T3

   where MaxPallet - SpaceTaken > 0 and Cube - TotalCube - IDCube > 0 and WeightCapacity - TotalWeight - IDWeight > 0

   --Filter by product type
   and ((@Flymo = 1 and LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = 'Flymo' and short = 'WA' and Storerkey = @cStorerKey))or @Flymo <> 1)
   and ((LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'WA' and Storerkey = @cStorerKey)))	

   SkipWA:
   insert into @AvailableLocList

   select AvailableLocPnD from
   (select AvailableLocPnD, 
   case when @CurrentLocType = 'PnD' and LocType = 'VNA' then 1 
   when @CurrentLocType <> 'PnD' and LocType <> 'VNA' then 1
   else 2 end LocType
   from
   (select AvailableLocPnD, LocAisle, LocType from @AvailableLocPnD 
   union all
   select AvailableLocVNA, LocAisle, LocType from @AvailableLocVNA
   union all
   select AvailableLocWA, LocAisle, LocType from @AvailableLocWA)T1)T2
   where LocType = 1

   IF @cToLOC not in (select AvailableLocList from @AvailableLocList)
   BEGIN
      SET @nErrNo = 218002
	  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Unsuitable location'
	  GOTO Quit
   END

   update LOTxLOCxID 
   set PendingMoveIN = 0
   where id = @cFromID and PendingMoveIN > 0 and storerkey = @cStorerKey and ID <> ''

   IF @NewLocType = 'PnD'
   BEGIN
      select top 1 @cSuggLOC = AvailableLocVNA from @AvailableLocVNA where LocAisle = 
      (select top 1 LocAisle from LOC (NOLOCK) where loc = @cToLOC and Facility = @cFacility)
      order by PALogicalLoc

      update lotxlocxid
      set PendingMoveIN = PendingMoveIN + (select sum(qty) from LOTxLOCxID LLI (NOLOCK) where LLI.lot = lotxlocxid.Lot and lli.Id = @cFromID and Loc = @cToLOC and lli.StorerKey = @cStorerKey and qty > 0)
      where id = @cFromID and loc = @cSuggLOC and StorerKey = @cStorerKey

   IF EXISTS
   (select 1 from lotxlocxid LLI1 (NOLOCK) 
   where id = @cFromID
   and loc = @cToLOC
   and StorerKey = @cStorerKey
   and not exists (select 1 from LOTxLOCxID LLI2 (NOLOCK) where StorerKey = @cStorerKey 
   and lli1.lot = lli2.Lot and lli1.Sku = lli2.Sku and lli1.Id = LLI2.id and loc = @cSuggLOC))

   BEGIN
      insert into lotxlocxid
      select Lot, @cSuggLOC, ID, StorerKey, Sku, 0, 0, 0, 0, 0, qty, 0, 0, null,null, 0, SUSER_NAME(), getdate() from lotxlocxid LLI1 (NOLOCK) 
      where id = @cFromID
	  and StorerKey = @cStorerKey
      and loc = @cToLOC
      and not exists (select 1 from LOTxLOCxID LLI2 (NOLOCK) where StorerKey = @cStorerKey 
	  and lli1.lot = lli2.Lot and lli1.Sku = lli2.Sku and lli1.Id = LLI2.id and loc = @cSuggLOC)
   END

   END-

   delete from RFPUTAWAY
   where id = @cFromID and StorerKey = @cStorerkey
   */

   GOTO Quit

Quit:

END



GO