SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803ExtValid02                                   */
/* Purpose: Check whether station has orders not yet picked             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-11-11 1.0  Chermaine  WMS-17331. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_803ExtValid02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cStation     NVARCHAR( 10),
   @cMethod      NVARCHAR( 1),
   @cSKU         NVARCHAR( 20),
   @cLastPos     NVARCHAR( 10),
   @cOption      NVARCHAR( 1),
   @tExtValid    VariableTable READONLY,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10) = '',
           @cLoadKey    NVARCHAR( 10) = '',
           @cPosition   NVARCHAR( 10) = '',
           @cErrMsg01   NVARCHAR( 20) = '',
           @cErrMsg02   NVARCHAR( 20) = '',
           @cErrMsg03   NVARCHAR( 20) = '',
           @cErrMsg04   NVARCHAR( 20) = '',
           @cErrMsg05   NVARCHAR( 20) = ''

   SET @nErrNo = 0

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	-- If hav balance Task , not allow to unassign
         IF @cOption = '1'
         BEGIN
         	IF EXISTS( SELECT 1
                     FROM Orders O WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey )
                     JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
                     JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation AND L.BatchKey = PT.TaskBatchNo )
                     WHERE L.Station = @cStation
                        AND PD.Status <> '4'
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'
                        AND PD.CaseID <> 'Sorted' )
            BEGIN
            	SET @nErrNo = 178351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --Task Not Done
               GOTO Quit
            END
         END
      END
   END
   
   Quit:

GO