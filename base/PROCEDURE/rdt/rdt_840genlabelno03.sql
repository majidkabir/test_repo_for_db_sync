SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840GenLabelNo03                                 */  
/* Purpose: Gen SSCC label no using codelkup. Need update back          */  
/*          the counter to the codelkup table                           */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-04-01 1.0  James      WMS-12757. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840GenLabelNo03] (  
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
           @cCounter       NVARCHAR( 8),   
           @cSSCCLabelNo   NVARCHAR( 20),  
           @cKeyName       NVARCHAR( 18),  
           @cStartCounter  NVARCHAR( 60),  
           @cEndCounter    NVARCHAR( 60),  
           @bSuccess       INT,  
           @bUpdCounter    INT,  
           @nIsMoveOrder   INT  
  
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)  
               JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.[Type] AND C.StorerKey = O.StorerKey)  
               WHERE C.ListName = 'HMORDTYPE'  
               AND   C.UDF01 = 'M'  
               AND   O.OrderKey = @cOrderkey  
               AND   O.StorerKey = @cStorerKey)  
      SET @nIsMoveOrder = 1  
   ELSE  
      SET @nIsMoveOrder = 0  
  
   IF @nIsMoveOrder = 1 -- move orders  
   BEGIN  
      /*  
         2 û Extension digit for LF (1 digit)  
         7212980 û GS1 Company Prefix (7 digits)  
         99 û Serial number for LF01 (2 digits)  
         0000000 û running counter, to be reset to 0000000 after reaching 9999999 (7 digits)  
         K û check digit using Modulo 10 algorithm (1 digit)  
      */  
  
      SELECT @cFixedString = UDF02,   
             @cStartCounter = UDF04,   
             @cEndCounter = UDF05  
      FROM dbo.CODELKUP WITH (NOLOCK)  
      WHERE ListName = 'PackTrklbl'  
      AND   Code = 'SSCCLbNo'  
      AND   StorerKey = @cStorerkey  
  
      IF @@ROWCOUNT = 0  
      BEGIN      
         SET @nErrNo = 150551  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup Codelkup'  
         GOTO Quit  
      END   
  
      IF ISNULL( @cFixedString, '') = ''  
      BEGIN      
         SET @nErrNo = 150552  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No GS1 prefix'      
         GOTO Quit      
      END   
  
      SET @cCounter = ''  
      SET @bSuccess = 1  
      SET @bUpdCounter = 0  
      SET @cKeyName = SUBSTRING( @cStorerKey, 1, 10) + 'SSCCLbNo'  
      EXECUTE nspg_getkey  
         @KeyName       = @cKeyName,   
         @fieldlength   = 8,  
         @keystring     = @cCounter  OUTPUT,  
         @b_Success     = @bSuccess   OUTPUT,  
         @n_err         = @nErrNo     OUTPUT,  
         @c_errmsg      = @cErrMsg    OUTPUT,  
         @b_resultset   = 0,  
         @n_batch       = 1  
  
      IF @bSuccess <> 1 OR ISNULL( @cCounter, '') = ''  
      BEGIN  
         SET @nErrNo = 150553  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey fail'      
         GOTO Quit  
      END  
  
      -- 1st time gen counter, make sure it is start from preset counter range  
      IF CAST( @cCounter AS INT) < CAST( @cStartCounter AS INT) AND ISNULL( @cStartCounter, '') <> ''  
      BEGIN  
         SET @cCounter = @cStartCounter  
         SET @bUpdCounter = 1  
      END  
      -- If counter already > than preset counter range then reset it   
      IF CAST( @cCounter AS INT) > CAST( @cEndCounter AS INT) AND ISNULL( @cEndCounter, '') <> ''  
      BEGIN  
         SET @cCounter = @cStartCounter  
         SET @bUpdCounter = 1  
      END  
  
      IF @bUpdCounter = 1  
      BEGIN  
         UPDATE nCounter WITH (ROWLOCK) SET   
            KeyCount = CAST( @cCounter AS INT), Editdate = GETDATE()   
         WHERE KeyName = @cKeyName       
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 150554  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey Fail'      
            GOTO Quit     
         END  
      END  
  
      SET @cSSCCLabelNo = RTRIM( @cFixedString)  
      SET @cSSCCLabelNo = @cSSCCLabelNo + RIGHT( ('00000000' + @cCounter), 8)  
      SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10( RTRIM( @cSSCCLabelNo), 0)  
      SET @cSSCCLabelNo = RTRIM( @cSSCCLabelNo) + @cCheckDigit  
  
      IF ISNULL( @cSSCCLabelNo, '') = ''  
      BEGIN  
         SET @nErrNo = 150555  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen SSCC Fail'      
         GOTO Quit     
      END  
  
      IF LEN( RTRIM( @cSSCCLabelNo)) <> 18  
      BEGIN  
         SET @nErrNo = 150556  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen SSCC Fail'      
         GOTO Quit  
      END  
  
      UPDATE dbo.CODELKUP WITH (ROWLOCK) SET   
         UDF03 = @cCounter  
      WHERE ListName = 'PackTrklbl'  
      AND   Code = 'SSCCLbNo'  
      AND   StorerKey = @cStorerkey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 150557  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD RunNo Fail'      
         GOTO Quit  
      END  
  
      SET @cLabelNo = @cSSCCLabelNo  
   END  
   ELSE  -- customer orders  
   BEGIN  
      -- Get new LabelNo  
      EXECUTE isp_GenUCCLabelNo  
         @cStorerKey,  
         @cLabelNo     OUTPUT,  
         @bSuccess     OUTPUT,  
         @nErrNo       OUTPUT,  
         @cErrMsg      OUTPUT  
   END  

   Quit:

GO