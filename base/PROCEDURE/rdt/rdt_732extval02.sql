SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_732ExtVal02                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate if LOC + SKU count QTY > system qty                */
/*          Prompt error in msg queue                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 13-07-2018  1.0  Ung         WMS-5664 Created                        */
/* 12-10-2018  1.2  Ung         WMS-6656 Add NewStock, ExcessStock      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtVal02]
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

   DECLARE @nSystemQTY INT
   DECLARE @nCountQTY  INT
   DECLARE @cErrMsg1   NVARCHAR( 20)
   DECLARE @cErrMsg2   NVARCHAR( 20)
   DECLARE @cErrMsg3   NVARCHAR( 20)

   IF @nStep = 4 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get all QTY
         SELECT @nSystemQTY = ISNULL( SUM( SystemQTY), 0)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCKey
            AND StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND SKU = @cSKU

         -- Get counted QTY
         SELECT 
            @nCountQTY = 
               CASE
                  WHEN @cCountNo = '1' THEN ISNULL( SUM( Qty), 0)
                  WHEN @cCountNo = '2' THEN ISNULL( SUM( Qty_Cnt2), 0)
                  WHEN @cCountNo = '3' THEN ISNULL( SUM( Qty_Cnt3), 0)
                  ELSE 0 
               END
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCKey
            AND StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND ((@cCountNo = 1 AND Counted_Cnt1 = '1') OR
                 (@cCountNo = 2 AND Counted_Cnt2 = '1') OR
                 (@cCountNo = 3 AND Counted_Cnt3 = '1'))

         -- Check new SKU
         IF @nSystemQTY = 0
         BEGIN
            DECLARE @cNewStock NVARCHAR(1)
            SET @cNewStock = rdt.RDTGetConfig( @nFunc, 'NewStock', @cStorerkey)

            IF @cNewStock IN ('1', '2')
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 126801, @cLangCode, 'DSP') --NEW SKU
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1

               IF @cNewStock = '1'
                  SET @nErrNo = 0 -- Just warning, not stopping
               
               IF @cNewStock = '2'
                  SET @nErrNo = 1 -- Stopping error

               GOTO Quit
            END
         END

         -- Check physical more than system
         IF (@nCountQTY + @nQTY) > @nSystemQTY AND @nSystemQTY > 0
         BEGIN
            DECLARE @cExcessStock NVARCHAR(1)
            SET @cExcessStock = rdt.RDTGetConfig( @nFunc, 'ExcessStock', @cStorerkey)
          
            IF @cExcessStock IN ('1', '2')
            BEGIN
               SET @cErrMsg1 = rdt.rdtgetmessage( 126802, @cLangCode, 'DSP') --PHYSICAL MORE THAN
               SET @cErrMsg2 = rdt.rdtgetmessage( 126803, @cLangCode, 'DSP') --SYSTEM

               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            
               IF @cExcessStock = '1'
                  SET @nErrNo = 0 -- Just warning, not stopping
               
               IF @cExcessStock = '2'
                  SET @nErrNo = 1 -- Stopping error
            END

            GOTO Quit
         END
      END
   END

Quit:

END

GO