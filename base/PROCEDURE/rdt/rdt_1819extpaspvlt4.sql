SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASPVLT4                                 */
/*                                                                      */
/* Date         Author   Purposes                                       */
/* 19/06/2024   PPA374   Identify location for putaway                  */
/* 08/08/2024   PPA374   Amended as per review comments                 */
/*                                                                      */
/*                                                                      */
/************************************************************************/

CREATE     PROC [RDT].[rdt_1819ExtPASPVLT4] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
   @nTranCount   INT,
   @SKU          NVARCHAR(20),
   @Style        NVARCHAR(10),
   @ABC          NVARCHAR(3),
   @Class        NVARCHAR(10),
   @cFromLOCType NVARCHAR(20),
   @cFromLocPAZ  NVARCHAR(20)

   select top 1 @SKU = SKU from LOTxLOCxID (NOLOCK) where qty > 0 and StorerKey = @cStorerkey and ID = @cID and Loc = @cFromLOC
   select top 1 @Style = Style, @ABC = ABC, @Class = CLASS from SKU (NOLOCK) where Sku = @SKU and StorerKey = @cStorerkey
   select top 1 @cFromLOCType = LocationType, @cFromLocPAZ = PutawayZone from Loc (NOLOCK) where Facility = @cFacility and loc = @cFromLOC

   --Check that LPN got only one SKU
   IF (select count(distinct sku) from LOTxLOCxID (NOLOCK) where qty > 0 and id = @cID and loc = @cFromLOC and storerkey = @cStorerKey)>1
   and (1 not in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQPASSKU' and storerkey = @cStorerKey) 
   or 0 in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQPASSKU' and storerkey = @cStorerKey))
   BEGIN
      SET @nErrNo = 217987
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   --Check if pick location for SKU is set
   IF exists (select Sku from LOTxLOCxID (NOLOCK)
   where id = @cID
   and qty > 0
   and loc = @cFromLOC
   and storerkey = @cStorerKey
   and not exists 
   (select sku from SKUxLOC (NOLOCK)
   where storerkey = @cStorerKey
   and sku = LOTxLOCxID.Sku
   and locationtype in ('PICK','CASE')
   and QtyLocationLimit > 0))

   BEGIN
      SET @nErrNo = 217988
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   --Establish an LPN type
   DECLARE @LPNPATYPE nvarchar(20)

   --Battery
   IF @Style = 'B'
   BEGIN
      SET @LPNPAType = 'Battery' 
   END

   --VelocityA
   ELSE IF @ABC = 'A'
   BEGIN
      SET @LPNPAType = 'VelocityA' 
   END

   --VelocityB
   ELSE IF	@ABC = 'B'
   BEGIN
      SET @LPNPAType = 'VelocityB' 
   END

   --VelocityC
   ELSE IF @ABC = 'C'
   BEGIN
      SET @LPNPAType = 'VelocityC' 
   END
	
   --VelocityE
   ELSE IF @ABC = 'E'
   BEGIN
      SET @LPNPAType = 'VelocityE' 
   END

   ELSE --Error if LPN type could not be established
   BEGIN
      SET @nErrNo = 217989
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Unknown PA LPN type'
      GOTO RollBackTran
   END

   --FLYMO check
   DECLARE @Flymo int
   SET @Flymo = 0

   IF @Class = 'FLY'
   BEGIN
      SET @Flymo = 1
   END

   IF not exists (select 1 from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'VNA' and Storerkey = @cStorerKey)
   BEGIN
      GOTO SkipVNA
   END

   --Creating list of available PnDs
   DECLARE @AvailablePnDAisle as TABLE (AvailablePnDAisle NVARCHAR(20))
   
   insert into @AvailablePnDAisle
   select LocAisle from
   (select MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
   L.Loc, LocationType, LocationFlag, LocationCategory, L.Cube, WeightCapacity, Status, PutawayZone, LocAisle,
   isnull(TotalWeight,0)TotalWeight, isnull(TotalCube,0)TotalCube, --This is from T1 table which calculate how much weight and cube is in the location based on SKU qty.
   IDWeight, IDCube
   from LOC L (NOLOCK)

   left join
   (
   select Loc, sum((LLI.qty+PendingMoveIN) * STDGROSSWGT) TotalWeight, sum((LLI.qty+PendingMoveIN) * (WidthUOM3 * LengthUOM3 * HeightUOM3)) TotalCube --Fnding how much weight and cube is in the location based on SKU qty.
   from LOTxLOCxID LLI (NOLOCK)
   join SKU S (NOLOCK)
   on LLI.Sku = S.Sku
   join PACK P (NOLOCK)
   on s.PACKKey = p.PackKey
   where (LLI.qty+PendingMoveIN)> 0
   and LLI.StorerKey = @cStorerKey
   and S.StorerKey = @cStorerKey
   group by loc
   )T1
   ON L.Loc = T1.Loc

   cross join
   (select isnull(sum(lli.qty * STDGROSSWGT),0) IDWeight, isnull(sum(lli.qty * (WidthUOM3 * LengthUOM3 * HeightUOM3)),0) IDCube from lotxlocxid LLI(NOLOCK) 
   join SKU S (NOLOCK)	on LLI.Sku = S.Sku join PACK P (NOLOCK) on S.PACKKey = P.PackKey
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cID and loc = @cFromLOC and s.StorerKey = @cStorerKey)T2

   where facility = @cFacility
   and PutawayZone in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNAZONHUSQ' and Storerkey = @cStorerKey)
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
   DECLARE @AvailableLoc as TABLE
   (AvailableLoc NVARCHAR(20),
   PALogicalLoc NVARCHAR(20),
   LocType NVARCHAR(20))

   insert into @AvailableLoc
   select top 1 Loc, PALogicalLoc, 'VNA' From
   (select substring(L.Loc,6,1) LocLevel, MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
   L.Loc, LocationType, LocationFlag, LocationCategory, l.Cube, WeightCapacity, Status, PutawayZone, LocAisle,
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
   where LLI.qty > 0 and LLI.storerkey = @cStorerKey and id = @cID and loc = @cFromLOC)T2

   where facility = @cFacility
   and (PutawayZone in (select code from CODELKUP (NOLOCK) where Storerkey = @cStorerKey AND LISTNAME = 'VNAZONHUSQ'))
   and (LocationCategory in (select code from CODELKUP (NOLOCK) where Storerkey = @cStorerKey AND LISTNAME = 'VNACATHUSQ'))
   and (LocationType in (select code from CODELKUP (NOLOCK) where Storerkey = @cStorerKey AND LISTNAME = 'VNATYPHUSQ'))
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and LocAisle in (select AvailablePnDAisle from @AvailablePnDAisle)
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T3

   where MaxPallet - SpaceTaken > 0 and Cube - TotalCube - IDCube > 0 and WeightCapacity - TotalWeight - IDWeight > 0
   
   --Filter by product type
   and ((@Flymo = 1 and LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = 'Flymo' and short = 'VNA' and Storerkey = @cStorerKey))or @Flymo <> 1)
   and ((LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'VNA' and Storerkey = @cStorerKey)))

   order by PALogicalLoc

   SkipVNA:
   --Creating list of available Wide Aisle locations
   IF not exists (select 1 from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'WA' and Storerkey = @cStorerKey)
   BEGIN
      GOTO SkipWA
   END
   
   DECLARE @AvailableWALoc as TABLE (AvailableWALoc NVARCHAR(20), PALogicalLoc NVARCHAR(20))
   
   Insert into @AvailableWALoc
   select Loc, PALogicalLoc From
   (select substring(L.Loc,6,1) LocLevel, MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
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
   on S.PACKKey = p.PackKey
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
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cID and loc = @cFromLOC)T2

   where facility = @cFacility
   and (PutawayZone in (select code from CODELKUP (NOLOCK) where Storerkey = @cStorerKey AND LISTNAME = 'WAZONEHUSQ'))
   and (LocationCategory in (select code from CODELKUP (NOLOCK) where Storerkey = @cStorerKey AND LISTNAME = 'WACATHUSQ'))
   and (LocationType in (select code from CODELKUP (NOLOCK) where Storerkey = @cStorerKey AND LISTNAME = 'WATYPEHUSQ'))
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T3

   where MaxPallet - SpaceTaken > 0 and Cube - TotalCube - IDCube > 0 and WeightCapacity - TotalWeight - IDWeight > 0

   --Filter by product type
   and ((@Flymo = 1 and LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = 'Flymo' and short = 'WA' and Storerkey = @cStorerKey))or @Flymo <> 1)
   and ((LocLevel in (select Long from CODELKUP (NOLOCK) where listname = 'HUSQLPNTYP' and udf01 = @LPNPAType and short = 'WA' and Storerkey = @cStorerKey)))	

   --Creating proximity check for Wide Aisle locations
   insert into @AvailableLoc
   select top 1 AvailableWALoc, PALogicalLoc, 'WA' from
   (select AvailableWALoc, PALogicalLoc,
   abs(convert(float,(convert(nvarchar(3),ASCII(substring(AvailableWALoc,1,1)))+
   convert(nvarchar(3),ASCII(substring(AvailableWALoc,2,1)))+
   convert(nvarchar(3),ASCII(substring(AvailableWALoc,3,1)))+
   convert(nvarchar(3),ASCII(substring(AvailableWALoc,4,1)))+
   convert(nvarchar(3),ASCII(substring(AvailableWALoc,5,1)))+
   convert(nvarchar(3),ASCII(substring(AvailableWALoc,6,1)))+
   convert(nvarchar(3),ASCII(substring(AvailableWALoc,7,1)))))
   - Coordinates2)Proximity
   from @AvailableWALoc
   cross join
   (select 
   convert(nvarchar(3),ASCII(substring(Loc,1,1)))+
   convert(nvarchar(3),ASCII(substring(Loc,2,1)))+
   convert(nvarchar(3),ASCII(substring(Loc,3,1)))+
   convert(nvarchar(3),ASCII(substring(Loc,4,1)))+
   convert(nvarchar(3),ASCII(substring(Loc,5,1)))+
   convert(nvarchar(3),ASCII(substring(Loc,6,1)))+
   convert(nvarchar(3),ASCII(substring(Loc,7,1)))Coordinates2
   from SKUxLOC (NOLOCK) --Retrieving pick SKUs 
   where StorerKey = @cStorerKey 
   and sku = (select top 1 sku from LOTxLOCxID (NOLOCK) where qty > 0 and id = @cID and loc = @cFromLOC and storerkey = @cStorerKey)
   and QtyLocationLimit > 0)T1)T2
   order by Proximity, PALogicalLoc

   ------custom code before global putaway SP end
   SkipWA:

   DECLARE @LocAisle NVARCHAR(10),
   @PendingLoc NVARCHAR(20)

   SET @PendingLoc = case when exists (select 1 from LOTxLOCxID (NOLOCK) where id = @cID and PendingMoveIN > 0 and StorerKey = @cStorerKey) then
   (select top 1 LOC from LOTxLOCxID (NOLOCK) where id = @cID and PendingMoveIN > 0 and StorerKey = @cStorerKey) else '' end

   SET @cSuggLOC = case when @PendingLoc <> '' then @PendingLoc
   when not exists (select 1 from @AvailableLoc) then '' else (select top 1 AvailableLoc from @AvailableLoc order by PALogicalLoc) end 

   select top 1 @LocAisle = locaisle from loc (NOLOCK) where Facility = @cFacility AND loc = (select top 1 AvailableLoc from @AvailableLoc order by PALogicalLoc)

   SET @cPickAndDropLOC = case when not exists (select 1 from @AvailableLoc) 
   or (select top 1 LocType from @AvailableLoc order by PALogicalLoc) <> 'VNA' 
   or (@cFromLOCType = 'PND' and @cFromLocPAZ in (select code from CODELKUP (NOLOCK) where storerkey = @cStorerKey and LISTNAME = 'VNAZONHUSQ'))
   then ''
   else
   (select top 1 Loc from
   (select MaxPallet, 
   (select count(distinct ID) from LOTxLOCxID (NOLOCK) where qty+PendingMoveIN > 0 and loc = L.Loc and StorerKey = @cStorerKey) SpaceTaken, --Finding how many pallets are in the location and how much can fit there.
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
   JOIN PACK P (NOLOCK)
   on S.PACKKey = P.PackKey
   where (lli.qty+PendingMoveIN)> 0
   and LLI.StorerKey = @cStorerKey
   group by loc
   )T1
   ON L.Loc = T1.Loc

   cross join
   (select isnull(sum(lli.qty * STDGROSSWGT),0) IDWeight, isnull(sum(lli.qty * (WidthUOM3 * LengthUOM3 * HeightUOM3)),0) IDCube from lotxlocxid LLI(NOLOCK) 
   join SKU S (NOLOCK)	on LLI.Sku = S.Sku join PACK P (NOLOCK) on S.PACKKey = P.PackKey
   where lli.qty > 0 and LLI.storerkey = @cStorerKey and id = @cID and loc = @cFromLOC)T2

   where facility = @cFacility
   and PutawayZone in (select code from CODELKUP (NOLOCK) where LISTNAME = 'VNAZONHUSQ' and Storerkey = @cStorerKey)
   and LocationCategory = 'PND'
   and LocationFlag in ('','NONE')
   and status = 'OK'
   and LocAisle = @LocAisle
   and not exists (select 1 from INVENTORYHOLD (NOLOCK) where Hold = 1 and isnull(loc,'') <> '' and loc = l.loc and Storerkey = @cStorerKey))T1

   where MaxPallet - SpaceTaken > 0 and 
   case when 
   (1 not in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQCHKPND' and storerkey = @cStorerKey) 
   or 0 in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQCHKPND' and storerkey = @cStorerKey))
   then 1 
   when Cube - TotalCube - IDCube >= 0 and WeightCapacity - TotalWeight - IDWeight >= 0 then 1 else 0
   end = 1) end

   set @cFitCasesInAisle = ''

   DECLARE @PnDRequired int
   SET @PnDRequired = case when (select top 1 LocType from @AvailableLoc order by PALogicalLoc) = 'VNA' then 1 else 0 end

   IF @PnDRequired = 1 and not exists (select 1 from @AvailablePnDAisle)
   BEGIN
      SET @nErrNo = 217990
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PnD loc available
      GOTO Quit
   END

   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = 217991
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PA loc available
      GOTO Quit
   END
   
   -- Lock suggested location
   BEGIN
      -- Get LOC aisle
      DECLARE 
      @cLOCAisle  NVARCHAR(10),
      @cLOCCat    NVARCHAR(10),
      @cPAZone    NVARCHAR(10),
      @cPAPNDReq  NVARCHAR(10)
   
      -- Handling transaction
      RollBackTran:
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASPVLT4 -- For rollback or commit only our own transaction
      
      IF @nErrNo<>0
      BEGIN
         GOTO RollbackTran2
      END

      SET @nPABookingKey = 0
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cSuggLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran2
      END

      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cPickAndDropLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran2
      END

   update LOTxLOCxID
   set PendingMoveIN = PendingMoveIN / 2
   where id = @cID and loc = @PendingLoc and storerkey = @cStorerKey and PendingMoveIN > 0 and ID <> ''

   COMMIT TRAN rdt_1819ExtPASPVLT4 -- Only commit change made here
   END

   delete from RFPUTAWAY
   where id = @cID and StorerKey = @cStorerKey

   GOTO Quit

   RollBackTran2:
   ROLLBACK TRAN rdt_1819ExtPASPVLT4 -- Only rollback change made here

   Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
   COMMIT TRAN

END

GO