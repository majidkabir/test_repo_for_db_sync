SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP11                                      */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-07-25 1.0  Ung      WMS-13505 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP11] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF @nFunc = 1641 -- Pallet build
   BEGIN
      IF @nStep = 3 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get session info
            DECLARE @cFacility NVARCHAR(5)
            SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

            -- Get carton info
            DECLARE @dLottable14 DATETIME
            SELECT @dLottable14 = LA.Lottable14
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LLI.StorerKey = @cStorerKey 
               AND LOC.Facility = @cFacility
               AND LLI.ID = @cUCCNo

            -- Check carton valid
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 155701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CTN ID
               GOTO Quit
            END

            DECLARE @cISWBufferInWeek NVARCHAR(10)
            DECLARE @nISWBufferInWeek INT = 0
            SELECT @cISWBufferInWeek = ISNULL( Code, 0)
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'HMISW'
               AND StorerKey = @cStorerKey

            IF rdt.rdtIsInteger( @cISWBufferInWeek) = 1
               SET @nISWBufferInWeek = CAST( @cISWBufferInWeek AS INT)

            IF @nISWBufferInWeek > 0
            BEGIN
               -- Check ISW must > 2 weeks from today
               IF DATEDIFF( ww, GETDATE(), @dLottable14) <= @nISWBufferInWeek
               BEGIN
                  SET @nErrNo = 155702
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TooCloseTo ISW
                  GOTO Quit
               END
            END
            
            -- Get other carton on pallet
            DECLARE @cOtherUCCNo NVARCHAR( 20)
            SELECT TOP 1
               @cOtherUCCNo = DID.ChildID
            FROM DropID D WITH (NOLOCK)
               JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (D.DropID = DID.DropID)
            WHERE D.DropID = @cDropID
            
            -- Pallet with existing carton
            IF @@ROWCOUNT > 0
            BEGIN
               -- Get other L14
               DECLARE @dOtherLottable14 DATETIME
               SELECT @dOtherLottable14 = LA.Lottable14
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                  JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
               WHERE LLI.StorerKey = @cStorerKey 
                  AND LOC.Facility = @cFacility
                  AND LLI.ID = @cOtherUCCNo
            
               -- Check same Lottable41
               IF @dLottable14 <> @dOtherLottable14
               BEGIN
                  SET @nErrNo = 155703
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot mix ISW
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO