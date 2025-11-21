SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_816BTSP01                                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: ANF PTS Bartender Printing SP                               */
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
/* 28-01-2014  1.0  ChewKP   Created                                    */
/* 05-06-2014  1.1  Chee     Prevent printing DCtoStore label when      */
/*                           pickslip has child order generated (Chee01)*/
/* 28-07-2016  1.2  ChewKP   SOS#373985 - CR for Order.Type = 'AFWHSALE'*/
/*                           (ChewKP01)                                 */
/* 24-02-2020  1.3  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_816BTSP01] (
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

   SET @nErrNo     = 0
   SET @cERRMSG    = ''
   SET @cLabelType = 'SHIPPLABELANF'
   SET @cPickSlipNo = ''
   SET @cOrderType = ''
   SET @cLabelFlag = ''

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE DropID = @cDropID
   AND LabelNo = @cLabelNo

   SELECT Top 1 @cOrderType = O.Type
   FROM dbo.Orders O WITH (NOLOCK)
   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
   WHERE PD.PickSlipNo = @cPickSlipNo
     AND O.Type <> 'CHDORD' -- (Chee01)


   IF ISNULL(RTRIM(@cOrderType),'') IN ('DCtoDC','StrtoIRL', 'Destroy')
   BEGIN
      SET @cLabelFlag = '0' -- DC to DC
   END
   ELSE IF ISNULL(RTRIM(@cOrderType),'') ='AFWHSALE' -- (ChewKP01)
   BEGIN
      SET @cLabelFlag = '2' -- AFWHSALE
   END
   ELSE
   BEGIN
      SET @cLabelFlag = '1' -- DC to Store
   END

   EXEC dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cPrinterID
       , @c_LabelType    = @cLabelType
       , @c_userid       = @cUserName
       , @c_Parm01       = @cLoadKey
       , @c_Parm02       = '' -- OrderKey
       , @c_Parm03       = @cLabelNo
       , @c_Parm04       = '' -- OrderType
       , @c_Parm05       = @cDropID
       , @c_Parm06       = ''
       , @c_Parm07       = @cLabelFlag
       , @c_Parm08       = ''
       , @c_Parm09       = ''
       , @c_Parm10       = ''
       , @c_StorerKey    = @cStorerKey
       , @c_NoCopy       = '1'
       , @b_Debug        = '0'
       , @c_Returnresult = 'N'
       , @n_err          = @nErrNo  OUTPUT
       , @c_errmsg       = @cERRMSG OUTPUT

   -- To Proceed PTS while printing having error --
   SET @nErrNo     = 0
   SET @cERRMSG    = ''

END

GO