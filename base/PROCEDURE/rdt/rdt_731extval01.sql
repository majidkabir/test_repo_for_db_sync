SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_731ExtVal01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate if LOC + SKU count QTY <> system qty               */
/*          Prompt error in msg queue                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 21-04-2016  1.0  James       SOS368587. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_731ExtVal01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cCCKey       NVARCHAR( 10) 
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

   DECLARE @cErrMsg1    NVARCHAR( 20),
           @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20),
           @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20)
               
   IF @nStep = 4 -- SKU, QTY
   BEGIN
      IF @nInputKey = 0 -- ESC
      BEGIN
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

         -- Check if scanned qty <> system qty in ccdetail then prompt error
         IF @nSystemQty > @nCountQty
         BEGIN
            SET @nErrNo = 0

            SET @cErrMsg1 = rdt.rdtgetmessage( 99151, @cLangCode, 'DSP') --Counted qty  
            SET @cErrMsg2 = rdt.rdtgetmessage( 99152, @cLangCode, 'DSP') --Less than 
            SET @cErrMsg3 = rdt.rdtgetmessage( 99153, @cLangCode, 'DSP') --System qty             

            SET @cErrMsg1 = SUBSTRING( @cErrMsg1, 7, 14)
            SET @cErrMsg2 = SUBSTRING( @cErrMsg2, 7, 14)
            SET @cErrMsg3 = SUBSTRING( @cErrMsg3, 7, 14)            

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3

            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END
            
            SET @nErrNo = 0

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 0

            SET @cErrMsg1 = rdt.rdtgetmessage( 99154, @cLangCode, 'DSP') --Counted qty  
            SET @cErrMsg2 = rdt.rdtgetmessage( 99155, @cLangCode, 'DSP') --More than 
            SET @cErrMsg3 = rdt.rdtgetmessage( 99156, @cLangCode, 'DSP') --System qty             

            SET @cErrMsg1 = SUBSTRING( @cErrMsg1, 7, 14)
            SET @cErrMsg2 = SUBSTRING( @cErrMsg2, 7, 14)
            SET @cErrMsg3 = SUBSTRING( @cErrMsg3, 7, 14)            

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3

            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END
            
            SET @nErrNo = 0

            GOTO Quit
         END         
      END
   END

Quit:
END

GO