SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_610ExtInfo01                                    */
/*                                                                      */
/* Purpose: Prompt sku packkey                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-02-05  1.0  James       WMS-11865. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_610ExtInfo01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cCCRefNo       NVARCHAR( 10),
   @cCCSheetNo     NVARCHAR( 10),
   @nCCCountNo     INT,
   @cZone1         NVARCHAR( 10),
   @cZone2         NVARCHAR( 10),
   @cZone3         NVARCHAR( 10),
   @cZone4         NVARCHAR( 10),
   @cZone5         NVARCHAR( 10),
   @cAisle         NVARCHAR( 10),
   @cLevel         NVARCHAR( 10),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),  
   @cUCC           NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cLottable01    NVARCHAR( 18),  
   @cLottable02    NVARCHAR( 18),  
   @cLottable03    NVARCHAR( 18),  
   @dLottable04    DATETIME,  
   @dLottable05    DATETIME, 
   @tExtValidate   VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPackKey          NVARCHAR( 10)
   DECLARE @nTotalLoc         INT
   DECLARE @nTotalCountedLoc  INT
   
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nTotalLoc = COUNT( DISTINCT LOC)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = @cCCSheetNo
      
         SELECT @nTotalCountedLoc = COUNT( DISTINCT LOC)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = @cCCSheetNo
         AND   (( @nCCCountNo = 1 AND Counted_Cnt1 = '1') OR ( @nCCCountNo <> 1 AND Counted_Cnt1 = Counted_Cnt1))
         AND   (( @nCCCountNo = 2 AND Counted_Cnt2 = '1') OR ( @nCCCountNo <> 2 AND Counted_Cnt2 = Counted_Cnt2))
         AND   (( @nCCCountNo = 3 AND Counted_Cnt3 = '1') OR ( @nCCCountNo <> 3 AND Counted_Cnt3 = Counted_Cnt3))
      
         --SET @cExtendedInfo = '# Of Records: ' + '1'--CAST( @nTotalCountedLoc AS NVARCHAR( 2)) + '/' + CAST( @nTotalLoc AS NVARCHAR( 2))
         SET @cExtendedInfo = '# Records: ' + CAST( @nTotalCountedLoc AS NVARCHAR( 3)) + '/' + CAST( @nTotalLoc AS NVARCHAR( 3))
      END  
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 0
      BEGIN
         SELECT @nTotalLoc = COUNT( DISTINCT LOC)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = @cCCSheetNo
      
         SELECT @nTotalCountedLoc = COUNT( DISTINCT LOC)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   CCSheetNo = @cCCSheetNo
         AND   (( @nCCCountNo = 1 AND Counted_Cnt1 = '1') OR ( @nCCCountNo <> 1 AND Counted_Cnt1 = Counted_Cnt1))
         AND   (( @nCCCountNo = 2 AND Counted_Cnt2 = '1') OR ( @nCCCountNo <> 2 AND Counted_Cnt2 = Counted_Cnt2))
         AND   (( @nCCCountNo = 3 AND Counted_Cnt3 = '1') OR ( @nCCCountNo <> 3 AND Counted_Cnt3 = Counted_Cnt3))
      
         --SET @cExtendedInfo = '# Of Records: ' + '1'--CAST( @nTotalCountedLoc AS NVARCHAR( 2)) + '/' + CAST( @nTotalLoc AS NVARCHAR( 2))
         SET @cExtendedInfo = '# Records: ' + CAST( @nTotalCountedLoc AS NVARCHAR( 3)) + '/' + CAST( @nTotalLoc AS NVARCHAR( 3))
      END  
   END

   IF @nStep in ( 14, 26) -- Add SKU Qty
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cPackKey = PackKey
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         
         SET @cExtendedInfo = @cPackKey
      END
   END


   Quit:

END

GO