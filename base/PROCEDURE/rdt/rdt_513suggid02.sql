SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_513SuggID02                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-12-2017  1.0  ChewKP      WMS-3501 Created                        */
/* 06-04-2022  1.1  yeekung     Change error message(yeekung01)         */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggID02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @c_Storerkey   NVARCHAR( 15),
   @c_Facility    NVARCHAR( 5), 
   @c_FromLoc     NVARCHAR( 10),
   @c_FromID      NVARCHAR( 18),
   @c_SKU         NVARCHAR( 20),
   @n_QtyReceived INT,
   @c_ToID        NVARCHAR( 18),
   @c_ToLoc       NVARCHAR( 10),
   @c_Type        NVARCHAR( 10), 
   @nPABookingKey INT            OUTPUT, 
	@c_oFieled01   NVARCHAR( 20)  OUTPUT,
	@c_oFieled02   NVARCHAR( 20)  OUTPUT,
   @c_oFieled03   NVARCHAR( 20)  OUTPUT,
   @c_oFieled04   NVARCHAR( 20)  OUTPUT,
   @c_oFieled05   NVARCHAR( 20)  OUTPUT,
   @c_oFieled06   NVARCHAR( 20)  OUTPUT,
   @c_oFieled07   NVARCHAR( 20)  OUTPUT,
   @c_oFieled08   NVARCHAR( 20)  OUTPUT,
   @c_oFieled09   NVARCHAR( 20)  OUTPUT,
   @c_oFieled10   NVARCHAR( 20)  OUTPUT,
	@c_oFieled11   NVARCHAR( 20)  OUTPUT,
	@c_oFieled12   NVARCHAR( 20)  OUTPUT,
   @c_oFieled13   NVARCHAR( 20)  OUTPUT,
   @c_oFieled14   NVARCHAR( 20)  OUTPUT,
   @c_oFieled15   NVARCHAR( 20)  OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cSuggToLOC  NVARCHAR( 10)
          ,@cHostWHCode NVARCHAR( 10) 
          ,@dLottable04 DATETIME
          ,@cYearMonth  NVARCHAR(6) 
          ,@cLottable06 NVARCHAR(30) 
          ,@cPAType     NVARCHAR(1) 
          ,@cSuggToID   NVARCHAR(18) 
          ,@cLot        NVARCHAR(10) 
          ,@cSuggestedLOC  NVARCHAR(10) 

   DECLARE @cLabelSuggID  NVARCHAR(20)
   DECLARE @cLabelSuggLOC NVARCHAR(20)

          
   DECLARE @tSuggestedLoc TABLE
   (
      SKU NVARCHAR(20)
     ,Qty INT
     ,Loc NVARCHAR(10)
     ,ToID  NVARCHAR(18)
     ,LogicalLocation NVARCHAR(18) 
     ,LotAttribute NVARCHAR(10) -- YearMonth Of Date
     
   )
   
   SELECT TOP 1 @cLottable06 = LA.Lottable06
               ,@dLottable04 = LA.Lottable04
               ,@cLot        = LA.Lot
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @c_Storerkey
   AND LLI.SKU = @c_SKU
   AND LLI.ID  = @c_FromID
   AND LLI.Loc = @c_FromLoc
   --AND LLI.Lot = @cLot 

   
   
   IF @cLottable06 = ''
      SET @cLottable06 = 'P'
   
   SELECT @cPAType = UDF01
         ,@cHostWHCode = Long
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE ListName = 'EATHWCODE'
   AND StorerKey = @c_Storerkey
   AND Code = @cLottable06
   
