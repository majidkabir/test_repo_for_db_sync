SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtVFPADefFromLOC                                   */
/* Copyright: LF Logistics                                              */
/* Purpose: TM Putaway From module, default FromLOC logic               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2013-08-28 1.0  Ung      SOS256104 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFPADefFromLOC]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT, 
   @cTaskDetailKey NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF (SELECT TaskType FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey) = 'PAF'
      SET @nErrNo = 0
   ELSE
      SET @nErrNo = -1
END

GO