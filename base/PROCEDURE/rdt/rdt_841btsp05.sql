SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_841BTSP05                                       */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: Dickies Ecomm Bartender Printing SP                         */
/*                                                                      */
/* Called from: rdtfnc_DTC_Dispatch                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-07-24  1.0  James    WMS9880. Created                           */
/* 2020-02-24  1.1  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_841BTSP05] (
   @nMobile       INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cPrinterID  NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cLoadKey    NVARCHAR( 10),
   @cLabelNo    NVARCHAR( 20),
   @cUserName   NVARCHAR( 18),
   @nErrNo      INT              OUTPUT,
   @cErrMsg     NVARCHAR( 20)    OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelType        NVARCHAR(30)
          ,@cOrderType        NVARCHAR(10)
          ,@cLabelFlag        NVARCHAR(1)
          ,@cPickSlipNo       NVARCHAR(10)
          ,@cExternORderKey   NVARCHAR(30)
          ,@cOrderKey         NVARCHAR(10)
          ,@cShipperKey       NVARCHAR(10)
          ,@cDocType          NVARCHAR( 1)
          ,@cShipLabel        NVARCHAR( 10)
          ,@nCartonNo         INT

   SET @nErrNo     = 0
   SET @cErrMsg    = ''
   SET @cPickSlipNo = ''
   SET @cOrderType = ''
   SET @cDocType = ''
   SET @cLabelFlag = ''

   -- (ChewKP03)
   IF ISNULL(@cLabelNo ,'' )  <> '' AND ISNULL(@cDropID ,'' )  = ''
   BEGIN
      SELECT TOP 1 @cPickSlipNo = PickSlipNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo
   END
   ELSE IF ISNULL(@cLabelNo ,'' )  = '' AND ISNULL(@cDropID ,'' )  <> ''
   BEGIN
      SELECT TOP 1  @cPickSlipNo = PickSlipNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cDropID
   END
   ELSE
   BEGIN
      SELECT TOP 1  @cPickSlipNo = PickSlipNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cDropID
      AND LabelNo = @cLabelNo
   END

   -- (ChewKP01)
   IF ISNULL(RTRIM(@cPickSlipNo),'') = ''
   BEGIN
      SELECT --@cPickSlipNo = PH.PickHeaderKey
             @cOrderKey   = PH.OrderKey
      FROM dbo.Pickheader PH WITH (NOLOCK)
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK)  ON PD.OrderKey = PH.OrderKey
      WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cDropID
      AND PD.CaseID = @cLabelNo
   END
   ELSE
   BEGIN
      SELECT @cOrderKey = OrderKey
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo
   END

   SELECT  @cExternOrderKey = ExternOrderKey
          ,@cShipperKey     = ShipperKey
          ,@cLoadKey        = LoadKey
          ,@cOrderType      = [Type]
          ,@cDocType        = DocType
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND OrderKey = @cOrderKey

   IF @cShipperKey IN ( 'LFL01', 'DHL' )
   BEGIN
      SET @cLabelType = 'SHIPPLABELDTC'
      EXEC dbo.isp_BT_GenBartenderCommand
            @cPrinterID     = @cPrinterID
          , @c_LabelType    = @cLabelType
          , @c_userid       = @cUserName
          , @c_Parm01       = @cLoadKey
          , @c_Parm02       = @cOrderKey -- OrderKey
          , @c_Parm03       = @cExternOrderKey
          , @c_Parm04       = @cLabelNo
          , @c_Parm05       = @cShipperKey
          , @c_Parm06       = ''
          , @c_Parm07       = ''
          , @c_Parm08       = ''
          , @c_Parm09       = ''
          , @c_Parm10       = ''
          , @c_StorerKey    = @cStorerKey
          , @c_NoCopy       = '1'
          , @b_Debug        = '0'
          , @c_Returnresult = 'N'
          , @n_err          = @nErrNo  OUTPUT
          , @c_errmsg       = @cERRMSG OUTPUT
   END
   ELSE
   BEGIN

      SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
      IF @cShipLabel = '0'
         SET @cShipLabel = ''

      IF @cShipLabel <> ''
      BEGIN
         SELECT TOP 1 @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         ORDER BY 1

         SET @nErrNo = 0
         DECLARE @tSHIPPLABEL AS VariableTable
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cPrinterID, '',
            @cShipLabel, -- Report type
            @tSHIPPLABEL, -- Report params
            'rdt_841BTSP05',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
      END
      ELSE
      BEGIN
        SET @cLabelType = 'SHIPPLBLSP' -- 'SHIPPLABEL'
        --INSERT INTO TraceInfo (  Tracename , TimeIN , Col1, Col2 , Col3 , Col4, col5, Step1, Step2 )
        --VALUES ('BARTENDER' , GetdatE() , @cLoadKey, @cOrderKey, @cShipperKey, @cStorerKey, @cPickSlipNo, @cDropID, @cLabelNo)

        EXEC dbo.isp_BT_GenBartenderCommand
              @cPrinterID     = @cPrinterID
            , @c_LabelType    = @cLabelType
            , @c_userid       = @cUserName
            , @c_Parm01       = @cLoadKey
            , @c_Parm02       = @cOrderKey -- OrderKey
            , @c_Parm03       = @cShipperKey
            , @c_Parm04       = 0
            , @c_Parm05       = ''
            , @c_Parm06       = ''
            , @c_Parm07       = ''
            , @c_Parm08       = ''
            , @c_Parm09       = ''
            , @c_Parm10       = ''
            , @c_StorerKey    = @cStorerKey
            , @c_NoCopy       = '1'
            , @b_Debug        = '0'
            , @c_Returnresult = 'N'
            , @n_err          = @nErrNo  OUTPUT
            , @c_errmsg       = @cERRMSG OUTPUT
      END
   END

   -- To Proceed Ecomm Despatch while printing having error --
   SET @nErrNo     = 0
   SET @cERRMSG    = ''
END

GO