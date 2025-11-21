SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_841BTSP01                                       */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: ANF Ecomm Bartender Printing SP                             */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 14-07-2014  1.0  ChewKP   Created                                    */
/* 26-03-2014  1.1  ChewKP   SOS#336932 - Add WaveKey, LoadKey Input    */
/*                           (ChewKP01)                                 */
/* 27-10-2016  1.2  ChewKP   Performance Tuning (ChewKP02)              */
/* 24-02-2020  1.3  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_841BTSP01] (
        @nMobile     int
      , @nFunc       int
      , @cLangCode   nvarchar(3)
      , @cFacility   nvarchar(5)
      , @cStorerKey  nvarchar(15)
      , @cPrinterID  nvarchar(10)
      , @cDropID     nvarchar(20)
      , @cLoadKey    nvarchar(10)
      , @cLabelNo    nvarchar(20)
      , @cUserName   nvarchar(18)
      , @nErrNo      int            OUTPUT
      , @cErrMsg     nvarchar(1024) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelType  AS NVARCHAR(30)
          ,@cOrderType  AS NVARCHAR(10)
          ,@cLabelFlag  AS NVARCHAR(1)
          ,@cPickSlipNo AS NVARCHAR(10)
          ,@cExternORderKey AS NVARCHAR(30)
          ,@cOrderKey   AS NVARCHAR(10)
          ,@cShipperKey AS NVARCHAR(10)

   SET @nErrNo     = 0
   SET @cERRMSG    = ''

   SET @cPickSlipNo = ''
   SET @cOrderType = ''
   SET @cLabelFlag = ''

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE DropID = @cDropID
   AND LabelNo = @cLabelNo

   -- (ChewKP01)
   IF ISNULL(RTRIM(@cPickSlipNo),'') = ''
   BEGIN
      SELECT --@cPickSlipNo = PH.PickHeaderKey
             @cOrderKey   = PH.OrderKey
      FROM dbo.Pickheader PH WITH (NOLOCK)
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK)  ON PD.OrderKey = PH.OrderKey
      WHERE PD.DropID = @cDropID
      AND PD.CaseID = @cLabelNo
   END
   ELSE
   BEGIN
      SELECT @cOrderKey = OrderKey
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
   END

   SELECT  @cExternOrderKey = ExternOrderKey
          ,@cShipperKey     = ShipperKey
          ,@cLoadKey        = LoadKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND OrderKey = @cOrderKey

--   SELECT Top 1 @cExternOrderKey = O.ExternOrderKey
--               ,@cOrderKey       = O.OrderKey
--               ,@cShipperKey     = O.ShipperKey
--               ,@cLoadKey        = O.LoadKey
--   FROM dbo.Orders O WITH (NOLOCK)
--   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
--   INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
--   WHERE PH.PickHeaderKey = @cPickSlipNo
--   AND PD.CaseID = @cLabelNo

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
      SET @cLabelType = 'SHIPPLABEL'
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

   -- To Proceed Ecomm Despatch while printing having error --
   SET @nErrNo     = 0
   SET @cERRMSG    = ''
END

GO