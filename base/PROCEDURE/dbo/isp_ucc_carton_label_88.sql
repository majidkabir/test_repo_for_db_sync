SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_UCC_Carton_Label_88                             */
/* Creation Date: 03-Jul-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9571 - [CN] Super Hub Project _                         */ 
/*                     temporary red sun_Carton Label Change (CR)       */
/*          Copy From nsp_UCC_CartonLabel_07                            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes                                        */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_88] (
            @c_StorerKey NVARCHAR(15),--ang01
            @c_PickSlipNo NVARCHAR(40),
            @c_cartonNoStart NVARCHAR(5), --ang01
            @c_cartonNoEnd NVARCHAR(5)  --ang01
)
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @c_startNumber          NVARCHAR(20),
   @c_selectedNumber       NVARCHAR(20),
   @c_endNumber            NVARCHAR(20),
   @c_externorderkey_start NVARCHAR(50),  --tlting_ext
   @c_externorderkey_end   NVARCHAR(50),  
   @c_orderkey_start       NVARCHAR(10),
   @c_orderkey_end         NVARCHAR(10),
   @nPosStart int, @nPosEnd int,
   @nDashPos                int ,
   @c_ExecStatements     nvarchar(4000),
   @c_ExecStatements1    nvarchar(4000),
   @c_ExecStatements2    nvarchar(4000),
   @c_ExecStatements3    nvarchar(4000),
   @c_ExecStatements4    nvarchar(4000),
   @c_ExecStatements5    nvarchar(4000),   --WL01
   @c_ExecStatements6    nvarchar(4000),   --WL01
   @c_ExecStatements7    nvarchar(4000),   --WL01
   @c_ExecStatementsMain nvarchar(4000),
   @c_ExecArguments      nvarchar(4000),
   @c_ShowCartonGID      NVARCHAR(20) --WL02

   IF LEFT(@c_PickSlipNo, 1) <> 'P'
   BEGIN
      IF CHARINDEX('-',@c_PickSlipNo) > 0
      BEGIN
         SET @c_PickSlipNo = @c_PickSlipNo
         SET @nDashPos = CHARINDEX('-',@c_PickSlipNo)

         --To retrieve Orderkey/ExternOrderKey Start
         SET @nPosStart = 1
         SET @nPosEnd = @nDashPos - 1

         SET @c_startNumber=(SELECT SUBSTRING(@c_PickSlipNo, @nPosStart, @nPosEnd) AS StartOrderKey)

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
         SET @c_endNumber = (SELECT SUBSTRING(@c_PickSlipNo, @nPosStart, @nPosEnd) AS EndOrderKey)

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

   --WL02
   SELECT @c_ShowCartonGID = ISNULL(SHORT,'N')
   FROM Codelkup (NOLOCK)
   WHERE Listname = 'BARCODELEN'
   AND Code = 'SUPERHUB'
   AND Storerkey = @c_StorerKey

   SET @c_ExecStatements = N'SELECT PACKHEADER.PickSlipNo,'+
   		 'PACKDETAIL.LabelNo, '+
   		 'ORDERS.InvoiceNo, '+
   		 'ORDERS.ExternOrderKey, '+
   		 'PACKDETAIL.CartonNo, '+
   		 'ORDERS.Userdefine04, '+
   		 'ORDERS.C_Company, '+
   		 'ORDERS.C_Address1, '+
   		 'ORDERS.C_Address2, '+
   		 'ORDERS.C_Address3, '+
   		 'ORDERS.C_Address4, '+
   		 'ORDERS.ConsigneeKey, '+  --(HFLiew01)
   		 'PACKHEADER.Route, '+
   		 'ORDERS.C_Zip, '+
   		 'CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + '' '' + CONVERT(CHAR(8), GetDate(), 108)),'

   IF LEFT(@c_PickSlipNo, 1) = 'P'
   BEGIN
      SET @c_ExecStatements1 = N'(SELECT COUNT(*)'+
      			'FROM PACKHEADER P (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK)'+
      			'ON P.OrderKey = OD.OrderKey '+
      			'WHERE P.PickSlipNo = @c_PickSlipNo '+
      			'AND OD.UserDefine05 > ''0'') as PriceLabel,'+
      		 'SUBSTRING(ORDERS.Notes2, 1, 30) as Notes2,'+
      		 'CASE ORDERS.Type WHEN ''D'' THEN ''D'' WHEN ''R'' THEN ''R'' ELSE Orders.type END As CartonType,'+
      		 'ORDERS.OrderKey '
   END

   IF @c_orderkey_start <> NULL AND @c_orderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements1 = N'(SELECT COUNT(*)'+
   			'FROM PACKHEADER P (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK)'+
   			'ON P.OrderKey = OD.OrderKey '+
            'WHERE  P.OrderKey BETWEEN @c_orderkey_start AND @c_orderkey_end '+
   			'AND OD.UserDefine05 > ''0'') as PriceLabel,'+
   		 'SUBSTRING(ORDERS.Notes2, 1, 30) as Notes2,'+
   		 'CASE ORDERS.Type WHEN ''D'' THEN ''D'' WHEN ''R'' THEN ''R'' ELSE Orders.type END As CartonType,'+
   		 'ORDERS.OrderKey '
   END

   IF @c_externorderkey_start <> NULL AND @c_externorderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements1 = N'(SELECT COUNT(*)'+
   			'FROM PACKHEADER P (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK)'+
   			'ON P.OrderKey = OD.OrderKey '+
            'WHERE  P.OrderRefNo BETWEEN @c_externorderkey_start AND @c_externorderkey_end '+
   			'AND OD.UserDefine05 > ''0'') as PriceLabel,'+
   		 'SUBSTRING(ORDERS.Notes2, 1, 30) as Notes2,'+
   		 'CASE ORDERS.Type WHEN ''D'' THEN ''D'' WHEN ''R'' THEN ''R'' ELSE Orders.type END As CartonType,'+
   		 'ORDERS.OrderKey '
   END
   
   SET @c_ExecStatements2 = N'FROM ORDERS ORDERS (NOLOCK) '+
     'JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)'+
     'JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  '+
     'JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)'+
     'JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) '+
     'LEFT OUTER JOIN STORER STORERContact (NOLOCK) ON ( STORERContact.Type = ''2'' AND STORERContact.StorerKey = ORDERS.ConsigneeKey)  '+
     'LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = ''11301'')'

   IF LEFT(@c_PickSlipNo, 1) = 'P'
   BEGIN
      SET @c_ExecStatements3 = N'WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo AND ORDERS.StorerKey = @c_StorerKey '+
      'AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as Int) '
   END

   IF @c_orderkey_start <> NULL AND @c_orderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements3 = N'WHERE PACKHEADER.OrderKey BETWEEN @c_orderkey_start AND @c_orderkey_end '+
      'AND ORDERS.StorerKey = @c_StorerKey '+
      'AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as Int) '
   END

   IF @c_externorderkey_start <> NULL AND  @c_externorderkey_end <> NULL
   BEGIN
      SET @c_ExecStatements3 = N'WHERE PACKHEADER.OrderRefNo BETWEEN @c_externorderkey_start AND @c_externorderkey_end '+
      'AND ORDERS.StorerKey = @c_StorerKey '+
      'AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as Int) '
   END

   SET @c_ExecStatements4 = N'GROUP BY PACKHEADER.PickSlipNo, '+
			'PACKDETAIL.LabelNo, '+
			'ORDERS.InvoiceNo, '+
			'ORDERS.ExternOrderKey, '+
			'PACKDETAIL.CartonNo, '+
			'ORDERS.Userdefine04, '+
			'ORDERS.C_Company, '+
			'ORDERS.C_Address1, '+
			'ORDERS.C_Address2, '+
			'ORDERS.C_Address3, '+
			'ORDERS.C_Address4, '+
			'ORDERS.ConsigneeKey, '+
			'PACKHEADER.Route, '+
			'ORDERS.C_Zip, '+
			'PACKHEADER.OrderKey,'+
			'SUBSTRING(ORDERS.Notes2, 1, 30),'+
			'ORDERS.Type,'+
		   'ORDERS.OrderKey'
		   
	   
   --WL01 START
   SET @c_ExecStatements5 = N',CASE WHEN ISNULL(CL.SHORT,''N'') = ''Y''
                              THEN PIF.CartonGID ELSE '''' END AS NewLabelNo,
                              ISNULL(CL.SHORT,''N'') AS ShowBarcode '
                              
   SET @c_ExecStatements6 = N'LEFT JOIN PACKINFO PIF (NOLOCK) ON PACKDETAIL.Pickslipno = PIF.Pickslipno AND PACKDETAIL.CartonNo = PIF.CartonNo ' +
                            N'OUTER APPLY (SELECT TOP 1 CL.SHORT FROM
                              CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = ''BARCODELEN'' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = ''SUPERHUB'' AND
                             (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '''') ) ORDER BY CASE WHEN CL.CODE2 = '''' THEN 2 ELSE 1 END ) AS CL '
   
   SET @c_ExecStatements7 = N',CL.SHORT, PIF.CartonGID '
   --WL01 END


   SET @c_ExecStatementsMain = @c_ExecStatements + @c_ExecStatements1 +
                             + @c_ExecStatements5 --WL01
                             + @c_ExecStatements2 
                             + @c_ExecStatements6 --WL01
                             + @c_ExecStatements3
                             + @c_ExecStatements4
                             + @c_ExecStatements7 --WL01
                      
   SET @c_ExecArguments = N'@c_PickSlipNo NVARCHAR(40), ' +
                           '@c_cartonNoStart NVARCHAR(5), ' + --ang01
                           '@c_cartonNoEnd NVARCHAR(5), ' + --ang01
                           '@c_StorerKey NVARCHAR(15), '+ --ang01
                           '@c_externorderkey_start NVARCHAR(50),'+  --tlting_ext
                           '@c_externorderkey_end   NVARCHAR(50),'+
                           '@c_orderkey_start NVARCHAR(10),'+
                           '@c_orderkey_end   NVARCHAR(10)'


   EXEC sp_ExecuteSql @c_ExecStatementsMain
                     ,@c_ExecArguments
                     ,@c_PickSlipNo
                     ,@c_cartonNoStart
                     ,@c_cartonNoEnd
                     ,@c_StorerKey
                     ,@c_externorderkey_start
                     ,@c_externorderkey_end
                     ,@c_orderkey_start
                     ,@c_orderkey_end


END


GO