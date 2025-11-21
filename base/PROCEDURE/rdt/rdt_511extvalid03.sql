SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtValid03                                   */
/* Purpose: Move By ID Extended Validate                                */
/*                                                                      */
/* Called from: rdtfnc_Move_ID                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2019-10-22  1.0  James      WMS-10857 - Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_511ExtValid03] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 18),    
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @nMaxPallet  INT
   DECLARE @nCount      INT

   SET @nErrNo = 0

   SELECT @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
     

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         -- To loc have inventory only check max pallet
         IF EXISTS ( SELECT 1 
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                     WHERE LOC.Facility = @cFacility
                     AND   LOC.Loc = @cToLOC
                     GROUP BY LOC.LOC 
                     -- Not Empty LOC
                     HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0)
         BEGIN
            SELECT @nMaxPallet = MaxPallet  
            FROM dbo.LOC WITH (NOLOCK)  
            WHERE Loc = @cToLOC  
            AND   Facility = @cFacility

            SELECT @nCount = COUNT(DISTINCT ID)  
            FROM dbo.RFPutaway WITH (NOLOCK)  
            WHERE SuggestedLoc = @cToLOC  

            SELECT @nCount = @nCount + COUNT(DISTINCT LLI.Id)  
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)  
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.Loc = @cToLOC  
            AND  (LLI.Qty - LLI.QtyPicked) > 0  
            AND   LLI.Id NOT IN (  
                  SELECT DISTINCT ID  
                  FROM dbo.RFPutaway WITH (NOLOCK)  
                  WHERE SuggestedLoc = @cToLOC)
            
            IF @nCount >= @nMaxPallet
            BEGIN
               SET @nErrNo = 145501  -- OVER MAX PALLET
               GOTO Quit
            END
         END
      END
   END

QUIT:

GO