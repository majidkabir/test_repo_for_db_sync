SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808ExtValid02                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Check if Pickslip scan-in before by another picker          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-03-29  1.0  James       WMS-16553. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_808ExtValid02] (
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cFacility  NVARCHAR( 5),
   @cStorerKey NVARCHAR( 15),
   @cLight     NVARCHAR( 1), 
   @cDPLKey    NVARCHAR( 10),
   @cCartID    NVARCHAR( 10),
   @cPickZone  NVARCHAR( 10),
   @cMethod    NVARCHAR( 10),
   @cLOC       NVARCHAR( 10),
   @cSKU       NVARCHAR( 20),
   @cToteID    NVARCHAR( 20),
   @nQTY       INT,
   @cNewToteID NVARCHAR( 20),
   @tExtValidVar  VariableTable READONLY,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cFieldAttr  NVARCHAR( 1)
   
   IF @nStep = 2 -- Assign 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get method info
         DECLARE @cMethodSP SYSNAME
         SET @cMethodSP = ''
         SELECT @cMethodSP = ISNULL( UDF01, '')
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'CartMethod'
            AND Code = @cMethod
            AND StorerKey = @cStorerKey
         
         IF @cMethodSP = 'rdt_PTLCart_Assign_BatchTotes' OR 
            @cMethodSP = 'rdt_PTLCart_Assign_BatchOneTote' 
            SELECT @cPickSlipNo = I_Field03, 
                   @cFieldAttr = FieldAttr03, 
                   @cUserName = UserName
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE Mobile = @nMobile
         
         IF @cFieldAttr = ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   ISNULL( ScanInDate, '') <> ''
                        AND   PickerID = 'VOICEPICKING')
            BEGIN
               SET @nErrNo = 165401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --VP Picked
               GOTO Quit
            END
         END
      END
   END

   Quit:

END

GO