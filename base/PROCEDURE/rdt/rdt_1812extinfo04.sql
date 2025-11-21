SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtInfo04                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-02-02   Ung       1.0   WMS-3333 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtInfo04]
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

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nAfterStep = 4   -- SKU, QTY
      BEGIN
         -- Get task info
         DECLARE @nRowCount INT
         DECLARE @nUOMQTY  INT
         DECLARE @nTaskQTY INT
         DECLARE @nCS      INT
         DECLARE @nTotalCS INT
         DECLARE @cFromLOC NVARCHAR(10)
         
         SELECT 
            @nUOMQTY = UOMQTY, 
            @nTaskQTY = QTY, 
            @cFromLOC = FromLOC
         FROM TaskDetail WITH (NOLOCK) WHERE 
         TaskDetailKey = @cTaskDetailKey
         
         -- Bulk LOC
         IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND LocationType = 'OTHER')
         BEGIN 
            IF @nUOMQTY = 0
               SET @nUOMQTY = 1
            
            -- Cases needed
            SET @nTotalCS = @nTaskQTY / @nUOMQTY
            
            -- Cases taken
            SELECT @nCS = COUNT(1) FROM rdt.rdtFCPLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
            
            SET @cExtendedInfo1 = 'CASE: ' + CAST( @nCS AS NVARCHAR(5))  + '/' + CAST( @nTotalCS AS NVARCHAR(5))
         END
      END
   END
END

GO