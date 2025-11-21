SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry17                                       */
/*                                                                         */
/* Purpose:                                                                */
/* Scan case id display task info                                          */
/*                                                                         */
/* Modifications log:                                                      */
/* Date       Rev  Author   Purposes                                       */
/* 2022-08-03 1.0  Ung      WMS-20373 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_727Inquiry17] (
   @nMobile       INT,
   @nFunc         INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cOption       NVARCHAR( 1),
   @cParam1       NVARCHAR( 20),
   @cParam2       NVARCHAR( 20),
   @cParam3       NVARCHAR( 20),
   @cParam4       NVARCHAR( 20),
   @cParam5       NVARCHAR( 20),
   @cOutField01   NVARCHAR( 20) OUTPUT,
   @cOutField02   NVARCHAR( 20) OUTPUT,
   @cOutField03   NVARCHAR( 20) OUTPUT,
   @cOutField04   NVARCHAR( 20) OUTPUT,
   @cOutField05   NVARCHAR( 20) OUTPUT,
   @cOutField06   NVARCHAR( 20) OUTPUT,
   @cOutField07   NVARCHAR( 20) OUTPUT,
   @cOutField08   NVARCHAR( 20) OUTPUT,
   @cOutField09   NVARCHAR( 20) OUTPUT,
   @cOutField10   NVARCHAR( 20) OUTPUT,
   @cOutField11   NVARCHAR( 20) OUTPUT,
   @cOutField12   NVARCHAR( 20) OUTPUT,
   @nNextPage     INT           OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskDetailKey NVARCHAR( 10) = ''
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cTaskStatus    NVARCHAR( 10)

   SET @nErrNo = 0

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep IN (2, 3) -- Inquiry sub module, 2=param screen, 3=result screen
      BEGIN
         -- Parameter mapping
         IF @nStep = 2
            SET @cCaseID = @cParam1
         IF @nStep = 3
            SELECT @cCaseID = I_Field12 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Check blank
         IF @cCaseID = ''
         BEGIN
            SET @nErrNo = 189151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Case ID
            GOTO Quit
         END

         -- Get task
         SELECT TOP 1
            @cTaskDetailKey = TaskDetailKey,
            @cFromLOC = FromLOC,
            @cToLOC = ToLOC,
            @cTaskStatus = Status
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
            AND TaskType = 'RPF'
            AND CaseID = @cCaseID
         ORDER BY TaskDetailKey DESC

         SET @cOutField01 = 'CASE ID:'
         SET @cOutField02 = @cCaseID
         SET @cOutField03 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''

         IF @cTaskDetailKey = ''
         BEGIN
            SET @cOutField04 = '*** NO TASK ***'
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
         END
         ELSE
         BEGIN
            SET @cOutField04 = 'TO LOC: ' + @cToLOC
            SET @cOutField05 = 'FROM LOC: ' + @cFromLOC
            SET @cOutField06 = 'TASK: ' + @cTaskDetailKey
            SET @cOutField07 = 'STATUS: ' + @cTaskStatus
         END
         
      	IF @nStep = 2
            SET @nNextPage = 0  
      	IF @nStep = 3
            SET @nNextPage = -1
      END
   END

Quit:


GO