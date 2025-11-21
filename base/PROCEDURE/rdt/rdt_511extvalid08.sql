SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtValid08                                   */
/* Purpose: Move By ID Extended Validate                                */
/* Copyright      : Maersk                                              */
/* Called from: rdtfnc_Move_ID                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2024-09-13  1.0  PYU015     UWP-26436 WMS- Created                   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_511ExtValid08] (
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @nMaxPallet     INT
   DECLARE @nCount         INT

   SELECT @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1
                       FROM LOTxLOCxID inv WITH(NOLOCK)
                      INNER JOIN LOTATTRIBUTE attr WITH(NOLOCK) ON inv.Lot = attr.Lot AND inv.Sku = attr.Sku AND inv.StorerKey = attr.StorerKey
                      WHERE inv.StorerKey = @cStorerKey
                        AND inv.Id = @cFromID
                        AND inv.Qty > 0 
                        AND attr.Lottable11 = 'QI')
         BEGIN
             SELECT @nCount = COUNT(DISTINCT HOSTWHCODE)
               FROM LOC WITH(NOLOCK)
              WHERE Facility = @cFacility
                AND Loc in (@cFromLOC , @cToLOC)

             IF @nCount  > 1
             BEGIN
               SET @nErrNo = 219911
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Quit
             END
         END

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
               SET @nErrNo = 219912   -- OVER MAX PALLET
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Quit
            END
         END
      END
   END

QUIT:


GO