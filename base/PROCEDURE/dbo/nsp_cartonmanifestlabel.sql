SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_CartonManifestLabel                             */
/* Creation Date: 16-May-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: HFLIEW                                                   */
/*                                                                      */
/* Purpose: SOS#101322 - Generate Carton Manifest Label                 */
/*                                                                      */
/* Called By: Power Builder Object                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:																					*/
/* Date           Author       Purposes                                 */
/* 20-Apr-2011    Audrey  1.1  SOS#213209 - Extend length cartonNo      */
/*                             from 3 to 5  (ang01)                     */
/* 24-May-2016   CSCHONG  1.2  SOS#370366 - run report error (CS01)     */
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[nsp_CartonManifestLabel] (
            @c_PickSlipNo NVARCHAR(40),
            @c_cartonNoStart NVARCHAR(5), --(ang01)
            @c_cartonNoEnd NVARCHAR(5)  --(ang01)
)
AS
BEGIN
   
   SET ANSI_WARNINGS OFF
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @c_startNumber NVARCHAR(20),
   @c_selectedNumber NVARCHAR(20),
   @c_endNumber NVARCHAR(20),
   @c_externorderkey_start NVARCHAR(50),   --tlting_ext
   @c_externorderkey_end   NVARCHAR(50),
   @c_orderkey_start NVARCHAR(10),
   @c_orderkey_end   NVARCHAR(10),
   @nPosStart int, @nPosEnd int,
   @nDashPos int ,
   @c_ExecStatements nvarchar(4000),
   @c_ExecStatements1 nvarchar(4000),
   @c_ExecStatements2 nvarchar(4000),
   @c_ExecStatements3 nvarchar(4000),
   @c_ExecStatements4 nvarchar(4000),
   @c_ExecStatements5 nvarchar(4000),
   @c_ExecStatements6 nvarchar(4000),
   @c_ExecStatementsMain nvarchar(4000),
   @c_ExecArguments nvarchar(4000)

   IF LEFT(@c_PickSlipNo, 1) <> 'P'
   BEGIN
      IF CharIndex('-',@c_PickSlipNo) > 0
      BEGIN
         SET @c_PickSlipNo = @c_PickSlipNo
         SET @nDashPos = charindex('-',@c_PickSlipNo)

         --To retrieve Orderkey/ExternOrderKey Start
         SET @nPosStart = 1
         SET @nPosEnd = @nDashPos - 1

         SET @c_startNumber=(SELECT substring(@c_PickSlipNo, @nPosStart, @nPosEnd) AS StartOrderKey)

         SET @c_selectedNumber = (SELECT ISNULL(orderkey,0) FROM Orders (NOLOCK) WHERE orderkey = @c_startNumber)
         IF @c_selectedNumber <> NULL
         BEGIN
            SET @c_orderkey_start = @c_startNumber
         END
         ELSE
         BEGIN
            SET @c_externorderkey_start = @c_startNumber
         END

         --To retrieve Orderkey/ExternOrderKey End
         SET @nPosStart = @nDashPos + 1
         SET @nPosEnd =  LEN(@c_PickSlipNo) - @nDashPos
         SET @c_endNumber = (SELECT substring(@c_PickSlipNo, @nPosStart, @nPosEnd) AS EndOrderKey)

         SET @c_selectedNumber = (SELECT ISNULL(orderkey,0) FROM orders (NOLOCK) WHERE orderkey = @c_endNumber)
         IF @c_selectedNumber <> NULL
         BEGIN
            SET @c_orderkey_end = @c_endNumber
         END
         ELSE
         BEGIN
            SET @c_externorderkey_end = @c_endNumber
         END
      END
      ELSE
      BEGIN
         SET @c_startNumber = (SELECT ISNULL(orderkey,0) FROM orders (NOLOCK) WHERE orderkey = @c_PickSlipNo)
         IF @c_startNumber <> NULL
         BEGIN
            SET @c_orderkey_start = @c_PickSlipNo
            SET @c_orderkey_end = @c_PickSlipNo
         END
         ELSE
         BEGIN
            SET @c_externorderkey_start = @c_PickSlipNo
            SET @c_externorderkey_end = @c_PickSlipNo
         END
      END
   END

   SET @c_ExecStatements = N'SELECT PACKHEADER.PickSlipNo,'+
   		 'PACKHEADER.OrderRefNo,'+
   		 'PACKDETAIL.LabelNo,'+
   		 'PACKDETAIL.CartonNo,'+
   		 'PACKDETAIL.Sku, '+
          'ORDERS.ExternOrderKey,'+
          'ORDERS.OrderKey,'+
          'ISNULL(PACKINFO.Weight,0),'+
          'ISNULL(PACKINFO.[Cube],0),'+
          'SUBSTRING(CARTONIZATION.CartonDescription,1,25) CTNDESC, '
   IF LEFT(@c_PickSlipNo, 1) = 'P'
   BEGIN
      SET @c_ExecStatements1 = N'(SELECT ISNULL(MAX(PD.CartonNo), 0) '+
      		                     'FROM PACKDETAIL PD (NOLOCK) JOIN PACKHEADER PH (NOLOCK)'+
      				               'ON PD.PickSlipNo = PH.PickSlipNo AND PH.PickSlipNo  = @c_PickSlipNo '+
      		                     'HAVING SUM(PD.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)'+
                                 'JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = OD2.Orderkey '
   END

   IF @c_orderkey_start <> NULL AND @c_orderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements1 = N'(SELECT ISNULL(MAX(PD.CartonNo), 0) '+
      									  'FROM PACKDETAIL PD (NOLOCK) JOIN PACKHEADER PH (NOLOCK)'+
      									  'ON PH.pickslipno = PD.pickslipno AND PH.OrderKey BETWEEN @c_orderkey_start AND @c_orderkey_end '+
      									  'HAVING SUM(PD.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)'+
                                   'JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = OD2.Orderkey '
   END

   IF @c_externorderkey_start <> NULL AND  @c_externorderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements1 =N'(SELECT ISNULL(MAX(PD.CartonNo), 0) '+
      								  'FROM PACKDETAIL PD (NOLOCK) JOIN PACKHEADER PH (NOLOCK)'+
      								  ' ON PH.pickslipno = PD.pickslipno AND PH.OrderRefNo BETWEEN @c_externorderkey_start AND @c_externorderkey_end '+
      								  'HAVING SUM(PD.Qty) = (SELECT SUM(QtyAllocated+QtyPicked+ShippedQty) FROM ORDERDETAIL OD2 (NOLOCK)'+
                                'JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = OD2.Orderkey '
   END

   IF LEFT(@c_PickSlipNo, 1) = 'P'
   BEGIN
      SET @c_ExecStatements2 = N'WHERE PH.PickSlipNo = @c_PickSlipNo '+
      										') ) as CartonMax,'+
      									 'SUM(PACKDETAIL.Qty) as Qty,'+
      									 'CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + '' '' + CONVERT(CHAR(8), GetDate(), 108)) as PrintDate,'+
      									 'ORDERS.UserDefine04,'+
      									 'MAX(Price.Cnt) as PriceLabel '
   END

   IF @c_orderkey_start <> NULL AND @c_orderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements2 = N'WHERE '+
      										'OD2.OrderKey BETWEEN @c_orderkey_start AND @c_orderkey_end '+
      										') ) as CartonMax,'+
      									 'SUM(PACKDETAIL.Qty) as Qty,'+
      									 'CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + '' '' + CONVERT(CHAR(8), GetDate(), 108)) as PrintDate,'+
      									 'ORDERS.UserDefine04,'+
      									 'MAX(Price.Cnt) as PriceLabel '
   END

   IF @c_externorderkey_start <> NULL AND  @c_externorderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements2 = N'WHERE '+
      								'OD2.ExternOrderKey BETWEEN @c_externorderkey_start AND @c_externorderkey_end) ) as CartonMax,'+
      								'SUM(PACKDETAIL.Qty) as Qty,'+
      								'CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + '' '' + CONVERT(CHAR(8), GetDate(), 108)) as PrintDate,'+
      								'ORDERS.UserDefine04,'+
      								'MAX(Price.Cnt) as PriceLabel '
   END

   SET @c_ExecStatements3 = N'FROM PACKHEADER (NOLOCK) '+
										'JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)'+
										'LEFT JOIN PACKINFO (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKINFO.PicKSlipNo AND PACKDETAIL.CartonNo = PACKINFO.CartonNo)' +
										'JOIN ORDERS (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)'+
										'LEFT JOIN CARTONIZATION (NOLOCK) ON (PACKINFO.CartonType = CARTONIZATION.CartonType)'+
										'JOIN (SELECT PD.Sku, PD.CartonNo, CASE WHEN MAX(OD.UserDefine05) > ''0'' THEN 1 ELSE 0 END as Cnt '+
   									'FROM PACKDETAIL PD (NOLOCK) JOIN PACKHEADER PH (NOLOCK)'+
   									'ON PD.PickSlipNo = PH.PickSlipNo '+
   									'JOIN ORDERDETAIL OD (NOLOCK)'+
   									'ON PD.Sku = OD.Sku '+
   	   							'AND PH.OrderKey = OD.OrderKey '


   IF LEFT(@c_PickSlipNo, 1) = 'P'
   BEGIN
      SET @c_ExecStatements4 = N'WHERE '+
										'PH.PickSlipNo = @c_PickSlipNo '+
      								'AND PD.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as int)'+
      								'GROUP BY PD.Sku, PD.CartonNo) as Price '+
      								'ON PACKDETAIL.CartonNo = Price.CartonNo '+
      								'AND PACKDETAIL.Sku = Price.Sku '
   END

   IF @c_orderkey_start <> NULL AND @c_orderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements4 = N'WHERE PH.OrderKey BETWEEN @c_orderkey_start AND @c_orderkey_end '+
      								'AND PD.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as int)'+
      								'GROUP BY PD.Sku, PD.CartonNo) as Price '+
      								'ON PACKDETAIL.CartonNo = Price.CartonNo '+
      								'AND PACKDETAIL.Sku = Price.Sku '
   END

   IF @c_externorderkey_start <> NULL AND  @c_externorderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements4 = N'WHERE '+
      								'PH.OrderRefNo BETWEEN @c_externorderkey_start AND @c_externorderkey_end '+
      								'AND PD.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as int)'+
      								'GROUP BY PD.Sku, PD.CartonNo) as Price '+
      								'ON PACKDETAIL.CartonNo = Price.CartonNo '+
      								'AND PACKDETAIL.Sku = Price.Sku '
   END

   IF LEFT(@c_PickSlipNo, 1) = 'P'
   BEGIN
      SET @c_ExecStatements5 = N'WHERE '+
                              'PACKHEADER.PickSlipNo = @c_PickSlipNo '+
      	                     'AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as int)'
   END

   IF @c_orderkey_start <> NULL AND @c_orderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements5 = N'WHERE PACKHEADER.OrderKey BETWEEN @c_orderkey_start AND @c_orderkey_end '+
      	                     'AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as int)'
   END

   IF @c_externorderkey_start <> NULL AND  @c_externorderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements5 = N'WHERE '+
      								'PACKHEADER.OrderRefNo BETWEEN @c_externorderkey_start AND @c_externorderkey_end '+
      								'AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as int)'
   END

   SET @c_ExecStatements6 = N'GROUP BY PACKHEADER.PickSlipNo, '+
   								 'PACKHEADER.Orderkey,'+
   								 'PACKHEADER.OrderRefNo,'+
   								 'PACKDETAIL.LabelNo,'+
   								 'PACKDETAIL.CartonNo,'+
   								 'PACKDETAIL.Sku,'+
   								 'ORDERS.UserDefine04,'+
   								 'ORDERS.ExternOrderKey,'+
									 'ORDERS.OrderKey,'+
									 'PACKINFO.Weight  ,'+
									 'PACKINFO.[Cube],'+                          --(CS01)
									 'CARTONIZATION.CartonDescription,'+
									 'PACKHEADER.PickSlipNo,'+
									 'PACKDETAIL.Qty'

      SET @c_ExecStatementsMain = @c_ExecStatements + @c_ExecStatements1 + @c_ExecStatements2+ @c_ExecStatements3+
                                  @c_ExecStatements4+ @c_ExecStatements5 +@c_ExecStatements6
      SET @c_ExecArguments = N'@c_PickSlipNo NVARCHAR(40), ' +
                              '@c_cartonNoStart NVARCHAR(5), ' + --(ang01)
                              '@c_cartonNoEnd NVARCHAR(5), ' + --(ang01)
                              '@c_externorderkey_start NVARCHAR(50),'+   --tlting_ext
                              '@c_externorderkey_end   NVARCHAR(50),'+
                              '@c_orderkey_start NVARCHAR(10),'+
                              '@c_orderkey_end   NVARCHAR(10)'

      EXEC sp_ExecuteSql @c_ExecStatementsMain
                        ,@c_ExecArguments
                        ,@c_PickSlipNo
                        ,@c_cartonNoStart
                        ,@c_cartonNoEnd
                        ,@c_externorderkey_start
                        ,@c_externorderkey_end
                        ,@c_orderkey_start
                        ,@c_orderkey_end
END

GO