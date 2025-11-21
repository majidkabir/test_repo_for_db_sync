SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732ExtInfo02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show extended info from simple cc module                          */
/*                                                                            */
/* Called from : rdtfnc_SimpleCC                                              */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 01-Sep-2016  James     1.0   SOS375760 Created                             */
/* 17-Aug-2018  Ung       1.1   WMS-5995 Reorganize param                     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtInfo02]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cCCKey         NVARCHAR( 10), 
   @cCCSheetNo     NVARCHAR( 10),
   @cCountNo       NVARCHAR( 1),  
   @cLOC           NVARCHAR( 10), 
   @cSKU           NVARCHAR( 20), 
   @nQty           INT, 
   @cOption        NVARCHAR( 1),  
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTtlQty              INT,
           @nTotalQtyCounted     INT,
           @nTotalQtyCountNo1    INT,
           @nTotalQtyCountNo2    INT,
           @nTotalQtyCountNo3    INT,
           @nTotalSKUCounted     INT

   IF @nFunc = 731 -- Simple CC
   BEGIN
      IF @nStep = 2 -- LOC
      BEGIN
         SET @nTotalSKUCounted = 0
         SET @nTotalQtyCountNo1 = 0
         SET @nTotalQtyCountNo2 = 0
         SET @nTotalQtyCountNo3 = 0
         SET @nTotalQtyCounted = 0

         IF ISNULL(@cCountNo,'') = '1'
         BEGIN
            Select @nTotalQtyCountNo1 = Count(Distinct SKU)
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCKey
            AND Storerkey = @cStorerkey
            AND Loc = @cLoc
            AND Qty <> 0
            AND CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCSheetNo END         
         END
         ELSE IF ISNULL(@cCountNo,'') = '2'
         BEGIN
            Select @nTotalQtyCountNo2 = Count(Distinct SKU)
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCKey
            AND Storerkey = @cStorerkey
            AND Loc = @cLoc
            AND Qty_Cnt2 <> 0
            AND CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCSheetNo END
         END
         ELSE IF ISNULL(@cCountNo,'') = '3'
         BEGIN
            Select @nTotalQtyCountNo3 = Count(Distinct SKU)
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @cCCKey
            AND Storerkey = @cStorerkey
            AND Loc = @cLoc
            AND Qty_Cnt3 <> 0
            AND CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCSheetNo END         
         END

         SET @nTotalSKUCounted = 0
         SET @nTotalSKUCounted = @nTotalQtyCountNo1 + @nTotalQtyCountNo2 + @nTotalQtyCountNo3

         Select @nTotalQtyCounted = CASE WHEN @cCountNo = 1 THEN SUM(Qty)
                                         WHEN @cCountNo = 2 THEN SUM(Qty_Cnt2)
                                         WHEN @cCountNo = 3 THEN SUM(Qty_Cnt3)
                                    END
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCKey
         AND Storerkey = @cStorerkey
         AND Loc = @cLoc
         AND CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCSheetNo END    
      
         SET @cExtendedInfo = RTRIM( 'SKU:' + CAST( @nTotalSKUCounted AS NVARCHAR(5))) + 
                              ' / ' + 
                              RTRIM( 'QTY:' + CAST( @nTotalQtyCounted AS NVARCHAR(5)))
      END   -- Step2

      IF @nStep = 4 -- QTY
      BEGIN

         SELECT @nTtlQty = CASE WHEN @cCountNo = '1' THEN ISNULL( Sum( Qty), 0) 
                                WHEN @cCountNo = '2' THEN ISNULL( Sum( Qty_Cnt2), 0)
                                WHEN @cCountNo = '3' THEN ISNULL( Sum( Qty_Cnt3), 0)
                                ELSE 0 END
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND CCKey = @cCCKey
         AND Loc = @cLoc
         AND CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCSheetNo END
         AND 1 = CASE WHEN @cCountNo = '1' AND COUNTED_CNT1 = '1' THEN 1
                      WHEN @cCountNo = '2' AND COUNTED_CNT2 = '1' THEN 1
                      WHEN @cCountNo = '3' AND COUNTED_CNT3 = '1' THEN 1
                      ELSE 0 END
         GROUP BY CCKey, CCSheetNo, Loc

         SET @cExtendedInfo = 'TTL LOC QTY: ' + CAST( @nTtlQty AS NVARCHAR(5))
      END
   END
   
   Quit:
END

GO