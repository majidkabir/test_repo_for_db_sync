SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1797ExtInfo02                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2023-05-19  1.0  Ung      WMS-22528 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1797ExtInfo02] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cTaskdetailKey  NVARCHAR( 10),
   @tExtInfo        VariableTable READONLY,
   @cExtendedInfo   NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1797 -- TM putaway from
   BEGIN
      IF @nStep = 2 -- ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cStorerKey NVARCHAR( 15)
            DECLARE @cFromLOC   NVARCHAR( 10)
            DECLARE @cFromID    NVARCHAR( 18)
            DECLARE @nTotalUCC  INT
            DECLARE @cMsg       NVARCHAR( 20)

            -- Get task info
            SELECT 
               @cStorerKey = StorerKey, 
               @cFromLOC = FromLOC, 
               @cFromID = FromID
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey
            
            -- Get pallet info
            SELECT @nTotalUCC = COUNT( DISTINCT UCCNo)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND LOC = @cFromLOC 
               AND ID = @cFromID
               AND Status = '1' -- 1=Received
            
            SET @cMsg = rdt.rdtgetmessage( 201201, @cLangCode, 'DSP') --TOTAL UCC:

            SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + CAST( @nTotalUCC AS NVARCHAR( 5))
         END
      END
   END
   
Quit:

END

GO