SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 15-Apr-2015  Ung       1.0   SOS335126 Created                             */
/* 17-Aug-2018  Ung       1.1   WMS-5995 Reorganize param                     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtInfo01]
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

   DECLARE @nTtlQty INT

   IF @nFunc = 732 -- Simple CC
   BEGIN
      IF @nStep = 3 -- SKU Info
      BEGIN
         SET @cExtendedInfo = ''
         GOTO Quit
      END

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

         SET @cExtendedInfo = 'TTL Record: ' + CAST( @nTtlQty AS NVARCHAR(5))
      END
   END
   
   Quit:
END

GO