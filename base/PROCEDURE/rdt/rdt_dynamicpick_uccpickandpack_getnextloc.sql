SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_UCCPickAndPack_GetNextLOC           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next location for UCC Pick And Pack function            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 25-04-2013 1.0  Ung         SOS262114 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_UCCPickAndPack_GetNextLOC] (
   @nMobile         INT,
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),
   @cWaveKey        NVARCHAR( 10),
   @cPWZone         NVARCHAR( 10),
   @cFromLoc        NVARCHAR( 10),
   @cToLoc          NVARCHAR( 10),
   @cCurrSuggestLOC NVARCHAR( 10),   
   @cNextSuggestLOC NVARCHAR( 10)  OUTPUT,
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT TOP 1 
      @cNextSuggestLOC = PD.LOC
   FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK, INDEX(PKLOC)) ON (PD.LOC = LOC.LOC)
   WHERE PD.WaveKey = @cWaveKey 
      AND LOC.PutawayZone = @cPWZone
      AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc
      AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
      AND PD.Status < '3'
      AND PD.QTY > 0
      AND PD.UOM = '2' -- Full case
      AND LOC.LOC > @cCurrSuggestLOC
      AND NOT EXISTS (SELECT 1 
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
         WHERE O.OrderKey = PD.OrderKey
            AND O.SOStatus = 'CANC'
            AND PD1.UOM = '2' -- Full case
         GROUP BY PD1.Status
         HAVING MAX( PD1.Status) = '0')
   ORDER BY LOC.LOC
   
   IF @@ROWCOUNT = 0
   BEGIN
      -- If no more next LOC then start search from first loc till last loc. Coz user might skip LOC
      SELECT TOP 1 
         @cNextSuggestLOC = PD.LOC
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK, INDEX(PKLOC)) ON (PD.LOC = LOC.LOC)
      WHERE PD.WaveKey = @cWaveKey 
         AND LOC.PutawayZone = @cPWZone
         AND LOC.LOC BETWEEN @cFromLoc AND @cToLoc
         AND PD.LOC BETWEEN @cFromLoc AND @cToLoc
         AND PD.Status < '3'
         AND PD.QTY > 0
         AND PD.UOM = '2' -- Full case
         AND NOT EXISTS (SELECT 1 
            FROM dbo.Orders O WITH (NOLOCK)
               JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
            WHERE O.OrderKey = PD.OrderKey
               AND O.SOStatus = 'CANC'
               AND PD1.UOM = '2' -- Full case
            GROUP BY PD1.Status
            HAVING MAX( PD1.Status) = '0')
      ORDER BY LOC.LOC

      -- If really no more LOC, prompt error
      IF @@ROWCOUNT = 0
      BEGIN    
         SET @nErrNo = 80801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more PKLOC
         GOTO Quit
      END         
   END   
      
Quit:
   SET @cNextSuggestLOC = CASE WHEN @cNextSuggestLOC <> '' THEN @cNextSuggestLOC ELSE @cCurrSuggestLOC END
      
END


GO