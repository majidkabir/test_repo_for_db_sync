SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1836ExtVal01                                    */
/* Purpose: Extended Val                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2025-01-24   Dennis   1.0.0  FCR-2517 Created                        */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1836ExtVal01
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cTaskdetailKey  NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10),  
   @nErrNo          INT             OUTPUT,  
   @cErrMsg         NVARCHAR( 1024) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1836
   BEGIN
      IF @nStep = 0 -- init
      BEGIN
         IF NOT EXISTS(
            SELECT 1
            FROM dbo.TaskDetail TD WITH(NOLOCK)
            INNER JOIN dbo.CODELKUP CK WITH(NOLOCK) ON CK.Code = TD.TOLOC
            WHERE TD.TaskDetailKey = @cTaskDetailKey
            AND listname = 'DICSEPKMTD'
         )
         BEGIN
            SET @nErrNo = 155952
            SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, @cLangCode, 'DSP') --Tasks should be Replenished to Pick face.
            GOTO Quit
         END
      END
   END

Quit:
END

GO