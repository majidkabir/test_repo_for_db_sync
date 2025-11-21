SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732ExtInfo03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date        Author     Ver.  Purposes                                      */
/* 13-07-2018  Ung        1.0   WMS-5664 Created                              */
/* 2018-08-17  Ung        1.1   WMS-5995 Add last LOC message                 */
/*                              Reorganize param                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtInfo03]
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

   DECLARE @nScan  INT
   DECLARE @nTotal INT
   DECLARE @cMsg   NVARCHAR( 20)

   IF @nFunc = 732 -- Simple CC
   BEGIN
      IF @nStep = 3 -- SKU Info
      BEGIN
         SET @cExtendedInfo = ''
         GOTO Quit
      END

      IF @nStep = 4 OR -- QTY
         @nStep = 7    -- SKIP LOC?
      BEGIN
         IF @nAfterStep = 1 -- CCREF
         BEGIN
            SET @cMsg = rdt.rdtgetmessage( 128001, @cLangCode, 'DSP') --REACH LAST LOC
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cMsg
            SET @nErrNo = 0
         END

         IF @nAfterStep = 4 -- QTY
         BEGIN
            SELECT 
               @nTotal = ISNULL( SUM( SystemQty), 0),
               @nScan = CASE WHEN @cCountNo = '1' THEN ISNULL( Sum( Qty), 0) 
                             WHEN @cCountNo = '2' THEN ISNULL( Sum( Qty_Cnt2), 0)
                             WHEN @cCountNo = '3' THEN ISNULL( Sum( Qty_Cnt3), 0)
                             ELSE 0 
                        END
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerkey
            AND CCKey = @cCCKey
            AND Loc = @cLoc
            AND CCSheetNo = CASE WHEN @cCCSheetNo <> '' THEN @cCCSheetNo ELSE CCSheetNo END

            SET @cMsg = rdt.rdtgetmessage( 128002, @cLangCode, 'DSP') --SCAN/TOTAL:

            SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + --SCAN/TOTAL: 
               CAST( @nScan AS NVARCHAR(4)) + '/' + 
               CAST( @nTotal AS NVARCHAR(4))
         END
      END
   END
   
Quit:

END

GO