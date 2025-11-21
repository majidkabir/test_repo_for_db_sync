SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1816ExtInfo01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-03-04   Ung       1.0   SOS332730 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1816ExtInfo01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nAfterStep      INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@cExtendedInfo   NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM assist NMV
   IF @nFunc = 1816
   BEGIN
      IF @nAfterStep = 1 -- FinalLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cPickMethod NVARCHAR(10)
            DECLARE @cCCKey      NVARCHAR(10)

            -- Get task info
            SELECT
               @cPickMethod = PickMethod,
               @cCCKey = LEFT( SourceKey, 10)
            FROM TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey

            -- Check OrderKey
            IF @cPickMethod = 'CC' AND @cCCKey <> ''
            BEGIN
               DECLARE @nRowCount INT
               SET @nRowCount = 0

               -- Get remaining pallet not yet call out
               SELECT @nRowCount = COUNT(1)
               FROM TaskDetail WITH (NOLOCK)
               WHERE TaskType = 'ASRSCC'
                  AND Status = '1'
                  AND SourceKey = @cCCKey

               SET @cExtendedInfo = 'CC:' + RTRIM( @cCCKey) + ' BL:' + CAST( @nRowCount AS NVARCHAR(5))
            END

            IF @cPickMethod = 'NMV'
            BEGIN
               SET @cExtendedInfo = 'NON INVENTORY PLT'
            END
         END
      END
   END

Quit:

END

GO