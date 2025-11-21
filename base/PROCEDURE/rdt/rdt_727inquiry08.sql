SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry08                                       */
/*                                                                         */
/* Purpose:                                                                */
/* -Scan pallet id display floor value                                     */
/*                                                                         */
/* Modifications log:                                                      */
/* Date       Rev  Author   Purposes                                       */
/* 2021-06-30 1.0  James    WMS-17018. Created                             */
/* 2023-09-14 1.1  James    WMS-23578 Add display system qty (james01)     */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_727Inquiry08] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @cOutField01  NVARCHAR(20) OUTPUT,
   @cOutField02  NVARCHAR(20) OUTPUT,
   @cOutField03  NVARCHAR(20) OUTPUT,
   @cOutField04  NVARCHAR(20) OUTPUT,
   @cOutField05  NVARCHAR(20) OUTPUT,
   @cOutField06  NVARCHAR(20) OUTPUT,
   @cOutField07  NVARCHAR(20) OUTPUT,
   @cOutField08  NVARCHAR(20) OUTPUT,
   @cOutField09  NVARCHAR(20) OUTPUT,
   @cOutField10  NVARCHAR(20) OUTPUT,
   @cOutField11  NVARCHAR(20) OUTPUT,
   @cOutField12  NVARCHAR(20) OUTPUT,
   @nNextPage    INT          OUTPUT,
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLoc         NVARCHAR( 10)
   DECLARE @cTaskStatus    NVARCHAR( 10)
   DECLARE @cText4Floor    NVARCHAR( 20)
   DECLARE @cFloor         NVARCHAR( 3)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cNotes1        NVARCHAR( 20)
   DECLARE @fPrice         FLOAT
   DECLARE @nSystemQty     INT
      
   SET @nErrNo = 0

   SELECT @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep IN ( 2, 3)
   BEGIN
      SET @cFromID = @cParam1

      IF @cFromID = ''
      BEGIN
         SET @nErrNo = 169851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Req
         GOTO QUIT
      END

      IF @nStep = 2
         SET @cTaskDetailKey = ''
      ELSE
         SET @cTaskDetailKey = @cOutField05

      SELECT TOP 1
         @cTaskDetailKey = TD.TaskDetailKey,
         @cToLoc = TD.ToLoc,
         @cTaskStatus = TD.Status,
         @nSystemQty = TD.SystemQty
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      WHERE TD.FromId = @cFromID
      AND   TD.Storerkey = @cStorerKey
      AND   TD.TaskType = 'ASTPA'
      AND   (( @cTaskDetailKey <> '' AND TD.TaskDetailKey > @cTaskDetailKey) OR ( TD.TaskDetailKey = TaskDetailKey))
      ORDER BY 1 DESC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @cText4Floor = '**NOT FOUND**'
         SET @cToLoc = ''
         SET @cFloor = ''
         GOTO DISPLAY
      END
      ELSE IF @cTaskStatus = '9'
      BEGIN
         SET @cText4Floor = '** NO TASK **'
         SET @cToLoc = ''
         SET @cFloor = ''
         GOTO DISPLAY
      END
      ELSE
      BEGIN
         SELECT @cFloor = [Floor]
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
         AND   Loc = @cToLoc

         SET @cToLoc = @cToLoc
         SET @cText4Floor = ''
         GOTO DISPLAY
      END

   END

   DISPLAY:
   BEGIN
      SELECT TOP 1
         @cSKU = SKU.Sku,
         @cNotes1 = SKU.NOTES1,
         @fPrice = SKU.Price
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( SKU.StorerKey = LLI.StorerKey AND SKU.Sku = LLI.Sku)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.Id = @cFromID
      ORDER BY 1

      SET @cOutField01 = 'ID:'
      SET @cOutField02 = @cFromID
      SET @cOutField03 = 'Floor:' + CASE WHEN @cFloor <> '' THEN @cFloor ELSE @cText4Floor END + 
                          '/' + 
                          CAST( @nSystemQty AS NVARCHAR( 4))
      SET @cOutField04 = 'Loc  :' + @cToLoc
      SET @cOutField05 = 'Task :' + @cTaskDetailKey
      SET @cOutField06 = 'SKU  :'
      SET @cOutField07 =  @cSKU
      SET @cOutField08 = 'Price:' + CAST( @fPrice AS NVARCHAR( 5))
      SET @cOutField09 = 'Notes:' + @cNotes1
   END

   SET @nNextPage = 0

QUIT:

GO