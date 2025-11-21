SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_GetTask                                 */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 06-10-2015  1.0  Ung         SOS336312 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_PACart_GetTask] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR(15)
   ,@cCartID      NVARCHAR(10)
   ,@cCol         NVARCHAR(5)
   ,@cRow         NVARCHAR(5)
   ,@nErrNo       INT          OUTPUT
   ,@cErrMsg      NVARCHAR(20) OUTPUT
   ,@cLOC         NVARCHAR(10) OUTPUT
   ,@cSKU         NVARCHAR(20) OUTPUT
   ,@cSKUDescr    NVARCHAR(60) OUTPUT
   ,@nTotalQTY    INT          OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @cPALogicalLOC NVARCHAR(18)

   -- Get task in same LOC, next SKU
   SELECT TOP 1
      @cLOC = R.SuggestedLOC,
      @cSKU = R.SKU
   FROM rdt.rdtPACartLog L WITH (NOLOCK)
      JOIN RFPutaway R WITH (NOLOCK) ON (L.ToteID = R.FromID)
      JOIN LOC WITH (NOLOCK) ON (R.SuggestedLOC = LOC.LOC)
	WHERE L.CartID = @cCartID
      AND R.SuggestedLOC = @cLOC
   ORDER BY LOC.PALogicalLoc, LOC.LOC, R.SKU

   IF @@ROWCOUNT = 0
   BEGIN
      -- Get logical LOC
      SET @cPALogicalLOC = ''
      SELECT @cPALogicalLOC = PALogicalLoc FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC
      
      -- Get task for next LOC
      SELECT TOP 1
         @cLOC = R.SuggestedLOC,
         @cSKU = R.SKU
      FROM rdt.rdtPACartLog L WITH (NOLOCK)
         JOIN RFPutaway R WITH (NOLOCK) ON (L.ToteID = R.FromID)
         JOIN LOC WITH (NOLOCK) ON (R.SuggestedLOC = LOC.LOC)
	   WHERE L.CartID = @cCartID
         AND LOC.PALogicalLoc + LOC.LOC > @cPALogicalLOC + @cLOC
      ORDER BY LOC.PALogicalLoc, LOC.LOC, R.SKU

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 57401
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'
         GOTO Quit
      END
   END
   
   -- Get SKU description
   SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   
   -- Get total order, QTY
   SELECT @nTotalQTY = SUM( QTY)
   FROM rdt.rdtPACartLog L WITH (NOLOCK)
      JOIN RFPutaway R WITH (NOLOCK) ON (L.ToteID = R.FromID)
	WHERE L.CartID = @cCartID
      AND R.StorerKey = @cStorerKey
	   AND R.SKU = @cSKU
	   AND R.SuggestedLOC = @cLOC
  
Quit:

END

GO