--   SELECT @dLottable04 = LA.Lottable04
--   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
--   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
--   WHERE LLI.StorerKey = @cStorerKey
--   AND LLI.SKU = @cSKU
--   AND LLI.ID  = @cID
--   AND LLI.Loc = @cLoc
--   AND LLI.Lot = @cLot 
   
   SET @cYearMonth =  CAST(Year(@dLottable04) AS NVARCHAR(4))  + CAST ( Month(@dLottable04)  AS NVARCHAR(2)) 
   
   
   
   IF @cPAType = '2'
   BEGIN
      
      SELECT TOP 1 @cSuggestedLOC = LLI.Loc 
                  --, @nQTY         = LLI.Qty
                  , @cSuggToID = LLI.ID 
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
      WHERE LLI.StorerKey = @c_Storerkey
      AND LLI.SKU = @c_SKU
      AND LLI.ID <> @c_FromID
      AND Loc.Facility = @c_Facility
      --AND Loc.LocationFlag <> 'HOLD' 
      AND Loc.Loc <> @c_FromLoc
      AND LA.Lottable06 = @cLottable06
      AND Loc.HostWHCode = @cHostWHCode
      ORDER BY LLI.Qty, Loc.LogicalLocation
      
   END
   ELSE IF @cPAType = '3'
   BEGIN
    
      INSERT INTO @tSuggestedLoc ( SKU, Qty, Loc, ToID, LogicalLocation, LotAttribute )
      SELECT LLI.SKU, SUM(LLI.Qty), LLI.Loc, LLI.ID, LOC.LogicalLocation, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot
      WHERE LLI.StorerKey = @c_Storerkey
      AND LLI.SKU = @c_SKU
      AND LLI.ID <> @c_FromID
      AND Loc.Facility = @c_Facility
      --AND Loc.LocationFlag <> 'HOLD' 
      AND Loc.Loc <> @c_FromLoc
      AND Loc.HostWHCode = @cHostWHCode
      AND LA.Lottable06 = @cLottable06
      GROUP BY LLI.SKU, LLI.Loc, LOC.LogicalLocation, LLI.ID, CAST(Year(LA.Lottable04) AS NVARCHAR(4))  + CAST ( Month(LA.Lottable04)  AS NVARCHAR(2))
      
      

      SELECT TOP 1 @cSuggestedLOC = Loc 
                  --, @nQTY         = Qty
                  , @cSuggToID    = ToID 
      FROM  @tSuggestedLoc
      WHERE LotAttribute = @cYearMonth
      AND SKU = @c_SKU 
      ORDER BY Qty, LogicalLocation 
   END

   --SELECT @cSuggestedLOC '@cSuggestedLOC' , @cSuggToID '@cSuggToID'   , @cLottable06 '@cLottable06' , @cYearMonth '@cYearMonth'  ,@cPAType '@cPAType'

   IF ISNULL(@cSuggestedLOC,'')  <> ''
   BEGIN
      
      -- Get QTY on suggest LOC
      --SELECT @nQTY = ISNULL( SUM( QTY), 0)
      --FROM RFPutaway WITH (NOLOCK) 
      --WHERE FromLOC = @c_FromLOC 
      --   AND FromID = @c_FromID 
      --   AND StorerKey = @c_StorerKey
      --   AND SKU = @c_SKU

      -- Get label
      SET @cLabelSuggID  = rdt.rdtgetmessage( 180011, @cLangCode, 'DSP')
      SET @cLabelSuggLOC = rdt.rdtgetmessage( 180012, @cLangCode, 'DSP')
      --SET @cLabelPAQTY   = rdt.rdtgetmessage( 57253, @cLangCode, 'DSP')

      
	
   	SET @c_oFieled01 = @cLabelSuggID    -- 'SUGGESTED ID:'
      SET @c_oFieled02 = @cSuggToID
      SET @c_oFieled03 = @cLabelSuggLOC   -- 'SUGGESTED LOC:'
      SET @c_oFieled04 = @cSuggestedLOC
      --SET @c_oFieled05 = @cLabelPAQTY     -- 'PUTAWAY QTY: '
      --SET @c_oFieled06 = CAST( @nQTY AS NVARCHAR(10))
   END
   ELSE
      -- Bypass suggest ID/LOC screen
      SET @nErrNo = -1 
END

SET QUOTED_IDENTIFIER OFF


SET QUOTED_IDENTIFIER OFF

GO