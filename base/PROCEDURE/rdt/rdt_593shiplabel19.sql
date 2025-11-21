SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel19                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-06-22 1.0  yeekung  WMS-22757 Created                              */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_593ShipLabel19] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- LoadKey
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),  -- LabelNo
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT

)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     INT

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cLabelType    NVARCHAR( 20)
   DECLARE @cUserName     NVARCHAR( 18)

   DECLARE @cLabelNo      NVARCHAR(20)
         , @cDropid       NVARCHAR(20)
         , @cPrintCartonLabel NVARCHAR(1)
         , @cOrderCCountry    NVARCHAR(30)
         , @cOrderType        NVARCHAR(10)
         , @cLoadKey      NVARCHAR(10)
         , @cTargetDB     NVARCHAR(20)
         , @cVASType      NVARCHAR(10)
         , @cField01      NVARCHAR(10)
         , @cTemplate     NVARCHAR(50)
         , @cOrderKey     NVARCHAR(10)
         , @cPickSlipNo   NVARCHAR(10)
         , @nCartonNo     INT
         , @cCodeTwo      NVARCHAR(30)
         , @cTemplateCode NVARCHAR(60)
         , @cPasscode     NVARCHAR(20) -- (ChewKP02)
         , @cDataWindow   NVARCHAR( 50) -- (ChewKP03)
         , @cTrackingno   NVARCHAR(20)
         , @cConsigneeKey NVARCHAR(20)
         , @cTMODE        NVARCHAR(20)
		   , @bSuccess      INT
		   , @nFocusParam   INT,
           @nTranCount    INT


   -- cLabelNo mapping
   SET @cDropid = @cParam1


   SELECT
      @cPickSlipNo = A.PickSlipNo,
      @nCartonNo   = A.cartonno,
		@cTMODE      = O.userdefine03,
		@cConsigneeKey = O.Consigneekey,
		@cLabelNo    = A.labelno
   FROM dbo.PackDetail A WITH (NOLOCK)
   JOIN dbo.PACKHEADER B WITH (NOLOCK) ON A.PICKSLIPNO = B.PICKSLIPNO
   JOIN dbo.PICKDETAIL PD (NOLOCK) ON B.Pickslipno =PD.pickslipno AND PD.SKU = A.SKU AND PD.dropid = A.LABELNO
   JOIN dbo.Orders O (NOLOCK) ON O.OrderKey = PD.OrderKey
   WHERE A.dropid = @cDropid
      AND   A.STORERKEY = @cStorerKey
   group by A.PickSlipNo,A.cartonno, O.userdefine03,O.Consigneekey,A.labelno;

   SELECT
      @cUserName = UserName,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   BEGIN
      SET @cLabelType = 'SHIPPLBLCNK'

      EXEC dbo.isp_BT_GenBartenderCommand
         @cLabelPrinter
         , @cLabelType
         , @cUserName
         , @cPickSlipNo
         , @nCartonNo
         , @nCartonNo
         , 'S' -- @cField01
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

      if @cStorerKey <> 'IIC'
      BEGIN
         EXEC dbo.isp_BT_GenBartenderCommand
            @cLabelPrinter
            , @cLabelType
            , @cUserName
            , @cPickSlipNo
            , @nCartonNo
            , @nCartonNo
            , 'C' -- @cField01
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

      IF @cTMODE = 'SC'
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM dbo.CARTONTRACK (NOLOCK)
                        WHERE LABELNO = @cLabelNo
                        AND   CARRIERNAME = 'SLKR'
                        AND   KEYNAME     = @cStorerKey
                        AND   CARRIERREF2 = 'GET')
         BEGIN

            DECLARE
               @cTrackNo          NVARCHAR(20),
               @cB_Contact1       NVARCHAR( 30),
               @cB_Company        NVARCHAR( 45),
               @cYY               NVARCHAR( 2),
               @cMM               NVARCHAR( 2),
               @cKeyName          NVARCHAR( 30),
               @cNewKey           NVARCHAR( 20)

            SET @cTrackNo = ''

            SELECT
               @cB_Contact1 = B_Contact1,
               @cB_Company = B_Company
            FROM dbo.STORER ST WITH (NOLOCK)
            WHERE StorerKey = @cConsigneeKey

            SET @cYY = YEAR( GETDATE() ) % 100
            SET @cMM = RIGHT( '0' + RTRIM( MONTH( GETDATE())), 2)

            SET @cKeyName = ''
            SET @cKeyName = 'CNK_SC'

            IF NOT EXISTS (SELECT 1 FROM dbo.NCounter WITH (NOLOCK) WHERE KeyName = @cKeyName)
            BEGIN
               SET @cNewKey = '60001'
               INSERT INTO NCounter (KeyName, KeyCount)
               VALUES (@cKeyName, @cNewKey)
            END
            ELSE
            BEGIN
               SET @cNewKey = ''

               EXECUTE nspg_getkey
                  @cKeyName
                  , 5
                  , @cNewKey          OUTPUT
                  , @bSuccess         OUTPUT
                  , @nErrNo           OUTPUT
                  , @cErrMsg          OUTPUT

               -- Big box sequential number, from 65000 to 69999, store level
               -- (e.g. store1: 65000, 65001, 65002à; store2: 65000, 65001, 65002à65222à loop it if number =69999)
               IF ISNULL(@cNewKey, '') = '79999'
               BEGIN
                  SET @cNewKey = '60001'

                  -- Reset the counter
                  UPDATE nCounter WITH (ROWLOCK) SET
                     KeyCount = 60001
                  WHERE KeyName = @cKeyName
               END
            END

            SET @cTrackNo = RTRIM( @cB_Contact1) + RTRIM( @cB_Company) + '0' + @cYY + @cMM + @cNewKey

            INSERT INTO CARTONTRACK(TRACKINGNO,CARRIERNAME,KEYNAME,LABELNO,CARRIERREF2)
            VALUES(@cTrackNo,'SLKR',@cStorerKey,@cLabelNo,'GET')
         END

         EXEC dbo.isp_BT_GenBartenderCommand
            @cLabelPrinter
            , @cLabelType
            , @cUserName
            , @cPickSlipNo
            , @nCartonNo
            , @nCartonNo
            , 'SLKR' -- @cField01
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
   GOTO QUIT

--RollBackTran:
--   ROLLBACK TRAN rdt_593ShipLabel19 -- Only rollback change made here
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam

Quit:
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
   --   COMMIT TRAN rdt_593ShipLabel19
   --EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam


GO