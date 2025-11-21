SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_732ExtVal01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate if SKU not in loc for ccdetail                     */
/*          validate countqty cannot more than systemqty                */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 27-06-2018  1.0  James       WMS5140. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtVal01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cCCKey       NVARCHAR( 10) 
   ,@cCCSheetNo   NVARCHAR( 10)
   ,@cCountNo     NVARCHAR( 1)  
   ,@cLOC         NVARCHAR( 10) 
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@cOption      NVARCHAR( 1)  
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSystemQty INT,
           @nCountQty  INT

   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @nStep = 4  -- SKU, QTY
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   CCKey = @cCCKey
                         AND   LOC = @cLoc
                         AND   SKU = @cSKU)
         BEGIN    
            SET @nErrNo = 125601   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in Loc 
            GOTO Quit
         END 

         SELECT @nSystemQty = ISNULL( SUM( SystemQty), 0),
                @nCountQty = CASE
                  WHEN @cCountNo = '1' THEN ISNULL( SUM( Qty), 0)
                  WHEN @cCountNo = '2' THEN ISNULL( SUM( Qty_Cnt2), 0)
                  WHEN @cCountNo = '3' THEN ISNULL( SUM( Qty_Cnt3), 0)
                ELSE 0 END         
         FROM dbo.CCDetail WITH (NOLOCK) 
         WHERE CCKey = @cCCKey
         AND   LOC = @cLoc

         IF @nSystemQty = @nCountQty
            GOTO Quit

         -- Check if scanned qty > system qty in ccdetail then prompt error
         IF @nSystemQty < @nCountQty + @nQTY
         BEGIN
            SET @nErrNo = 125602   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Count 
            GOTO Quit
         END         
      END
   END

Quit:
END

GO