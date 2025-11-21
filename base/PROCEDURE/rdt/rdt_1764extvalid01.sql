SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764ExtValid01                                        */
/* Purpose: Validate cannot over replen if replen task from DPP               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2021-02-25   James     1.0   WMS-16271. Created                            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtValid01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
   ,@cDropID         NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cSuggSKU          NVARCHAR( 20)
   DECLARE @cSuggFromLOC      NVARCHAR( 10)
   DECLARE @cPQTY             NVARCHAR( 5)
   DECLARE @cMQTY             NVARCHAR( 5)
   DECLARE @cFieldAttr14      NVARCHAR( 1)
   DECLARE @cFieldAttr15      NVARCHAR( 1)
   DECLARE @cOutField14       NVARCHAR( 60)
   DECLARE @cOutField15       NVARCHAR( 60)
   DECLARE @cInField14        NVARCHAR( 60)
   DECLARE @cInField15        NVARCHAR( 60)
   DECLARE @cPUOM             NVARCHAR( 1)
   DECLARE @nQTY_RPL          INT
   DECLARE @nQTY              INT

   SELECT @cFacility = Facility, 
          @cFieldAttr14 = FieldAttr14, 
          @cFieldAttr15 = FieldAttr15, 
          @cInField14 = I_Field14, 
          @cInField15 = I_Field15, 
          @cOutField14 = O_Field14, 
          @cOutField15 = O_Field15,
          @cPUOM  = V_UOM,
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 4 -- UCC/Qty
      BEGIN
         SELECT
            @cSuggSKU = Sku,
            @cSuggFromLOC = FromLOC,
            @nQTY_RPL     = QTY
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE Loc = @cSuggFromLOC
                     AND   Facility = @cFacility
                     AND   LocationType = 'DYNPPICK')
         BEGIN
            SET @cPQTY = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END
            SET @cMQTY = CASE WHEN @cFieldAttr15 = 'O' THEN @cOutField15 ELSE @cInField15 END

            -- Calc total QTY in master UOM
            SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSuggSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
            SET @nQTY = @nQTY + CAST( @cMQTY AS INT)

            IF @nQTY > @nQTY_RPL
            BEGIN
               SET @nErrNo = 163801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Replenish
               GOTO Quit
            END
         END
      END
   END


Quit:

END

GO