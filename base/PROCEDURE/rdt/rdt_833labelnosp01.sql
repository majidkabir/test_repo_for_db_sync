SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Store procedure: rdt_833LabelNoSP01                                  */
/* Copyright: IDS                                                       */
/* Called From: rdtfnc_PackByCartonID                                   */
/* Purpose: Generate label no                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 03-Apr-2019  1.0  James      WMS8119.Created                         */
/* 16-Apr-2021  1.1  James      WMS-16024 Standarized use of TrackingNo */
/*                              (james01)                               */
/************************************************************************/

CREATE PROC [RDT].[rdt_833LabelNoSP01](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerkey    NVARCHAR( 15),
   @cWaveKey      NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10),
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @cCaseID       NVARCHAR( 20),
   @cSerialNo     NVARCHAR( MAX),
   @nQty          INT,
   @cLabelNo      NVARCHAR( 20) OUTPUT,
   @nCartonNo     INT           OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cUserDefine04     NVARCHAR( 20)
   DECLARE @cDocType          NVARCHAR( 1)
   DECLARE @bSuccess          INT
   DECLARE @nMaxCartonNo      INT

   SET @nErrNo = 0

   SELECT @cOrderKey = OrderKey
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo

   IF ISNULL( @cOrderKey, '') = ''
      SELECT @cOrderKey = OrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

   --SELECT @cUserDefine04 = UserDefine04, 
   SELECT @cUserDefine04 = TrackingNo, -- (james01)
          @cDocType = DocType
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   AND   StorerKey = @cStorerKey

   IF @cDocType = 'E'
   BEGIN
      --Check if it is 1st carton
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE PickSlipNo = @cPickSlipNo)
      BEGIN


         IF ISNULL( @cUserDefine04, '') = ''
         BEGIN
            SET @nErrNo = 137301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No UDF04'
            GOTO Quit
         END

         SELECT @cLabelNo = @cUserDefine04
      END
      ELSE
      BEGIN
         SELECT @nMaxCartonNo = MAX( CartonNo)
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo

         EXEC [dbo].[isp_EPackCtnTrack03]  
            @c_PickSlipNo  = @cPickSlipNo
         ,  @n_CartonNo    = @nMaxCartonNo  
         ,  @c_CTNTrackNo  = @cLabelNo    OUTPUT  
         ,  @b_Success     = @bSuccess    OUTPUT   -- 0:Fail, 1:Success 2:Success with Track # is lock  
         ,  @n_err         = @nErrNo      OUTPUT   
         ,  @c_errmsg      = @cErrMsg     OUTPUT   

         IF @bSuccess = 0 OR @nErrNo <> 0 OR ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 137302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen Label Fail'
            GOTO Quit
         END
      END
   END
   ELSE
   BEGIN
      EXECUTE dbo.nsp_GenLabelNo
         @c_orderkey    = '',
         @c_storerkey   = @cStorerKey,
         @c_labelno     = @cLabelNo    OUTPUT,
         @n_cartonno    = @nCartonNo   OUTPUT,
         @c_button      = '',
         @b_success     = @bSuccess    OUTPUT,
         @n_err         = @nErrNo      OUTPUT,
         @c_errmsg      = @cErrMsg     OUTPUT

      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 137303
         SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
         GOTO Quit
      END
   END

   Quit:


GO