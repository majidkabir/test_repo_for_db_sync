SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: 4. rdt_593ShipLabel13                                  */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2021-03-09 1.0  Chermaine  WMS-16510 Created                            */
/* 2021-07-01 1.1  James      WMS-17070 Update packheader.ctntyp1 (james01)*/
/* 2021-11-29 1.2  James      WMS-18430 Prompt error for B2B (james02)     */
/* 2022-02-22 1.3  Ung        WMS-18940 Fix update carton type only when   */
/*                            not yet pack confirm                         */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_593ShipLabel13] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- dropid
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success     INT

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cLabelType    NVARCHAR( 20)
   DECLARE @cUserName     NVARCHAR( 18)

   DECLARE
    @cDropid             NVARCHAR(20)
      , @cLabelNo          NVARCHAR(20)
    , @cTrackingNo       NVARCHAR(20)
      , @cPrintCartonLabel NVARCHAR(1)
      , @cOrderCCountry    NVARCHAR(30)
      , @cOrderType        NVARCHAR(10)
      , @cLoadKey          NVARCHAR(10)
      , @cTargetDB         NVARCHAR(20)
      , @cVASType          NVARCHAR(10)
      , @cField01          NVARCHAR(10)
      , @cTemplate         NVARCHAR(50)
      , @cOrderKey         NVARCHAR(10)
      , @cPickSlipNo       NVARCHAR(10)
      , @nCartonNo         INT
      , @cCodeTwo          NVARCHAR(30)
      , @cTemplateCode     NVARCHAR(60)
      , @cPasscode         NVARCHAR(20) -- (ChewKP02)
      , @cDataWindow       NVARCHAR( 50) -- (ChewKP03)

   -- cLabelNo mapping
   SET @cDropid = @cParam1

   SELECT
      @cUserName = UserName,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT
      @cOrderKey = ISNULL(o.orderkey,''),
      @cLabelNo = ISNULL(pd.labelno,''),
      @nCartonNo = ISNULL(pd.cartonno,''),
      @cPickSlipno = ISNULL(ph.pickslipno,'')
   FROM orders o with(nolock)
   JOIN packheader ph with(nolock) on (o.orderkey = ph.orderkey)
   JOIN packdetail pd with(nolock) on (ph.pickslipno = pd.pickslipno)
   WHERE pd.dropid = @cDropid
   and o.userdefine03 = 'LC'
   and pd.storerkey = @cStorerKey


   IF @cOrderKey <> ''
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  AND   DocType = 'E')
      BEGIN
         SET @nErrNo = 179301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
         GOTO Quit
      END

      IF NOT EXISTS(SELECT 1 FROM ORDERS (NOLOCK) WHERE ORDERKEY = @cOrderKey AND SHIPPERKEY = 'CJKE8')
      BEGIN
         UPDATE ORDERS SET SHIPPERKEY = 'CJKE8' WHERE ORDERKEY = @cOrderKey
      END

      IF exists(select 1 from orders (nolock) where orderkey = @cOrderKey and userdefine03 = 'LC' and storerkey = @cStorerKey)
      BEGIN
         IF not exists(select 1 from cartontrack(nolock) where trackingno = @cLabelNo and carriername = 'CJKE8' and keyname = @cStorerKey)
         BEGIN
            select top 1 @cTrackingNo = ISNULL(TrackingNo,'') from cartontrack(nolock) where  carriername = 'CJKE8' and keyname = @cStorerKey and CARRIERREF2 = ''

            IF @cTrackingNo <> ''
            BEGIN
               UPDATE cartontrack SET
                  LABELNO = @cLabelNo,
                  CARRIERREF2 = 'GET'
               WHERE carriername = 'CJKE8'
               AND keyname = @cStorerKey
               AND CARRIERREF2 = ''
               AND trackingno = @cTrackingNo

               UPDATE packdetail SET
                  labelno = @cTrackingNo
               WHERE labelno = @cLabelNo
               AND storerkey = 'IIC'
               AND pickslipno = @cPickSlipno
            END
         END

         -- (james01)
         IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '0')
         BEGIN 
            UPDATE dbo.PackHeader SET
               CtnTyp1 = 'S',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickSlipNo = @cPickSlipNo
            SET @nErrNo = @@ERROR

            IF @nErrNo <> 0
               GOTO Quit
         END
         
         SET @cLabelType = 'SHIPLBLCJ2'
         EXEC dbo.isp_BT_GenBartenderCommand
            @cLabelPrinter
            , @cLabelType
            , @cUserName
            , @cOrderKey
            , @nCartonNo
            , @nCartonNo
            , ''
            , ''
            , ''
            , ''
            , ''
            , ''
            , ''
            , @cStorerKey
            , '1'
            , '0'
            , 'N'
            , @nErrNo  OUTPUT
            , @cERRMSG OUTPUT
      END
   END

Quit:


GO