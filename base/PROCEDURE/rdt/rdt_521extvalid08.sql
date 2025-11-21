SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtValid08                                   */
/* Copyright: Maersk                                                    */
/* Purpose: Validate override toLoc for Levis                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2024-06-07  1.0  Jackc     FCR-264. Created                          */ 
/************************************************************************/

CREATE   PROC [RDT].[rdt_521ExtValid08] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cUCCNo          NVARCHAR( 20),
   @cSuggestedLOC   NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cFacility           NVARCHAR( 5),  
            @cToLocType          NVARCHAR( 10),
            @cToPutawayZone      NVARCHAR( 20),
            @cToLocAisle         NVARCHAR( 10),
            @cToLocStatus        NVARCHAR( 10),
            @nToMaxCarton        INT,

            @cSuggtRFFromLoc     NVARCHAR( 10),
            @cSuggtRFSuggLoc     NVARCHAR( 10),
            @nSuggtRFQty         INT,
            @nSuggtRFPABookKey   INT,
            @cSuggtRFFromID      NVARCHAR ( 18),
            @cSuggtFromLocCat    NVARCHAR ( 10),

            @nSuggtMaxCarton     INT,
            @cSuggtPutawayZone   NVARCHAR( 20),
            @cSuggtLocAsile      NVARCHAR( 10)
            

   SET @nErrNo = 0
   SET @cErrMSG = ''
   SET @nSuggtRFPABookKey = 0


   SELECT @cFacility = Facility FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nFunc = 521
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ISNULL(@cSuggestedLOC,'') <> @cToLOC
            BEGIN
               --GET toLoc info
               SELECT 
                  @cToLocType = LocationType
                  , @cToPutawayZone = PutawayZone
                  , @cToLocAisle = LocAisle
                  , @cToLocStatus = Status
                  , @nToMaxCarton = IIF(MaxCarton=0, 9999, MaxCarton)
               FROM LOC WITH (NOLOCK)
               WHERE FACILITY = @cFacility
                  AND LOC = @cToLOC

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 216151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLoc Not Exists
                  GOTO Quit
               END

               --Get SuggestLoc info
               SELECT 
                  @cSuggtPutawayZone = PutawayZone
                  , @cSuggtLocAsile = LocAisle
                  , @nSuggtMaxCarton = IIF(MaxCarton=0, 9999, MaxCarton)
               FROM LOC WITH (NOLOCK)
               WHERE FACILITY = @cFacility
                  AND LOC = ISNULL(@cSuggestedLOC, '')

               
               --Validate toLoc
               IF ISNULL(@cToPutawayZone,'') = ''
               BEGIN
                  SET @nErrNo = 216152
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLoc not have Putaway Zone
                  GOTO Quit
               END

               IF ISNULL(@cToLocAisle, '') = '' 
               BEGIN
                  SET @nErrNo = 216153
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLoc not have Asile
                  GOTO Quit
               END

               IF ISNULL(@cToLocStatus, '') <> 'OK' 
               BEGIN
                  SET @nErrNo = 216158
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLoc Status must be OK
                  GOTO Quit
               END

               IF ISNULL(@cToLocType, '') <> 'CASE' 
               BEGIN
                  SET @nErrNo = 216154
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc Type not case
                  GOTO Quit
               END


               --To loc putaway zone not valid
               IF @cToPutawayZone <> ISNULL(@cSuggtPutawayZone, '')
               BEGIN
                  SET @nErrNo = 216155
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid putaway zone
                  GOTO Quit
               END

               IF ((SELECT COUNT(1) FROM UCC WITH (NOLOCK) WHERE LOC = @cToLOC AND [Status] IN ('1','3','4') GROUP BY LOC) 
                     >= @nToMaxCarton)
               BEGIN
                  SET @nErrNo = 216156
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLoc is Full
                  GOTO Quit
               END

               -------------------------------------------------------------------------------------------
               -- FCR-264 Main logic
               -------------------------------------------------------------------------------------------
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

               -- check available capacity (capacity - storage - booked) if not from same aisle or not from PND
               IF (@cToLocAisle <> ISNULL(@cSuggtLocAsile,'')) OR (ISNULL(@cSuggtFromLocCat,'')  NOT IN ('PND', 'PND_IN', 'PND_OUT'))
               BEGIN
                  -- Check ToLoc must be (capacity - storage - booked) >0
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
                              HAVING IIF(loc.MaxCarton = 0, 9999, loc.MaxCarton) - COUNT(DISTINCT sto.UCCNo) - COUNT(DISTINCT RFPUTAWAY.CaseID) <= 0)
                  BEGIN
                     SET @nErrNo = 216157
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLoc is full or booked
                     GOTO Quit
                  END --check toLOC capacity
               END -- not from pnd or not in same aisle

               GOTO Quit
            END -- suggtLoc <> toLoc
         END -- inputkey =1
      END -- Step 2
   END -- func 521

   
   Quit:

END-- END SP

GO