SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc04                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Find a friend, then find empty LOC                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 02-01-2015  1.0  Ung         SOS321614 Created                       */
/* 29-07-2015  1.1  Ung         SOS348770 Fix param changed             */
/* 23-04-2015  1.2  Ung         SOS337296 Add PABookingKey              */
/* 14-07-2021  1.3  Ung         Performance tuning (add cursor option)  */ 
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveSKUSuggLoc04] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @c_StorerKey   NVARCHAR( 15),
   @c_Facility    NVARCHAR( 5),
   @c_FromLOC     NVARCHAR( 10),
   @c_FromID      NVARCHAR( 18),
   @c_SKU         NVARCHAR( 20),
   @n_QtyReceived INT,
   @c_ToID        NVARCHAR( 18),
   @c_ToLOC       NVARCHAR( 10),
   @c_Type        NVARCHAR( 10), 
   @nPABookingKey INT           OUTPUT, 
   @c_oFieled01   NVARCHAR( 20) OUTPUT,
   @c_oFieled02   NVARCHAR( 20) OUTPUT,
   @c_oFieled03   NVARCHAR( 20) OUTPUT,
   @c_oFieled04   NVARCHAR( 20) OUTPUT,
   @c_oFieled05   NVARCHAR( 20) OUTPUT,
   @c_oFieled06   NVARCHAR( 20) OUTPUT,
   @c_oFieled07   NVARCHAR( 20) OUTPUT,
   @c_oFieled08   NVARCHAR( 20) OUTPUT,
   @c_oFieled09   NVARCHAR( 20) OUTPUT,
   @c_oFieled10   NVARCHAR( 20) OUTPUT,
   @c_oFieled11   NVARCHAR( 20) OUTPUT,
   @c_oFieled12   NVARCHAR( 20) OUTPUT,
   @c_oFieled13   NVARCHAR( 20) OUTPUT,
   @c_oFieled14   NVARCHAR( 20) OUTPUT,
   @c_oFieled15   NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility   NVARCHAR(5)
   DECLARE @cSuggLOC    NVARCHAR(10)
   DECLARE @cOutput     NVARCHAR(20)
   DECLARE @i           INT
   DECLARE @nQTY        INT
   
   DECLARE @cLOCCat1    NVARCHAR(10)
   DECLARE @cLOCCat2    NVARCHAR(10)
   DECLARE @cLOCCat3    NVARCHAR(10)
   DECLARE @cLOCCat4    NVARCHAR(10)
   DECLARE @cLOCCat5    NVARCHAR(10)

   SET @i = 1
   SET @cLOCCat1 = ''
   SET @cLOCCat2 = ''
   SET @cLOCCat3 = ''
   SET @cLOCCat4 = ''
   SET @cLOCCat5 = ''

   SET @c_oFieled01 = ''
   SET @c_oFieled02 = ''
   SET @c_oFieled03 = ''
   SET @c_oFieled04 = ''
   SET @c_oFieled05 = ''

   -- Get facility
   SELECT @cFacility = Facility FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get location category
   SELECT 
      @cLOCCat1 = LEFT( UDF01, 10), 
      @cLOCCat2 = LEFT( UDF02, 10), 
      @cLOCCat3 = LEFT( UDF03, 10), 
      @cLOCCat4 = LEFT( UDF04, 10), 
      @cLOCCat5 = LEFT( UDF05, 10)
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'RDTPA' 
      AND Code = 'LOCCat'
      AND StorerKey = @c_StorerKey 
      AND Code2 = @cFacility

   -- Find a friend
   DECLARE @curLOC CURSOR
   IF @cLOCCat1 = '' AND @cLOCCat2 = '' AND @cLOCCat3 = '' AND @cLOCCat4 = '' AND @cLOCCat5 = ''
      SET @curLOC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TOP 5
             LOC.LOC, SUM( LLI.QTY - LLI.QTYPicked)
         FROM dbo.LOC LOC WITH (NOLOCK)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
            AND LLI.StorerKey = @c_StorerKey
            AND LLI.SKU = @c_SKU
            AND LOC.LOC <> @c_FromLOC
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( LLI.QTY - LLI.QTYPicked) > 0 
         ORDER BY LOC.PALogicalLOC, LOC.LOC
   ELSE   
      SET @curLOC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TOP 5
             LOC.LOC, SUM( LLI.QTY - LLI.QTYPicked)
         FROM dbo.LOC LOC WITH (NOLOCK)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
            AND LLI.StorerKey = @c_StorerKey
            AND LLI.SKU = @c_SKU
            AND LOC.LOC <> @c_FromLOC
            AND LOC.LocationCategory <> ''
            AND LOC.LocationCategory IN (@cLOCCat1, @cLOCCat2, @cLOCCat3, @cLOCCat4, @cLOCCat5)
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( LLI.QTY - LLI.QTYPicked) > 0 
         ORDER BY LOC.PALogicalLOC, LOC.LOC

   OPEN @curLOC
   FETCH NEXT FROM @curLOC INTO @cSuggLOC, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cOutput = @cSuggLOC + RIGHT( SPACE(10) + RTRIM( CAST( @nQTY AS NVARCHAR(10))), 10)

      IF @i = 1 SET @c_oFieled01 = @cOutput
      IF @i = 2 SET @c_oFieled02 = @cOutput
      IF @i = 3 SET @c_oFieled03 = @cOutput
      IF @i = 4 SET @c_oFieled04 = @cOutput
      IF @i = 5 SET @c_oFieled05 = @cOutput

      SET @i = @i + 1
      IF @i > 5
         BREAK

      FETCH NEXT FROM @curLOC INTO @cSuggLOC, @nQTY
   END


   IF @i <= 5
   BEGIN
      -- Find empty LOC
      IF @cLOCCat1 = '' AND @cLOCCat2 = '' AND @cLOCCat3 = '' AND @cLOCCat4 = '' AND @cLOCCat5 = ''
         SET @curLOC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT TOP 5
                LOC.LOC
            FROM dbo.LOC LOC WITH (NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
               AND LOC.LOC <> @c_FromLOC
            GROUP BY LOC.PALogicalLOC, LOC.LOC
            HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
            ORDER BY LOC.PALogicalLOC, LOC.LOC
      ELSE
         SET @curLOC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT TOP 5
                LOC.LOC
            FROM dbo.LOC LOC WITH (NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
               AND LOC.LOC <> @c_FromLOC
               AND LOC.LocationCategory <> ''
               AND LOC.LocationCategory IN (@cLOCCat1, @cLOCCat2, @cLOCCat3, @cLOCCat4, @cLOCCat5)
            GROUP BY LOC.PALogicalLOC, LOC.LOC
            HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
            ORDER BY LOC.PALogicalLOC, LOC.LOC

      OPEN @curLOC
      FETCH NEXT FROM @curLOC INTO @cSuggLOC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cOutput = @cSuggLOC + RIGHT( SPACE(10) + RTRIM( CAST( 0 AS NVARCHAR(10))), 10)
         
         IF @i = 1 SET @c_oFieled01 = @cOutput
         IF @i = 2 SET @c_oFieled02 = @cOutput
         IF @i = 3 SET @c_oFieled03 = @cOutput
         IF @i = 4 SET @c_oFieled04 = @cOutput
         IF @i = 5 SET @c_oFieled05 = @cOutput

         SET @i = @i + 1
         IF @i > 5
            BREAK

         FETCH NEXT FROM @curLOC INTO @cSuggLOC
      END
   END
END

GO