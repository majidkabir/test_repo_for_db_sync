SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_511ExtValid06                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: UA custom move check                                              */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 2021-08-02  1.0  James      WMS-17562. Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_511ExtValid06] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 18),    
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
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

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 1 -- From Id
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOPSPosition = 'B2C'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                           JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
                           WHERE LLI.Id = @cFromID
                           AND   LOC.Facility = @cFacility
                           AND   LA.Lottable02 IN ('01000','02000')
                           GROUP BY LLI.Id
                           HAVING ISNULL( SUM( LLI.Qty), 0) > 0)
               BEGIN
                  SET @nErrNo = 172701  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DiffLottableID  
                  GOTO Quit
               END
            END

            IF @cOPSPosition = 'B2B'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                           JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
                           WHERE LLI.Id = @cFromID
                           AND   LOC.Facility = @cFacility
                           AND   LA.Lottable02 NOT IN ('01000','02000')
                           GROUP BY LLI.Id
                           HAVING ISNULL( SUM( LLI.Qty), 0) > 0)
               BEGIN
                  SET @nErrNo = 172702  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DiffLottableID  
                  GOTO Quit
               END
            END
         END
      END
      
      IF @nStep = 3
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
                  SET @nErrNo = 172703  
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
                  SET @nErrNo = 172704  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff HOLD Loc  
                  GOTO Quit
               END
            END
         END
      END
      Quit:
   END

GO