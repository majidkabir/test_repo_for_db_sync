SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1812ExtInfo10                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date         Author    Ver.  Purposes                                */
/* 2024-09-18   James     1.0   WMS-26122. Created                      */
/* 2024-10-27   James     1.1   Change DropID->CaseID mapping (james01) */
/* 2024-11-11   PXL009    1.2   FCR-1125 Merged 1.0, 1.1 from v0 branch */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1812ExtInfo10]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDropID NVARCHAR( 20)

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
   	IF @nAfterStep = 4
   	BEGIN
         SELECT @cDropID = CaseID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         SET @cExtendedInfo1 = @cDropID
   	END
   END
END

GO