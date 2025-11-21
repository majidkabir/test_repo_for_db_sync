SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal07                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2019-08-02   James     1.0   WMS10120. Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal07]
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
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStorerKey NVARCHAR( 15),
           @cFacility  NVARCHAR( 10),
           @nMaxPallet INT,
           @nCount     INT

   SELECT @cStorerKey = StorerKey, 
          @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1 
   BEGIN
      IF @nStep IN ( 2, 5)
      BEGIN
         -- If empty loc no need further checking
         IF EXISTS ( SELECT 1 
                     FROM dbo.LOC LOC WITH (NOLOCK)
                     LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
                     WHERE LOC.Facility = @cFacility
                     AND   LOC.LOC = @cToLOC
                     AND   LOC.Locationflag <> 'HOLD'
                     AND   LOC.Locationflag <> 'DAMAGE'
                     AND   LOC.Status <> 'HOLD'
                     GROUP BY LOC.LOC
                     HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                                  ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) = 0)
            GOTO Quit

         -- Check max pallet for suggested loc
         SELECT @nMaxPallet = MaxPallet
         FROM dbo.LOC WITH (NOLOCK)  
         WHERE Loc = @cToLOC  
           
         IF @nMaxPallet <> 0  
         BEGIN  
            SELECT @nCount = COUNT( DISTINCT ID)  
            FROM dbo.RFPutaway WITH (NOLOCK)  
            WHERE SuggestedLoc = @cToLOC  
  
            IF @nCount > @nMaxPallet  
            BEGIN  
               SET @nErrNo = 142351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over MaxPallet
               GOTO QUIT  
            END  

            -- Cater for user key in loc that's not suggested and not lock in rfputaway
            IF @cToLOC <> @cSuggLOC
               SET @nCount = @nCount + 1

            SELECT @nCount = @nCount + COUNT( DISTINCT ID)  
            FROM dbo.LotxLocxID WITH (NOLOCK)  
            WHERE LOC = @cToLOC  
            AND  ( Qty - QtyPicked) > 0  
            AND   ID NOT IN (  
                     SELECT DISTINCT ID  
                     FROM dbo.RFPutaway WITH (NOLOCK)  
                     WHERE SuggestedLoc = @cToLOC)
  
            IF @nCount > @nMaxPallet  
            BEGIN  
               SET @nErrNo = 142352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over MaxPallet
               GOTO QUIT  
            END  
         END -- IF @nMaxPallet <> 0  
      END
   END

Quit:

END

GO