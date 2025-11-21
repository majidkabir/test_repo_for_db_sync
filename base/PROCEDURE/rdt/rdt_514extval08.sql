SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_514ExtVal08                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Nike KR custom move check                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2021-08-02  1.0  James    WMS-17563. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_514ExtVal08] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cToID          NVARCHAR( 18),
   @cToLoc         NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cUCC           NVARCHAR( 20),
   @cUCC1          NVARCHAR( 20),
   @cUCC2          NVARCHAR( 20),
   @cUCC3          NVARCHAR( 20),
   @cUCC4          NVARCHAR( 20),
   @cUCC5          NVARCHAR( 20),
   @cUCC6          NVARCHAR( 20),
   @cUCC7          NVARCHAR( 20),
   @cUCC8          NVARCHAR( 20),
   @cUCC9          NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cOPSPosition   NVARCHAR( 60)
   
   SELECT
      @cFacility = Facility, 
      @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cOPSPosition = OPSPosition 
   FROM rdt.RDTUser WITH (NOLOCK) 
   WHERE UserName = @cUserName

   IF @nFunc = 514 -- Move by UCC
   BEGIN
      IF @nStep = 1 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOPSPosition = 'B2C'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                           JOIN dbo.UCC UCC WITH (NOLOCK) ON ( LLI.Lot = UCC.Lot AND LLI.Loc = UCC.Loc)
                           JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
                           WHERE UCC.UCCNo = @cUCC
                           AND   LOC.Facility = @cFacility
                           AND   LA.Lottable02 IN ('01000','02000')
                           GROUP BY UCC.UCCNo
                           HAVING ISNULL( SUM( LLI.Qty), 0) > 0)
               BEGIN
                  SET @nErrNo = 172751  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DifLottableUCC  
                  GOTO Quit
               END
            END

            IF @cOPSPosition = 'B2B'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                           JOIN dbo.UCC UCC WITH (NOLOCK) ON ( LLI.Lot = UCC.Lot AND LLI.Loc = UCC.Loc)
                           JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
                           WHERE UCC.UCCNo = @cUCC
                           AND   LOC.Facility = @cFacility
                           AND   LA.Lottable02 NOT IN ('01000','02000')
                           GROUP BY UCC.UCCNo
                           HAVING ISNULL( SUM( LLI.Qty), 0) > 0)
               BEGIN
                  SET @nErrNo = 172752  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DifLottableUCC  
                  GOTO Quit
               END
            END
         END
      END
      
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOPSPosition = 'B2C'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.LOC LOC WITH (NOLOCK)
                           WHERE LOC.Facility = @cFacility
                           AND   LOC.LOC = @cToLOC
                           AND   LOC.LocationFlag = 'HOLD'
                           AND   NOT EXISTS ( SELECT 1 
                                              FROM dbo.CODELKUP CLP WITH (NOLOCK) 
                                              WHERE CLP.LISTNAME = 'NonITFLoc' 
                                              AND   LOC.LocationCategory = CLP.Code
                                              AND   CLP.Storerkey = @cStorerKey))
               BEGIN
                  SET @nErrNo = 172753  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff HOLD Loc  
                  GOTO Quit
               END
            END

            IF @cOPSPosition = 'B2B'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.LOC LOC WITH (NOLOCK)
                           WHERE LOC.Facility = @cFacility
                           AND   LOC.LOC = @cToLOC
                           AND   LOC.LocationFlag = 'HOLD'
                           AND   EXISTS ( SELECT 1 
                                          FROM dbo.CODELKUP CLP WITH (NOLOCK) 
                                          WHERE CLP.LISTNAME = 'NonITFLoc' 
                                          AND   LOC.LocationCategory = CLP.Code
                                          AND   CLP.Storerkey = @cStorerKey))
               BEGIN
                  SET @nErrNo = 172754  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff HOLD Loc  
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO