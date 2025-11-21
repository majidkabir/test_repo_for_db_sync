SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840GenLabelNo01                                 */
/* Purpose: HM gen SSCC label no using codelkup. Need update back       */
/*          the counter to the codelkup table                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-11-02 1.0  James      WMS3352. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_840GenLabelNo01] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @cLabelNo    NVARCHAR( 20) OUTPUT,
   @nCartonNo   INT           OUTPUT,
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @cFixedString   NVARCHAR( 10), 
           @cCheckDigit    NVARCHAR( 1),
           @cCounter       NVARCHAR( 7), 
           @cSSCCLabelNo   NVARCHAR( 20),
           @bSuccess       INT

   /*
      2 û Extension digit for LF (1 digit)
      7212980 û GS1 Company Prefix (7 digits)
      99 û Serial number for LF01 (2 digits)
      0000000 û running counter, to be reset to 0000000 after reaching 9999999 (7 digits)
      K û check digit using Modulo 10 algorithm (1 digit)
   */

   SELECT @cFixedString = UDF02
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'HMSSCC'
   AND   Code = 'HMSSCCLbNo'
   AND   StorerKey = @cStorerkey

   IF @@ROWCOUNT = 0
   BEGIN    
      SET @nErrNo = 118551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup Codelkup'
      GOTO Quit
   END 

   IF ISNULL( @cFixedString, '') = ''
   BEGIN    
      SET @nErrNo = 118552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No GS1 prefix'    
      GOTO Quit    
   END 

   SET @cCounter = ''
   SET @bSuccess = 1

   EXECUTE nspg_getkey
		@KeyName       = 'HMSSCCLbNo', 
		@fieldlength   = 7,
		@keystring     = @cCounter  OUTPUT,
		@b_Success     = @bSuccess   OUTPUT,
		@n_err         = @nErrNo     OUTPUT,
		@c_errmsg      = @cErrMsg    OUTPUT,
      @b_resultset   = 0,
      @n_batch       = 1

   IF @bSuccess <> 1 OR ISNULL( @cCounter, '') = ''
   BEGIN
      SET @nErrNo = 118553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey fail'    
      GOTO Quit
   END

   SET @cSSCCLabelNo = RTRIM( @cFixedString)
   SET @cSSCCLabelNo = @cSSCCLabelNo + RIGHT( ('0000000' + @cCounter), 7)
   SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10( RTRIM( @cSSCCLabelNo), 0)
   SET @cSSCCLabelNo = RTRIM( @cSSCCLabelNo) + @cCheckDigit

   IF ISNULL( @cSSCCLabelNo, '') = ''
   BEGIN
      SET @nErrNo = 118554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen SSCC Fail'    
      GOTO Quit   
   END

   IF LEN( RTRIM( @cSSCCLabelNo)) <> 18
   BEGIN
      SET @nErrNo = 118555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen SSCC Fail'    
      GOTO Quit
   END

   UPDATE dbo.CODELKUP WITH (ROWLOCK) SET 
      UDF03 = @cCounter
   WHERE ListName = 'HMSSCC'
   AND   Code = 'HMSSCCLbNo'
   AND   StorerKey = @cStorerkey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 118556
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD RunNo Fail'    
      GOTO Quit
   END

   SET @cLabelNo = @cSSCCLabelNo

   Quit:

GO