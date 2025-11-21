SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1868UnpackVal                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date         Rev   Author      Purposes                              */
/* 2024-11-05   1.0   TLE109      FCR-917 Serial Unpack and Unpick      */
/************************************************************************/

CREATE   PROC rdt.rdt_1868UnpackVal (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cSerialNo        NVARCHAR( 100),
   @cPickSlipNo      NVARCHAR( 20),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE 
   @cUnPackValidateSP  NVARCHAR( 20),   
   @cSQL               NVARCHAR( MAX),
   @cSQLParam          NVARCHAR( MAX)


-------------------------------------------------Customer---------------------------------------------

   SET @cUnPackValidateSP = rdt.RDTGetConfig( @nFunc, 'UnPackValidateSP', @cStorerKey)
   IF @cUnPackValidateSP = '0'
   BEGIN
      SET @cUnPackValidateSP = ''
   END

   IF @cUnPackValidateSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cUnPackValidateSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cUnPackValidateSP) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
      ' @cSerialNo, @cPickSlipNo,' +
      ' @nErrNo OUTPUT, @cErrMsg OUTPUT ' 

      SET @cSQLParam = 
      ' @nMobile        INT,           ' +
      ' @nFunc          INT,           ' +
      ' @cLangCode      NVARCHAR( 3),  ' +
      ' @nStep          INT,           ' +
      ' @nInputKey      INT,           ' +
      ' @cFacility      NVARCHAR( 5),  ' +
      ' @cStorerKey     NVARCHAR( 15), ' +
      ' @cSerialNo      NVARCHAR( 100),' +
      ' @cPickSlipNo    NVARCHAR( 20), ' + 
      ' @nErrNo         INT,           ' +
      ' @cErrMsg        NVARCHAR( 20)  ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cSerialNo, @cPickslipNo,
         @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      END
      GOTO Quit
   END


-------------------------------------------------Standard----------------------------------------------


   IF @cSerialNo = ''
   BEGIN
      SET @nErrNo = 228256
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --228256^SerialNo is not valid
      GOTO Quit
   END

   IF NOT EXISTS( SELECT 1 FROM dbo.PackSerialNo WITH(NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND SerialNo = @cSerialNo AND StorerKey = @cStorerKey )
   BEGIN
      SET @nErrNo = 228259
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --228259^Serial number not yet packed
      GOTO Quit
   END

   IF EXISTS( SELECT 1 FROM dbo.SerialNo WITH(NOLOCK) WHERE SerialNo = @cSerialNo AND Storerkey=@cStorerkey AND Status NOT IN(1,6) )
   BEGIN
      SET @nErrNo = 228257
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --228257^SerialNo is not valid
      GOTO Quit
   END  


 


Quit:
END

GO