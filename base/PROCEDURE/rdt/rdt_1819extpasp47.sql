SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP47                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2023-04-14   1.0  yeekung   WMS-22234. Created                        */
/************************************************************************/

CREATE    PROC [RDT].[rdt_1819ExtPASP47] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10) = ''  OUTPUT,
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
   
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPAZone        NVARCHAR( 10)
   DECLARE @cLocAisle      nvarchar( 20)
   DECLARE @CLottable02    NVARCHAR(20)
   DECLARE @LocOfMinQty    NVARCHAR(20)
   DECLARE @MaxPallet      INT
   
   DECLARE @nTranCount  INT


   Select TOP 1
         @CLottable02 = LA.Lottable02,
         @CSKU = LLI.SKU
    from Loc LOC (Nolock)  
    JOIN lotxlocxID LLI (nolock) ON LOC.loc = lli.loc 
    Join [dbo].[LOTATTRIBUTE] LA (nolock) on LLi.Lot = LA.Lot and lli.Storerkey = LA.Storerkey 
    Where   LLI.ID =@cID
      AND LLI.LOC = @cFromLOC

	--Find a location of minimum QTY of inventory in the location with the same SKU & Batch (Lottable02) in the same putaway zone.
	Select top 1 @LocOfMinQty =  LOC.LOC ,
				@cPAZone = LOC.Putawayzone,  
				@cLocAisle = LOC.LocAisle, 
				@MaxPallet = Loc.MaxPallet
    from Loc LOC (Nolock)  
    JOIN lotxlocxID LLI (nolock) ON LOC.loc = lli.loc 
    Join [dbo].[LOTATTRIBUTE] LA (nolock) on LLi.Lot = LA.Lot and lli.Storerkey = LA.Storerkey 
    Where  Loc.LocationCategory in ('DOUBLE' ,'DRIVEIN')
    And Loc.LocationType = 'BULK'  
    And Loc.LocationFlag = 'NONE'  
    And Loc.Status = 'OK' 
    And ISNULL(LLI.qty,0)>0 
    AND LA.Lottable02 = @CLottable02
	And LLI.SKU = @cSKU  
    AND loc.loc <> @cFromLOC 
    Order by  LLI.qty ,Loc.PALogicalLoc


   IF ISNULL(@LocOfMinQty,'') = '' 
   BEGIN 
	   --findáanáemptyálocationáá
	   SELECT top 1 @cSuggLOC = LLI.LOC 
	   FROM dbo.LOC LOC WITH (NOLOCK)
	   join CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'NiRDTExtPA'  and CL.Short = LOC.Facility and CL.Long  = Loc.PutawayZone
	   left JOIN LOTXLOCXID LLI (NOLOCK)  ON ( LLI.Loc = LOC.Loc) 
	   WHERE LLI.StorerKey = @cStorerKey 
		   AND LOC.Facility = @cFacility 
		   and Loc.LocationCategory in ('DOUBLE' ,'DRIVEIN')
		   And Loc.LocationType = 'BULK'  
		   And Loc.LocationFlag = 'NONE'  
		   And Loc.Status = 'OK'  
		   AND LLI.LOC       <> @cFromLOC 
      group by LLI.LOC,Cl.Code, Loc.PALogicalLoc
      HAVING SUM(ISNULL(LLI.qty,0)) = 0
	   Order by Cl.Code, Loc.PALogicalLoc ASC 
   end
   else IF ISNULL(@LocOfMinQty,'') <> ''
   Begin
	   select Count(Id) as CntPL from LOTxLOCxID (nolock) where Qty > 0 and Loc = @LocOfMinQty
	   IF ISNULL(@MaxPallet,0) > (select Count(Id) from LOTxLOCxID (nolock) where Qty > 0 and Loc = @LocOfMinQty)
	   Begin 
		   set @cSuggLOC = @LocOfMinQty
	   End
	   else IF ISNULL(@MaxPallet,0) <= (select Count(Id) from LOTxLOCxID (nolock) where Qty > 0 and Loc = @LocOfMinQty)
	   BEGIN 
		   -- SEARCH Empty Location on same zone, same aisle 
		   SELECT TOP 1        @cSuggLoc =  LOC.LOC   
		   FROM dbo.LOC LOC WITH (NOLOCK)   
			   LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)   
		   WHERE LLI.StorerKey = @cStorerKey 
			   AND LOC.Facility = @cFacility 
			   and Loc.LocationCategory in ('DOUBLE' ,'DRIVEIN') 
			   AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')   
			   And Loc.LocationType = 'BULK'  
			   And Loc.LocationFlag = 'NONE'  
			   And Loc.Status = 'OK' 
			   AND LOC.LocAisle = @cLocAisle 
			   AND loc.loc <> @cFromLOC 
			   AND LOC.Putawayzone = @cPAZone 
		   GROUP BY LOC.PALogicalLOC, LOC.LOC   
		   HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyAllocated,0) - ISNULL( LLI.QTYPicked, 0)) = 0   
		   ORDER BY LOC.PALogicalLOC, LOC.LOC  

		    -- If No Empty Location on the same aisle, findáanáemptyálocationáá
		   IF ISNULL(@cSuggLoc,'')  = '' 
		   BEGIN 
			   --findáanáemptyálocationáá
			   SELECT top 1 @cSuggLOC = LLI.LOC 
			   FROM dbo.LOC LOC WITH (NOLOCK)
				   join CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'NiRDTExtPA'  and CL.Short = LOC.Facility and CL.Long  = Loc.PutawayZone
				   left JOIN LOTXLOCXID LLI (NOLOCK)  ON ( LLI.Loc = LOC.Loc) 
			   WHERE LLI.StorerKey = @cStorerKey 
				   AND LOC.Facility = @cFacility 
				   and Loc.LocationCategory in ('DOUBLE' ,'DRIVEIN')
				   And Loc.LocationType = 'BULK'  
				   And Loc.LocationFlag = 'NONE'  
				   And Loc.Status = 'OK'  
				   AND LLI.LOC       <> @cFromLOC 
            group by LLI.LOC,Cl.Code, Loc.PALogicalLoc
             HAVING SUM(ISNULL(LLI.qty,0)) = 0
	         Order by Cl.Code, Loc.PALogicalLoc ASC 
		   END 
	   end
   End


   IF ISNULL( @cSuggLOC, '') <> ''
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP47 -- For rollback or commit only our own transaction

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cSuggLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTraN
   
      COMMIT TRAN rdt_1819ExtPASP47

      GOTO Quit

      RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP47 -- Only rollback change made here
      Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

Fail:

END


GO