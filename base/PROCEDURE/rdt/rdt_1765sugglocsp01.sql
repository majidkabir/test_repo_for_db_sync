SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1765SuggLocSP01                                 */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: VICTORIA SECRET Replen To Logic                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 04-04-2019  1.0  ChewKP   Created. WMS-8496                          */ 
/* 13-05-2019  1.1  ChewKP   Fixes / Fine Tuning (ChewKP01 )            */
/* 21-06-2019  1.2  Ung      WMS-8496 Fix PendingMoveIn                 */
/* 14-10-2019  1.3  Chermaine WMS-10793 Not hardcode from Lot04 (cc01)  */
/* 27-05-2021  1.4  James    WMS-17060 Add new suggestloc logic(james01)*/
/* 20-02-2023  1.5  James    WMS-21740 Filter all AGV loc (james02)     */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1765SuggLocSP01] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @cUserName      NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cDROPID        NVARCHAR( 20),    
   @nStep          INT,  
   @cTaskDetailKey NVARCHAR(10),  
   @nQty           INT,  
   @cCustomSuggToLoc NVARCHAR(10) OUTPUT,
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE  
            @cFromLoc           NVARCHAR(10)  
          , @cToLoc             NVARCHAR(10)  
          , @b_Success          INT  
          , @cFromID            NVARCHAR(18)  
          , @cLot               NVARCHAR(10)  
          , @cSKU               NVARCHAR(20)   
          , @nPutawayQTY        INT
          , @cPutawayZone       NVARCHAR(10) 
          --, @dLottable04        DATETIME --(cc01)
          , @cSuggestedLOC      NVARCHAR(10) 
          , @nPABookingKey      INT
          , @cShort             NVARCHAR( 10)
          , @cBUSR9             NVARCHAR( 30)
          , @cPickZone          NVARCHAR( 10)
          , @nExists            INT = 0
          
   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   SET @cSKU     = ''  
   SET @cLot     = ''  
   SET @cFromLoc = ''  
   SET @cToLoc   = ''  
   SET @cFromID  = ''  
   
   SET @cCustomSuggToLoc = '' 

   --SET @nTranCount = @@TRANCOUNT  
   
   IF @nFunc = 1765 
   BEGIN
      
      
      SELECT 
               @cFromLoc = FromLoc
             , @cToLoc   = ToLoc
             , @cFromID  = FromID
             , @cSKU     = SKU
             , @cLot     = Lot   
             , @nPutawayQTY = Qty
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey 
      
      SELECT 
         @cPutawayZone = PutawayZone, 
         @cBUSR9 = BUSR9 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU 

      SELECT @cShort = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'RPTFNLLOC'
      AND   UDF02 = @cBUSR9
      AND   Code = @cFacility
      AND   Storerkey = @cStorerKey      
      SET @nExists = @@ROWCOUNT
      
      IF OBJECT_ID('tempdb..#AGVLOC') IS NOT NULL  
      DROP TABLE #AGVLOC
         
      CREATE TABLE #AGVLOC  (  
         RowRef        BIGINT IDENTITY(1,1)  Primary Key,
         LOC           NVARCHAR( 10))  

      INSERT INTO #AGVLOC ( LOC)
      SELECT DISTINCT Long
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'RPTFEXLOC'
      AND   Code = @cFacility
      AND   Short = '1'
      AND   Storerkey = @cStorerKey
      
      IF ISNULL( @cShort, '0') = '0' OR @nExists = 0
      BEGIN
         --Step1 Find same SKU from SKU PutawayZone
         SELECT TOP 1 @cSuggestedLOC = LLI.LOC
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone
            --AND LOC.LocationCategory <> 'STAGE'
            --AND ISNULL(LOC.HostWHCode,'')  = ''
            AND LOC.LocationCategory = 'MEZZANINE'   /*ChewKP01*/
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
            --AND LA.Lottable04 = @dLottable04 --(cc01)
            AND NOT EXISTS ( SELECT 1 FROM #AGVLOC AGVLOC WHERE LOC.Loc = AGVLOC.LOC)
         ORDER BY LOC.LogicalLocation, LOC.Loc
      
         --Step2 Find Empty Loc from same SKU Putawayzone
         IF ISNULL(@cSuggestedLOC,'')  = '' 
         BEGIN
            SELECT TOP 1 @cSuggestedLOC = LOC.loc                              
            FROM LOC LOC WITH (NOLOCK)     
            LEFT OUTER JOIN LotxLocxID LLI WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LLI.Storerkey = @cStorerKey AND LLI.Loc = Loc.Loc)     
            WHERE LOC.LOC <> @cFromLoc  
            AND   LOC.putawayzone = @cPutawayZone
            AND   LOC.LocationCategory = 'MEZZANINE'
            AND   LOC.Facility = @cFacility  
            AND   NOT EXISTS ( SELECT 1 FROM #AGVLOC AGVLOC WHERE LOC.Loc = AGVLOC.LOC)
            GROUP BY LOC.LogicalLocation, LOC.LOC   
            HAVING SUM( ISNULL(LLI.Qty,0)) = 0  /*ChewKP01*/
               AND SUM( ISNULL(LLI.PendingMoveIn,0)) = 0
            ORDER BY LOC.LogicalLocation, LOC.LOC
         
            --Step2 Find Empty Loc from any Putawayzone
            IF ISNULL(@cSuggestedLOC,'')  = '' 
            BEGIN
               SELECT TOP 1 @cSuggestedLOC = LOC.loc                              
               FROM LOC LOC WITH (NOLOCK)     
               LEFT OUTER JOIN LotxLocxID LLI WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LLI.Storerkey = @cStorerKey AND LLI.Loc = Loc.Loc)    /*Michael01*/ 
               WHERE LOC.LOC <> @cFromLoc  
               AND   LOC.LocationCategory = 'MEZZANINE'
               AND   LOC.Facility = @cFacility  
               AND   NOT EXISTS ( SELECT 1 FROM #AGVLOC AGVLOC WHERE LOC.Loc = AGVLOC.LOC)
               GROUP BY LOC.LogicalLocation, LOC.LOC   
               HAVING SUM( ISNULL(LLI.Qty,0))  = 0  /*ChewKP01*/
                  AND SUM( ISNULL(LLI.PendingMoveIn,0)) = 0
               ORDER BY LOC.LogicalLocation, LOC.LOC
            END
         END
      END
      ELSE IF @cShort = '1'
      BEGIN
         SELECT @cSuggestedLOC = Long
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'RPTFNLLOC'
         AND   UDF02 = @cBUSR9
         AND   Code = @cFacility
      END
      IF @cShort = '2'
      BEGIN
         SELECT @cPutawayZone = UDF01
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'RPTFNLLOC'
         AND   UDF02 = @cBUSR9
         AND   Code = @cFacility
         AND   Storerkey = @cStorerKey   
      
         --Step1 Find same SKU from SKU PutawayZone
         SELECT TOP 1 @cSuggestedLOC = LLI.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LOC.PutawayZone = @cPutawayZone
         AND   LOC.LocationCategory = 'MEZZANINE'
         AND   LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cSKU
         AND   LLI.QTY-LLI.QTYPicked+LLI.PendingMoveIn > 0
         ORDER BY ( LLI.QTY-LLI.QTYPicked) DESC, LOC.LogicalLocation, LOC.Loc
      
         --Step2 Find Empty Loc from same SKU Putawayzone
         IF ISNULL(@cSuggestedLOC,'')  = '' 
         BEGIN
            SELECT TOP 1 @cSuggestedLOC = LOC.loc                              
            FROM dbo.LOC LOC WITH (NOLOCK)     
            LEFT OUTER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON ( LLI.Loc = Loc.Loc)     
            WHERE LOC.LOC <> @cFromLoc  
            AND   LOC.PutawayZone = @cPutawayZone
            AND   LOC.LocationCategory = 'MEZZANINE'
            AND   LOC.Facility = @cFacility  
            AND   LLI.Storerkey = @cStorerKey
            GROUP BY LOC.LogicalLocation, LOC.LOC   
            HAVING SUM( ISNULL(LLI.Qty,0)) = 0  
               AND SUM( ISNULL(LLI.PendingMoveIn,0)) = 0
            ORDER BY SUM( LLI.QTY-LLI.QTYPicked), LOC.LogicalLocation, LOC.LOC
         
            --Step2 Find Empty Loc from any Putawayzone
            IF ISNULL(@cSuggestedLOC,'')  = '' 
            BEGIN
               SELECT TOP 1 @cSuggestedLOC = LOC.loc                              
               FROM dbo.LOC LOC WITH (NOLOCK)     
               LEFT OUTER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON ( LLI.Loc = Loc.Loc)    
               WHERE LOC.LOC <> @cFromLoc  
               AND   LOC.LocationCategory = 'MEZZANINE'
               AND   LOC.Facility = @cFacility  
               AND   LLI.Storerkey = @cStorerKey
               GROUP BY LOC.LogicalLocation, LOC.LOC   
               HAVING SUM( ISNULL(LLI.Qty,0)) = 0  
                  AND SUM( ISNULL(LLI.PendingMoveIn,0)) = 0
               ORDER BY SUM( LLI.QTY-LLI.QTYPicked), LOC.LogicalLocation, LOC.LOC
            END
         END
      END
      
      IF ISNULL(@cSuggestedLOC,'') = '' 
      BEGIN
         IF @cShort = '1'
         BEGIN
            SET @nErrNo = 168251    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvSuggAGVLoc    
         END
         ELSE IF @cShort = '2'
         BEGIN
            SET @nErrNo = 168252    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No SuggAGVLoc    
         END
            
         GOTO QUIT
      END
      ELSE
      BEGIN
         --Booking Location          
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
         ,@cFromLOC      --FromLOC  
         ,@cFromID       --FromID  
         ,@cSuggestedLOC --SuggLOC  
         ,@cStorerKey    --Storer  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
         ,@cSKU           = @cSKU
         ,@cFromLOT       = @cLOT
         ,@cTaskDetailKey = @cTaskDetailKey  

         IF @nErrNo <> 0
         GOTO QUIT
            
         SET @cCustomSuggToLoc = @cSuggestedLOC
      END

         --PRINT @cCustomSuggToLoc
       
  END
END   

QUIT:
 

GO