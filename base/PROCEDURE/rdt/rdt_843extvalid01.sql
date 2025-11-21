SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_843ExtValid01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Check if scanned tote id has been closed ( not exists in    */
/*          rdtPTLCartLog ). If Yes, prompt error                       */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-11-26  1.0  James       WMS-11186. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_843ExtValid01] (
   @nMobile       INT, 
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,   
   @nInputKey     INT, 
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cDropID       NVARCHAR( 20), 
   @nCartonNo     INT, 
   @cLabelNo      NVARCHAR( 20), 
   @cOption       NVARCHAR( 1), 
   @cCartonType   NVARCHAR( 10), 
   @cWeight       NVARCHAR( 10), 
   @tExtValidVar  VariableTable READONLY, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   IF @nStep = 1 -- Pickslipno, Drop id
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- If drop id blank, no need further check
         IF ISNULL( @cDropID, '') = ''
            GOTO Quit

         -- Scan in drop id ( main sp check either pickslipno or dropid can scan in)
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
                    WHERE ToteID = @cDropID 
                    AND   StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 146501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteID In Used
            GOTO Quit
         END
      END
   END

   Quit:

END

GO