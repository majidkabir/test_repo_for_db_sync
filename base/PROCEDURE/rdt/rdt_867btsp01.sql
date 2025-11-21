SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_867BTSP01                                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick by Track No Bartender Printing SP                      */
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
/* 23-07-2013  1.0  ChewKP   Created                                    */
/* 24-02-2020  1.1  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_867BTSP01] (
        @nMobile     int
      , @nFunc       int
      , @cLangCode   nvarchar(3)
      , @cFacility   nvarchar(5)
      , @cStorerKey  nvarchar(15)
      , @cPrinterID  nvarchar(10)
      , @cOrderKey   nvarchar(10)
      , @cTrackNo    nvarchar(10)
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

   DECLARE @cLabelType  AS NVARCHAR(10)
         , @cLoadKey    AS NVARCHAR(10)
         , @cShipperKey AS NVARCHAR(10)

   SET @nErrNo     = 0
   SET @cERRMSG    = ''
   SET @cLabelType = 'SHIPPLABEL'
   SET @cLoadKey   = ''
   SET @cShipperKey  = ''

   SELECT  @cLoadKey = LoadKey
         , @cShipperKey = ShipperKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND OrderKey = @cOrderKey

   EXEC dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cPrinterID
       , @c_LabelType    = @cLabelType
       , @c_userid       = @cUserName
       , @c_Parm01       = @cLoadKey
       , @c_Parm02       = @cOrderKey
       , @c_Parm03       = ''--@cShipperKey
       , @c_Parm04       = '0'
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

GO