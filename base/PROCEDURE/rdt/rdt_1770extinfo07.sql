SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtInfo07                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-08-30   Ung       1.0   WMS-26055 Created                       */
/* 2024-11-11   PXL009    1.1   FCR-1124 Merged 1.0 from v0 branch      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1770ExtInfo07]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nAfterStep = 4 -- TO LOC
      BEGIN
         DECLARE @cStorerKey     NVARCHAR( 15)
         DECLARE @cTaskType      NVARCHAR( 10)
         DECLARE @cOrderKey      NVARCHAR( 15)
         DECLARE @cConsigneeKey  NVARCHAR( 15)

         -- Get TaskDetail info
         SELECT
            @cStorerKey = StorerKey,
            @cTaskType = TaskType
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Get order info (1 pallet 1 order)
         SELECT TOP 1
            @cOrderKey = O.OrderKey,
            @cConsigneeKey = ISNULL( O.ConsigneeKey, '')
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE PD.TaskDetailKey = @cTaskDetailKey

         /*
            To LOC is the outbound door location
            Drop ID is the outbound lane ID (1 door multiple lanes)
         */

         -- Get order's lane
         DECLARE @cSuggDropID NVARCHAR( 20) = ''
         SELECT TOP 1
            @cSuggDropID = TD.DropID
         FROM dbo.TaskDetail TD WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)
         WHERE PD.OrderKey = @cOrderKey
            AND TD.StorerKey = @cStorerKey
            AND TD.TaskType = @cTaskType
            AND TD.Status = '9'

         -- Order not yet have lane (first pallet)
         IF @cSuggDropID = ''
            -- Suggest lane as abbreviated company name
            SELECT @cSuggDropID = LEFT( Long, 20)
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'RDTCSTCODE'
               AND Code = @cConsigneeKey
               AND StorerKey = @cStorerKey

         SET @cExtendedInfo1 = @cSuggDropID
      END
   END
END

GO