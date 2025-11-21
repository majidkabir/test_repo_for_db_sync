SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_511ExtValid05                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: MAST custom move check                                            */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 2021-07-30  1.0  James      WMS-17576. Created                             */
/* 2022-01-13  1.1  James      Add new validation (james01)                   */
/* 2022-10-20  1.2  yeekung    WMS-21035 Add new condition (yeekung01)        */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_511ExtValid05] (
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

   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @bSuccess    INT
   DECLARE @cTransmitLogKey   NVARCHAR( 10) = ''

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 3 -- To LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF ISNULL( @cFromID, '') = ''
               GOTO Quit

            SELECT @cFacility = Facility
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'AGVDEFLoc'
                        AND   Code = @cFacility
                        AND   Long = @cToLOC
                        AND   Storerkey = @cStorerKey)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP CLP WITH (NOLOCK)
                        WHERE CLP.LISTNAME = 'AGVSKUCat'
                        AND   CLP.Storerkey = @cStorerKey
                        AND   CLP.Long IN('ALL','')) --(yeekung01)

               BEGIN
                  IF EXISTS (
                     SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.Sku = SKU.SKU)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   LLI.Id = @cFromID
                     AND   LOC.Facility = @cFacility
                     AND   NOT EXISTS (
                           SELECT 1 FROM dbo.CODELKUP CLP WITH (NOLOCK)
                           WHERE CLP.LISTNAME = 'AGVSKUCat'
                           AND   CLP.Storerkey = @cStorerKey
                           AND   CLP.Long = SKU.BUSR9))
                  BEGIN
                     SET @nErrNo = 172451
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotAllAGVGoods'
                     GOTO Quit
                  END
               END

               IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                               WHERE LISTNAME = 'CHKMVTOLOC'
                               AND   Storerkey = @cStorerKey
                               AND   Long = @cToLOC)
               BEGIN
                  SET @nErrNo = 172452
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid AGV Loc'
                  GOTO Quit
               END

               IF EXISTS ( SELECT 1 FROM dbo.ITRN WITH (NOLOCK)
                           WHERE SourceType = 'rdtfnc_Move_ID'
                           AND   StorerKey = @cStorerKey
                           AND   ToLoc = @cToLOC
                           AND   ToID = @cFromID
                           AND   [Status] = 'OK')
               BEGIN
                  SET @nErrNo = 172453
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Dup AGV ToId'
                  GOTO Quit
               END
            END
         END
      END
   END
   Quit:

GO