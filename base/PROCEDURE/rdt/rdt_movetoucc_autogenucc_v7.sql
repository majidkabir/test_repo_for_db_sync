SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveToUCC_AutoGenUCC_V7                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate UCC                                           */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2023-01-30  1.0  Ung       WMS-21506 Created                         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_MoveToUCC_AutoGenUCC_V7]
   @nMobile     INT,
   @nFunc       INT,
   @nStep       INT,
   @nInputKey   INT,
   @cLangCode   NVARCHAR( 3),
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cAutoGenUCC NVARCHAR( 20),
   @cFromLOC    NVARCHAR( 10),
   @cFromID     NVARCHAR( 18),
   @cSKU        NVARCHAR( 20),
   @nQTY        INT,
   @cUCC        NVARCHAR( 20),
   @cToID       NVARCHAR( 18),
   @cToLOC      NVARCHAR( 10),
   @cOption     NVARCHAR( 1),
   @cAutoUCCNo  NVARCHAR( 20) OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cAutoUCCNo = ''

   IF @cAutoGenUCC = '1'
   BEGIN
      DECLARE @b_success INT
      
      WHILE (1=1)
      BEGIN
         -- Generate new UCCNo
         SET @b_success = 0
         EXECUTE dbo.nspg_GetKey
            'UCCNo',
            20 ,
            @cAutoUCCNo OUTPUT,
            @b_success  OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 195951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AutoUCCNo Fail
            GOTO Fail
         END
         
         -- Retry if UCCNo already exist
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cAutoUCCNo)
            BREAK
      END
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cAutoGenUCC AND type = 'P')
      BEGIN
         DECLARE @cSQL NVARCHAR(MAX)
         DECLARE @cSQLParam NVARCHAR(MAX)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cAutoGenUCC) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, ' +
            ' @cAutoGenUCC, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @cOption, ' +
            ' @cAutoUCCNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile     INT,          ' +
            '@nFunc       INT,          ' +
            '@nStep       INT,          ' +
            '@nInputKey   INT,          ' +
            '@cLangCode   NVARCHAR( 3), ' +
            '@cStorerKey  NVARCHAR(15), ' +
            '@cFacility   NVARCHAR(5),  ' +
            '@cAutoGenUCC NVARCHAR(20), ' +
            '@cFromLOC    NVARCHAR(10), ' +
            '@cFromID     NVARCHAR(18), ' +
            '@cSKU        NVARCHAR(20), ' +
            '@nQTY        INT,          ' +
            '@cUCC        NVARCHAR(20), ' +
            '@cToID       NVARCHAR(18), ' +
            '@cToLOC      NVARCHAR(10), ' +
            '@cOption     NVARCHAR( 1), ' +
            '@cAutoUCCNo  NVARCHAR(18)  OUTPUT, ' +
            '@nErrNo      INT           OUTPUT, ' +
            '@cErrMsg     NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility,
            @cAutoGenUCC, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @cOption,
            @cAutoUCCNo OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
      END
   END

Fail:
END


GO