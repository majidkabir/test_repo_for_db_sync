SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: isp_838GenLabelNo04                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 29-10-2022 1.0  Yeekung    WMS-21057 Created                         */
/************************************************************************/

CREATE   PROC [dbo].[isp_838GenLabelNo04] (
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
   DECLARE @cstorerkey NVARCHAR(20)

   DECLARE 
           @cCounter       NVARCHAR( 20),
           @cSSCCLabelNo   NVARCHAR( 20),
           @cKeyName       NVARCHAR( 18),
           @cKeyName2      NVARCHAR( 20),
           @cLangCode      NVARCHAR(20)='ENG',
           @dYear          INT,
           @dMonth         INT,
           @dDay           INT

   SELECT TOP 1 @cstorerkey=pd.Storerkey
   FROM pickheader ph (NOLOCK)
   JOIN loadplandetail lp (NOLOCK) ON ph.loadkey=lp.LoadKey
   JOIN pickdetail pd (NOLOCK) ON pd.OrderKey=lp.OrderKey
   WHERE ph.PickHeaderKey=@cPickslipNo

   /*
      ∩âÿ	YMMDD010000000+3Digit[0~9]
   */

   SET @cKeyName = SUBSTRING( @cStorerKey, 1, 10) + '-SSCCLbNo'
   SET @cKeyName2 = @cKeyName+'2'

   select @cKeyName,@cKeyName2

   IF NOT EXISTS (SELECT 1 From nCounter WITH (NOLOCK)
         WHERE KeyName = @cKeyName
         )
   BEGIN

      INSERT  nCounter(keyname,keycount)
      values(@cKeyName,'000000000')

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 193401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey Fail'
         GOTO Quit
      END

      INSERT  nCounter(keyname,keycount)
      values(@cKeyName2,'1200')

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 193401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey Fail'
         GOTO Quit
      END


      SET @cLabelNo='1200000000000'
   END

   ELSE
   BEGIN
      SET @cCounter = 0
      SET @bSuccess = 1

      EXECUTE nspg_getkey
         @KeyName       = @cKeyName,
         @fieldlength   = 9,
         @keystring     = @cCounter  OUTPUT,
         @b_Success     = @bSuccess   OUTPUT,
         @n_err         = @nErrNo     OUTPUT,
         @c_errmsg      = @cErrMsg    OUTPUT,
         @b_resultset   = 0,
         @n_batch       = 1

      IF @bSuccess <> 1 
      BEGIN
         SET @nErrNo = 193402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey fail'
         GOTO Quit
      END

      IF @cCounter='999999999'
      BEGIN
         SELECT @cLabelNo=CAST(keycount AS NVARCHAR(4))+@cCounter
         FROM nCounter (NOLOCK)
         where keyname=@cKeyName2

         EXECUTE nspg_getkey
            @KeyName       = @cKeyName2,
            @fieldlength   = 4,
            @keystring     = @cCounter  OUTPUT,
            @b_Success     = @bSuccess   OUTPUT,
            @n_err         = @nErrNo     OUTPUT,
            @c_errmsg      = @cErrMsg    OUTPUT,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @bSuccess <> 1 
         BEGIN
            SET @nErrNo = 193402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey fail'
            GOTO Quit
         END
      END
      ELSE
      BEGIN
          SELECT @cLabelNo=CAST(keycount AS NVARCHAR(4))+@cCounter
         FROM nCounter (NOLOCK)
         where keyname=@cKeyName2
      END
   END
END
QUIT:

GO