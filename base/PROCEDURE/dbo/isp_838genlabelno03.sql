SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_838GenLabelNo03                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 19-05-2021 1.0  Yeekung    WMS-16963 Created                         */
/************************************************************************/

CREATE PROC [dbo].[isp_838GenLabelNo03] (
   @cPickslipNo NVARCHAR(10),        
   @nCartonNo   INT,                 
   @cLabelNo    NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT
   DECLARE @nErrNo INT
   DECLARE @cErrMsg NVARCHAR( 250)
   DECLARE @corderkey NVARCHAR(20)
   DECLARE @cstorerkey NVARCHAR(20)

   DECLARE @cFixedString   NVARCHAR( 10),     
           @cCheckDigit    NVARCHAR( 1),    
           @cCounter       NVARCHAR( 8),     
           @cSSCCLabelNo   NVARCHAR( 20),    
           @cKeyName       NVARCHAR( 18),    
           @cStartCounter  NVARCHAR( 60),    
           @cEndCounter    NVARCHAR( 60),        
           @bUpdCounter    INT,    
           @nIsMoveOrder   INT,
           @cLangCode      NVARCHAR(20)='ENG'    

   SELECT TOP 1 @corderkey=pd.OrderKey
                ,@cstorerkey=pd.Storerkey
   FROM pickheader ph (NOLOCK)
   JOIN loadplandetail lp (NOLOCK) ON ph.ExternOrderKey=lp.LoadKey
   JOIN pickdetail pd (NOLOCK) ON pd.OrderKey=lp.OrderKey
   WHERE ph.PickHeaderKey=@cPickslipNo

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
         SET @nErrNo = 168001    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup Codelkup'    
         GOTO Quit    
      END     
    
      IF ISNULL( @cFixedString, '') = ''    
      BEGIN        
         SET @nErrNo = 168002    
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
         SET @nErrNo = 168003    
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
            SET @nErrNo = 168004    
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
         SET @nErrNo = 168005    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen SSCC Fail'        
         GOTO Quit       
      END    
    
      IF LEN( RTRIM( @cSSCCLabelNo)) <> 18    
      BEGIN    
         SET @nErrNo = 168006    
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
         SET @nErrNo = 168007    
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
END
QUIT:

GO