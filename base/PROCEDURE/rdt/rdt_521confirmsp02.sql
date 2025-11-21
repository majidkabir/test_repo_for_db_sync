SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_521ConfirmSP02                                        */
/* CopyRight: Maersk                                                          */
/*                                                                            */
/* Purpose: Customized Confirm SP for LEVIS. 521ExtValid08 is required        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2024-06-07  1.0  JACKC    FCR-264 Created                                */
/******************************************************************************/

CREATE   PROC [rdt].[rdt_521ConfirmSP02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCCNo           NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cToLOC           NVARCHAR( 10),
   @cSuggestedLOC    NVARCHAR( 10),
   @cPickAndDropLoc  NVARCHAR( 10),
   @nPABookingKey    INT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   
   SET @nTranCount = @@TRANCOUNT
   DECLARE @cUserName NVARCHAR( 10) = SUSER_SNAME()

   -- Get UCC info
   DECLARE @nSKUCnt INT
   SELECT @nSKUCnt = COUNT( DISTINCT SKU)
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo
      AND [Status] = '1'
   
   
   /**********************************************************************************************
                                  FCR-264 Customized part
   **********************************************************************************************/
   DECLARE   
         @cToLocAisle         NVARCHAR( 10),
         @nToMaxCarton        INT,

         @cToRFFromLoc        NVARCHAR( 10),
         @cToRFSuggLOC        NVARCHAR( 10),
         @nToRFQty            INT,
         @nToRFPABookKey      INT,
         @cToRFFromID         NVARCHAR( 18),
         @cToRFCaseID         NVARCHAR( 20),
         @cToRFStorerKey      NVARCHAR( 15),

         @cSuggtRFFromLoc     NVARCHAR( 10),
         @cSuggtRFSuggLoc     NVARCHAR( 10),
         @nSuggtRFQty         INT,
         @nSuggtRFPABookKey   INT,
         @cSuggtRFFromID      NVARCHAR ( 18),

         @cSuggtFromLocCat    NVARCHAR ( 10),
         @nSuggtMaxCarton     INT,
         @cSuggtLocAsile      NVARCHAR( 10),

         @cNewBookLoc         NVARCHAR( 10),
         @bDebuggFlag         BIT = 0

   SET @nErrNo = 0
   SET @cErrMSG = ''
   SET @nSuggtRFPABookKey = 0
   SET @nToRFPABookKey = 0

   --Get UCC RFPutaway data
   SELECT 
      @cSuggtRFFromLoc = FromLoc
      , @nSuggtRFQty = qty
      , @cSuggtRFFromID = FromID
      , @nSuggtRFPABookKey = PABookingKey
      , @cSuggtFromLocCat = LOC.LocationCategory
   FROM RFPUTAWAY rf WITH (NOLOCK)
   LEFT JOIN LOC WITH (NOLOCK) ON LOC.Facility = @cFacility AND rf.FromLoc = LOC.Loc
   WHERE SuggestedLoc = ISNULL(@cSuggestedLOC,'')
      AND CaseID = @cUCCNo

   -- Retrieve PABookingKey again because it is reset to in rdt_521ExtPA18 to avoid the pre-book data deleted when press esc in step2
   IF @nPABookingKey = 0
      SET @nPABookingKey = @nSuggtRFPABookKey

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdtfnc_UCCPutaway -- For rollback or commit only our own transaction

   IF ISNULL(@cSuggestedLOC,'') <> @cToLOC
   BEGIN
      IF @bDebuggFlag = 1
         SELECT 'customize logic', @cSuggestedLOC as SuggestLoc, @cToLOC as toLoc

      --Clear PABookingKey to Skip basic unlock logic, handle it in customize logic
      SET @nPABookingKey = 0

      --GET toLoc info
      SELECT 
         @cToLocAisle = LocAisle
         , @nToMaxCarton = IIF(MaxCarton=0, 9999, MaxCarton)
      FROM LOC WITH (NOLOCK)
      WHERE FACILITY = @cFacility
         AND LOC = @cToLOC
      
      --Get SuggestLoc info
      SELECT 
         @cSuggtLocAsile = LocAisle
         , @nSuggtMaxCarton = IIF(MaxCarton=0, 9999, MaxCarton)
      FROM LOC WITH (NOLOCK)
      WHERE FACILITY = @cFacility
         AND LOC = @cSuggestedLOC

      --Get ToLoc RFPutaway data
      SELECT TOP 1
         @cToRFFromLoc = FromLoc
         , @nToRFQty = qty
         , @cToRFFromID = FromID
         , @cToRFSuggLOC = SuggestedLoc
         , @cToRFCaseID = CaseID
         , @nToRFPABookKey = PABookingKey
         , @cToRFStorerKey = StorerKey
      FROM RFPUTAWAY rf WITH (NOLOCK)
      WHERE SuggestedLoc = @cToLOC
      ORDER BY PABookingKey DESC


      IF @bDebuggFlag = 1
         SELECT  @cToLocAisle as ToLocAisle, @cSuggtLocAsile as SuggtLocAisle, @cSuggtFromLocCat as SuggtLocCat, @nSuggtRFPABookKey as suggtPABookKey,
                  @nToRFPABookKey as toPABookKey 
      
      -- If from pnd and in same aisle         
      IF @cToLocAisle = @cSuggtLocAsile AND @cSuggtFromLocCat  IN ('PND', 'PND_IN', 'PND_OUT')
      BEGIN

         IF @bDebuggFlag = 1
            SELECT 'debug - from PND & Same Aisle', @nToRFPABookKey as ToRFPABookKey

         IF @nToRFPABookKey = 0-- toLoc no booking info
         BEGIN
            IF @bDebuggFlag = 1
               SELECT 'debug - Unbook SuggtLoc only', @nSuggtRFPABookKey as SuggtRFPABookKey
            --unbook suggest loc
            IF @nSuggtRFPABookKey <> 0 
            BEGIN
               EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                     @cUserName = @cUserName,
                     @cType = N'UNLOCK',
                     @cStorerKey = @cStorerkey,
                     @cFromLoc = @cSuggtRFFromLoc,
                     @cFromID = @cSuggtRFFromID,
                     @cSuggestedLOC = @cSuggestedLOC,
                     @nErrNo = @nErrNo OUTPUT,
                     @cErrMsg = @cErrMsg OUTPUT,
                     @nPABookingKey = @nSuggtRFPABookKey

               IF @nErrNo <> 0
                  GOTO RollbackTran
            END
            -- book toLoc
            /*EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                     @cUserName = @cUserName,
                     @cType = N'LOCK',
                     @cStorerKey = @cStorerkey,
                     @cFromLoc = @cSuggtRFFromLoc,
                     @cFromID = @cSuggtRFFromID,
                     @cSuggestedLOC = @cToLOC,
                     @nPutawayQTY = @nSuggtRFQty,
                     @cUCCNo = @cUCCNo,
                     @nErrNo = @nErrNo OUTPUT,
                     @cErrMsg = @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollbackTran*/

         END -- ToRFPABookKey = 0
         ELSE  --Booking info found in ToLoc
         BEGIN
            IF @bDebuggFlag = 1
               SELECT 'Debug - unbook/book suggt  & unbook to loc'

               --unbook existing toLoc 
               /*EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                        @cUserName = @cUserName,
                        @cType = N'UNLOCK',
                        @cStorerKey = @cToRFStorerKey,
                        @cFromLoc = @cToRFFromLoc,
                        @cFromID = @cToRFFromID,
                        @cSuggestedLOC = @cToLOC,
                        @nErrNo = @nErrNo OUTPUT,
                        @cErrMsg = @cErrMsg OUTPUT,
                        @nPABookingKey = @nToRFPABookKey

               IF @nErrNo <> 0
                  GOTO RollbackTran*/

            --unbook suggest Loc
            EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                     @cUserName = @cUserName,
                     @cType = N'UNLOCK',
                     @cStorerKey = @cStorerkey,
                     @cFromLoc = @cSuggtRFFromLoc,
                     @cFromID = @cSuggtRFFromID,
                     @cSuggestedLOC = @cSuggestedLOC,
                     @nErrNo = @nErrNo OUTPUT,
                     @cErrMsg = @cErrMsg OUTPUT,
                     @nPABookingKey = @nSuggtRFPABookKey

            IF @nErrNo <> 0
               GOTO RollbackTran

            --Book toLoc with putaway UCC
            /*EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                     @cUserName = @cUserName,
                     @cType = N'LOCK',
                     @cStorerKey = @cStorerkey,
                     @cFromLoc = @cSuggtRFFromLoc,
                     @cFromID = @cSuggtRFFromID,
                     @cSuggestedLOC = @cToLOC,
                     @nPutawayQTY = @nSuggtRFQty,
                     @cUCCNo = @cUCCNo,
                     @nErrNo = @nErrNo OUTPUT,
                     @cErrMsg = @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollbackTran*/

            -- Check whether is there another unbooked and empty space
            SET @cNewBookLoc = ''
            SELECT TOP 1  @cNewBookLoc = loc.Loc
            FROM dbo.LOC loc WITH(NOLOCK) 
            LEFT JOIN ( SELECT LLI.Loc, UCC.UCCNo 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        INNER JOIN dbo.UCC WITH (NOLOCK) ON LLI.StorerKey = UCC.StorerKey AND LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC 
                        WHERE LLI.StorerKey = @cStorerKey
                           AND LLI.QTY - LLI.QTYPicked > 0 ) AS UCCSTO
               ON loc.Loc = UCCSTO.Loc
            LEFT JOIN dbo.RFPUTAWAY rp WITH(NOLOCK)
               ON loc.Loc = rp.SuggestedLoc
               AND rp.StorerKey = @cStorerKey
            WHERE 
               loc.Facility = @cFacility
               AND loc.LocationType = 'CASE'
               AND ISNULL(loc.Status, '') = 'OK'
               AND loc.LocAisle = @cSuggtLocAsile
               AND loc.Loc <> @cSuggestedLOC
            GROUP BY loc.LocAisle, loc.Loc, IIF(loc.MaxCarton = 0, 9999, MaxCarton)
            HAVING IIF(loc.MaxCarton = 0, 9999, loc.MaxCarton) - COUNT(DISTINCT UCCSTO.UCCNo) - COUNT(rp.RowRef) > 0
            ORDER BY loc.LocAisle, IIF(loc.MaxCarton = 0, 9999, MaxCarton) - COUNT(DISTINCT UCCSTO.UCCNo) - COUNT(rp.RowRef), loc.Loc
            
            IF @bDebuggFlag = 1
                  SELECT  'debug - Try to find new loc', @cNewBookLoc as NewBookLoc

            IF @bDebuggFlag = 1
               SELECT 'debug - unbook existing toLoc record'

            --unbook existing toLoc 
            EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                     @cUserName = @cUserName,
                     @cType = N'UNLOCK',
                     @cStorerKey = @cToRFStorerKey,
                     @cFromLoc = @cToRFFromLoc,
                     @cFromID = @cToRFFromID,
                     @cSuggestedLOC = @cToLOC,
                     @nErrNo = @nErrNo OUTPUT,
                     @cErrMsg = @cErrMsg OUTPUT,
                     @nPABookingKey = @nToRFPABookKey

            IF @nErrNo <> 0
               GOTO RollbackTran

            -- Check whether new loc found
            IF ISNULL(@cNewBookLoc, '') <> ''
            BEGIN
               IF @bDebuggFlag = 1
                  SELECT  'debug - book new loc ' + @cNewBookLoc
               
               -- Book NEW Loc with toLoc UCC
               EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                        @cUserName = @cUserName,
                        @cType = N'LOCK',
                        @cStorerKey = @cToRFStorerKey,
                        @cFromLoc = @cToRFFromLoc,
                        @cFromID = @cToRFFromID,
                        @cSuggestedLOC = @cNewBookLoc,
                        @nPutawayQTY = @nToRFQty,
                        @cUCCNo = @cToRFCaseID, --toLoc UCC
                        @nErrNo = @nErrNo OUTPUT,
                        @cErrMsg = @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO RollbackTran
            END
            ELSE 
            BEGIN -- No unbooked space found, book the original suggest loc 
               IF @bDebuggFlag = 1
                  SELECT 'debug - No unbooked loc found, repleace to/suggt loc rfputaway'

               -- Book Suggest Loc with toLoc UCC
               EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                        @cUserName = @cUserName,
                        @cType = N'LOCK',
                        @cStorerKey = @cToRFStorerKey,
                        @cFromLoc = @cToRFFromLoc,
                        @cFromID = @cToRFFromID,
                        @cSuggestedLOC = @cSuggestedLOC,
                        @nPutawayQTY = @nToRFQty,
                        @cUCCNo = @cToRFCaseID, --toLoc UCC
                        @nErrNo = @nErrNo OUTPUT,
                        @cErrMsg = @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO RollbackTran
            END -- Check whether new loc found

         END -- booking info found
      END -- from pnd in same aisle
      ELSE -- other scenarios
      BEGIN
         /* Check ToLoc must be (capacity - storage - booked) >0
         IF EXISTS ( SELECT 1
                     FROM  LOC WITH (NOLOCK)
                        LEFT JOIN ( SELECT UCC.Loc, UCC.UCCNo 
                                    FROM UCC WITH (NOLOCK) 
                                       INNER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON UCC.Loc = LLI.loc AND UCC.lot = lli.lot 
                                       AND UCC.storerkey = LLI.storerkey and UCC.sku = LLI.sku
                                    WHERE UCC.Loc = @cToLOC
                                       AND UCC.Status IN ('1','3','4')
                                       AND LLI.QTY - LLI.QTYPicked > 0) AS STO 
                           ON LOC.Loc = STO.Loc
                        LEFT JOIN RFPUTAWAY WITH(NOLOCK) ON LOC.Loc = RFPUTAWAY.SuggestedLoc
                     WHERE
                        LOC.Facility = @cFacility
                        AND LOC.Loc = @cToLOC
                     GROUP BY loc.LocAisle, loc.Loc, IIF(loc.MaxCarton = 0, 9999, MaxCarton)
                     HAVING IIF(loc.MaxCarton = 0, 9999, loc.MaxCarton) - COUNT(DISTINCT sto.UCCNo) - COUNT(DISTINCT RFPUTAWAY.CaseID) > 0)*/

         IF @bDebuggFlag = 1
            SELECT 'debug - Other scenarios, toLoc has capacity', @nSuggtRFPABookKey as SuggtPABookKey
         
         IF @nSuggtRFPABookKey <> 0 --unbook suggest loc
         BEGIN
            EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                  @cUserName = @cUserName,
                  @cType = N'UNLOCK',
                  @cStorerKey = @cStorerkey,
                  @cFromLoc = @cSuggtRFFromLoc,
                  @cFromID = @cSuggtRFFromID,
                  @cSuggestedLOC = @cSuggestedLOC,
                  @nErrNo = @nErrNo OUTPUT,
                  @cErrMsg = @cErrMsg OUTPUT,
                  @nPABookingKey = @nSuggtRFPABookKey 

            IF @nErrNo <> 0
               GOTO RollbackTran
         END
         -- book toLoc
         /*EXEC  [RDT].[rdt_Putaway_PendingMoveIn]
                  @cUserName = @cUserName,
                  @cType = N'LOCK',
                  @cStorerKey = @cStorerkey,
                  @cFromLoc = @cSuggtRFFromLoc,
                  @cFromID = @cSuggtRFFromID,
                  @cSuggestedLOC = @cToLOC,
                  @cToID = @cUCCNo,
                  @nPutawayQTY = @nSuggtRFQty,
                  @cUCCNo = @cUCCNo,
                  @nErrNo = @nErrNo OUTPUT,
                  @cErrMsg = @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO RollbackTran*/

      END -- other scenarios

   END -- suggtLoc <> toLoc

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   IF @bDebuggFlag = 1
      SELECT 'debug - standard confirm'
   -- Single SKU UCC
   IF @nSKUCnt = 1
   BEGIN
      IF @bDebuggFlag = 1
         SELECT 'debug - execut putaway for SKUCNT: ' + CAST(@nSKUCnt AS VARCHAR(10))
      -- Execute putaway process  
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,  
         @cLOT, 
         @cFromLOC,  
         @cID,  
         @cStorerKey,  
         @cSKU,  
         @nQTY,  
         @cToLOC,  
         '',      --@cLabelType OUTPUT, -- optional  
         @cUCCNo, -- optional  --(cc01- for event log)
         @nErrNo     OUTPUT,  
         @cErrMsg    OUTPUT  
      IF @nErrNo <> 0
         GOTO RollBackTran
   END
   
   -- Multi SKU UCC
   ELSE
   BEGIN
      IF @bDebuggFlag = 1
         SELECT 'debug - execut putaway for SKUCNT: ' + CAST(@nSKUCnt AS VARCHAR(10))
      DECLARE @cUCC_SKU NVARCHAR(20)
      DECLARE @cUCC_LOT NVARCHAR(10)
      DECLARE @nUCC_QTY INT
      DECLARE @curUCC   CURSOR

      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT SKU, QTY, LOT
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCCNo
            AND [Status] = '1'
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Execute putaway process  
         EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,  
            @cUCC_LOT,  
            @cFromLOC,  
            @cID,  
            @cStorerKey,  
            @cUCC_SKU,  
            @nUCC_QTY,  
            @cToLOC,  
            '',      --@cLabelType OUTPUT, -- optional  
            @cUCCNo, -- optional  --(cc01--for Eventlog)
            @nErrNo     OUTPUT,  
            @cErrMsg    OUTPUT  

         IF @nErrNo <> 0
            GOTO RollBackTran
         
         FETCH NEXT FROM @curUCC INTO @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
      END
   END

   -- Get LOC info  
   DECLARE @cLoseID  NVARCHAR( 1)
   DECLARE @cLoseUCC NVARCHAR( 1)
   SELECT   
      @cLoseID = LoseID,   
      @cLoseUCC = LoseUCC  
   FROM LOC WITH (NOLOCK)   
   WHERE LOC = @cToLOC  

   -- Update UCC
   UPDATE dbo.UCC WITH (ROWLOCK) SET 
      ID = CASE WHEN @cLoseID = '1' THEN '' ELSE ID END,   
      LOC = @cToLOC,   
      EditWho  = SUSER_SNAME(),    
      EditDate = GETDATE(),   
      [Status] = CASE WHEN @cLoseUCC = '1' THEN '6' ELSE [Status] END  
   WHERE UCCNo = @cUCCNo   
      AND StorerKey = @cStorerKey  
      AND Status = '1'  
   IF @@ERROR <> 0
   BEGIN    
      SET @nErrNo = 50020 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD UCC FAIL 
      GOTO RollBackTran    
   END    

   -- Unlock current session suggested LOC
   IF @nPABookingKey <> 0
   BEGIN
      IF @bDebuggFlag = 1
         SELECT 'debug - Unbook PABookingKey: ' + CAST(@nPABookingKey AS VARCHAR(10))
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --FromLOC
         ,'' --FromID
         ,'' --SuggLOC
         ,'' --Storer
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0  
         GOTO RollBackTran
   
      SET @nPABookingKey = 0
   END

   COMMIT TRAN rdt_UCCPutaway_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_UCCPutaway_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO