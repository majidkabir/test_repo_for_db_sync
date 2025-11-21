SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_JACKWExtValid03                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate To ID must start with #1 and 4 digits              */
/*                                                                      */
/* Called from: rdtfnc_TM_DynamicPicking                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-10-03  1.0  James       Created                                 */  
/************************************************************************/

CREATE PROC [RDT].[rdt_JACKWExtValid03] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cTaskStorer     NVARCHAR( 15), 
   @cTaskDetailKey  NVARCHAR( 10), 
   @cToID           NVARCHAR( 18), 
   @cFromLoc        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cToLoc          NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20), 
   @cCaseID         NVARCHAR( 20), 
   @nQty            INT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 1 AND @nInputKey = 1 AND ISNULL( @cToID, '') <> ''
   BEGIN
      IF SUBSTRING( @cToID, 1, 1) <> '1'
         SET @cErrMsg = 'ID START WITH #1'

      IF LEN( RTRIM( @cToID)) <> 4
         SET @cErrMsg = 'ID MUST BE 4 DIGITS'

      GOTO Quit
   END

   IF @nStep = 8 AND @nInputKey = 1 AND ISNULL( @cToLOC, '') <> ''
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK) 
                      WHERE ListName = 'WCSROUTE' 
                      AND   Code = 'CASE'
                      AND   Short = @cToLOC) 
      BEGIN
         SET @cErrMsg = 'Invalid Spur LOC'
         GOTO Quit
      END
   END
Quit:
END

GO