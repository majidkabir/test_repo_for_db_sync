SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808ExtValid01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Check if scaned toteid has been used before                 */
/*          (no matter which cart use it ), prompt error                */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-11-26  1.0  James       WMS-11089. Created                      */
/* 2020-02-27  1.1  James       WMS-11371 Enhance duplicate tote id     */
/*                              checking (james01)                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_808ExtValid01] (
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

   DECLARE @cFieldAttr NVARCHAR( 1)
   
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
         
         IF @cMethodSP = 'rdt_PTLCart_Assign_BatchTotes'
            SELECT @cToteID = I_Field06, @cFieldAttr = FieldAttr06 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         IF @cMethodSP = 'rdt_PTLCart_Assign_BatchTotes01'         
            SELECT @cToteID = I_Field05, @cFieldAttr = FieldAttr05 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
         
         IF @cFieldAttr = ''
         BEGIN
            IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
                       WHERE ToteID = @cToteID 
                       AND   StorerKey = @cStorerKey)
            BEGIN
               SET @nErrNo = 146401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteID In Used
               GOTO Quit
            END

            IF EXISTS( SELECT 1 FROM dbo.PICKDETAIL P WITH (NOLOCK) 
                       WHERE DropID = @cToteID 
                       AND   StorerKey = @cStorerKey)
            BEGIN
               -- (james01)
               -- If it B2C no duplicated toteid should be checked
               -- because toteid for B2C will always be the position of a cart , like 01,02,03 
               -- Only B2B orders need check duplicate toteid
               IF EXISTS ( SELECT 1  
                           FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
                           WHERE CartID = @cCartID  
                           AND   DeviceProfileLogKey = @cDPLKey  
                           AND   LEFT( BatchKey, 1) = 'M')  
               BEGIN
                  SET @nErrNo = 146402
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteID In Used
                  GOTO Quit
               END
            END
         END
      END
   END
   
   IF @nStep = 6 -- Close tote
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
                    WHERE ToteID = @cNewToteID 
                    AND   StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 146403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteID In Used
            GOTO Quit
         END
         
         IF EXISTS ( SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   DropID = @cNewToteID
                     AND   [Status] = '9')
         BEGIN
            SET @nErrNo = 146404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteID Used
            GOTO Quit
         END
      END
   END

   Quit:

END

GO