SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Store procedure: nsp_GenLabelNo01                                           */
/* Copyright: LF Logistics                                                     */
/*                                                                             */
/* Date       Rev  Author     Purposes                                         */
/* 23-04-2018 1.0  Ung        WMS-4625 Created (based on nsp_GenLabelNo)       */
/*******************************************************************************/
CREATE PROC [dbo].[nsp_GenLabelNo01] (
	@c_pickslipno	NVARCHAR( 10),
	@n_cartonno		INT           OUTPUT,
	@c_labelno	   NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cOrderKey              NVARCHAR( 10),
      @cStorerKey             NVARCHAR( 15),
      @cIdentifier            NVARCHAR( 2),
      @cPacktype              NVARCHAR( 1),
      @cUDF01                 NVARCHAR( 20),
      @cSUSR1                 NVARCHAR( 20),
      @nCheckDigit            INT,
      @nTotalCnt              INT,
      @nTotalOddCnt           INT,
      @nTotalEvenCnt          INT,
      @nAdd                   INT,
      @nRemain                INT,
      @nOddCnt                INT,
      @nEvenCnt               INT,
      @nOdd                   INT,
      @nEven                  INT

   DECLARE
      @c_nCounter             NVARCHAR( 25),
      @b_success              INT,
      @n_err                  INT,
      @c_errmsg               NVARCHAR( 250)

   SET @cIdentifier = '00'
   SET @cPacktype = '0'
   SET @c_LabelNo = ''
   SET @cSUSR1 = '0000000'

   /*
   SELECT @cOrderKey = OrderKey,
          @cStorerKey = StorerKey
   FROM PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @c_pickslipno
   */

   --NJOW
   SELECT @cOrderKey = ORDERS.OrderKey,
          @cStorerKey = ORDERS.StorerKey
   FROM PickHeader WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON Pickheader.Orderkey = ORDERS.Orderkey
   WHERE Pickheader.Pickheaderkey = @c_pickslipno

   SELECT @cUDF01 = RTRIM( ISNULL(UserDefine01, '0'))
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SELECT @cSUSR1 = RTRIM( ISNULL( Short, '0'))
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'GenLabelNo'
      AND Code = @cUDF01
      AND Storerkey = @cStorerKey

   SET @cUDF01 = @cStorerKey + '-' + @cUDF01

   EXEC dbo.isp_getucckey
         @cUDF01,
         9,
         @c_nCounter OUTPUT ,
         @b_success  OUTPUT,
         @n_err      OUTPUT,
         @c_errmsg   OUTPUT,
         @b_resultset = 0,
         @n_batch = 1,
         @n_joinstorer = 0

   IF LEN(@cSUSR1) <> 8
      SELECT @cSUSR1 = RIGHT('0000000' + CAST(@cSUSR1 AS VARCHAR( 7)), 7)

   SET @c_LabelNo = @cIdentifier + @cPacktype + RTRIM(@cSUSR1) + RTRIM(@c_nCounter) --+ @nCheckDigit

   SET @nOdd = 1
   SET @nOddCnt = 0
   SET @nTotalOddCnt = 0
   SET @nTotalCnt = 0

   WHILE @nOdd <= 20
   BEGIN
      SET @nOddCnt = CAST(SUBSTRING(@c_LabelNo, @nOdd, 1) AS INT)
      SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
      SET @nOdd = @nOdd + 2
   END

   SET @nTotalCnt = (@nTotalOddCnt * 3)

   SET @nEven = 2
   SET @nEvenCnt = 0
   SET @nTotalEvenCnt = 0

   WHILE @nEven <= 20
   BEGIN
      SET @nEvenCnt = CAST(SUBSTRING(@c_LabelNo, @nEven, 1) AS INT)
      SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
      SET @nEven = @nEven + 2
   END

   SET @nAdd = 0
   SET @nRemain = 0
   SET @nCheckDigit = 0

   SET @nAdd = @nTotalCnt + @nTotalEvenCnt
   SET @nRemain = @nAdd % 10
   SET @nCheckDigit = 10 - @nRemain

   IF @nCheckDigit = 10
      SET @nCheckDigit = 0

   SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
END

GO