SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggID01                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Retrieve booked ID and LOC from receiving                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-09-2015  1.0  Ung         SOS350420 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggID01] (
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

   DECLARE @cSuggID  NVARCHAR(18)
   DECLARE @cSuggLOC NVARCHAR(10)
   DECLARE @nQTY INT
   
   DECLARE @cLabelSuggID  NVARCHAR(20)
   DECLARE @cLabelSuggLOC NVARCHAR(20)
   DECLARE @cLabelPAQTY   NVARCHAR(20)
  
   SET @cSuggID = ''
   SET @cSuggLOC = ''
   
   SELECT 
      @cSuggID = ID, 
      @cSuggLOC = SuggestedLOC 
   FROM RFPutaway WITH (NOLOCK) 
   WHERE FromLOC = @c_FromLOC 
      AND FromID = @c_FromID 
      AND StorerKey = @c_StorerKey
      AND SKU = @c_SKU

   IF @cSuggLOC <> ''
   BEGIN
      -- Get QTY on suggest LOC
      SELECT @nQTY = ISNULL( SUM( QTY), 0)
      FROM RFPutaway WITH (NOLOCK) 
      WHERE FromLOC = @c_FromLOC 
         AND FromID = @c_FromID 
         AND StorerKey = @c_StorerKey
         AND SKU = @c_SKU

      -- Get label
      SET @cLabelSuggID  = rdt.rdtgetmessage( 57251, @cLangCode, 'DSP')
      SET @cLabelSuggLOC = rdt.rdtgetmessage( 57252, @cLangCode, 'DSP')
      SET @cLabelPAQTY   = rdt.rdtgetmessage( 57253, @cLangCode, 'DSP')
	
   	SET @c_oFieled01 = @cLabelSuggID    -- 'SUGGESTED ID:'
      SET @c_oFieled02 = @cSuggID
      SET @c_oFieled03 = @cLabelSuggLOC   -- 'SUGGESTED LOC:'
      SET @c_oFieled04 = @cSuggLOC
      SET @c_oFieled05 = @cLabelPAQTY     -- 'PUTAWAY QTY: '
      SET @c_oFieled06 = CAST( @nQTY AS NVARCHAR(10))
   END
   ELSE
      -- Bypass suggest ID/LOC screen
      SET @nErrNo = -1 
END

GO