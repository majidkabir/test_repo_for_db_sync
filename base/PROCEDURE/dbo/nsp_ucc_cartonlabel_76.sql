SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: nsp_UCC_CartonLabel_76                              */  
/* Creation Date: 14-DEC-2018                                           */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose: WMS-7272 Vitec - Carton Label (UCC + Mainfest) Enhancement  */  
/*                                                                      */  
/* Called By: r_dw_ucc_carton_label_76                                  */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date           Author      Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[nsp_UCC_CartonLabel_76] (  
            @c_StorerKey NVARCHAR(5),  
            @c_PickSlipNo NVARCHAR(40),  
            @c_cartonNoStart NVARCHAR(5),  --(ang01)  
            @c_cartonNoEnd NVARCHAR(5)    --(ang01)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
   @c_startNumber          NVARCHAR(20),  
   @c_selectedNumber       NVARCHAR(20),  
   @c_endNumber            NVARCHAR(20),  
   @c_externorderkey_start NVARCHAR(20),  
   @c_externorderkey_end   NVARCHAR(20),  
   @c_orderkey_start       NVARCHAR(10),  
   @c_orderkey_end         NVARCHAR(10),  
   @nPosStart int, @nPosEnd int,  
   @nDashPos                int ,  
   @c_ExecStatements     nvarchar(4000),  
   @c_ExecStatements1    nvarchar(4000),  
   @c_ExecStatements2    nvarchar(4000),  
   @c_ExecStatements3    nvarchar(4000),  
   @c_ExecStatements4    nvarchar(4000),  
   @c_ExecStatementsMain nvarchar(4000),  
   @c_ExecArguments      nvarchar(4000)  
  
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

   SET @c_ExecStatements = N'SELECT PACKHEADER.PickSlipNo,'+  
      'PACKDETAIL.LabelNo, '+  
      'ORDERS.ExternOrderKey, '+  
      'PACKDETAIL.CartonNo, '+
	  'PACKDETAIL.Sku, '+  
	  'SUM(PACKDETAIL.Qty) as Qty,'+
      'ORDERS.C_Company, '+  
      'ORDERS.C_Address1, '+  
      'ORDERS.C_Address2, '+  
      'ORDERS.C_Address3, '+  
      'ORDERS.C_Address4, '+   
	  'ORDERS.C_ISOCntryCode, '+
      'ORDERS.C_Zip, '+  
      'CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + '' '' + CONVERT(CHAR(8), GetDate(), 108)),'+
	  'ISNULL(PACKINFO.Weight,0),' +
	  'ISNULL(PACKINFO.[Cube],0),' 
  
   IF LEFT(@c_PickSlipNo, 1) = 'P'  OR (@c_orderkey_start <> NULL AND @c_orderkey_end <> NULL )
		OR (@c_externorderkey_start <> NULL AND @c_externorderkey_end <> NULL)
   BEGIN  
      SET @c_ExecStatements1 = 
         N'CASE ORDERS.Type WHEN ''D'' THEN ''D'' WHEN ''R'' THEN ''R'' ELSE Orders.type END As CartonType,'+  
         'ORDERS.OrderKey '  
   END  

   SET @c_ExecStatements2 = N'FROM ORDERS ORDERS (NOLOCK) '+  
     'JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)'+  
     'JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  '+
	 'LEFT JOIN PACKINFO (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKINFO.PicKSlipNo AND PACKDETAIL.CartonNo = PACKINFO.CartonNo)'-- +    
  
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
   'ORDERS.ExternOrderKey, '+ 
   'PACKDETAIL.CartonNo, '+  
   'PACKDETAIL.Sku,' +
   'PACKDETAIL.Qty,' +
   'ORDERS.C_Company, '+  
   'ORDERS.C_Address1, '+  
   'ORDERS.C_Address2, '+  
   'ORDERS.C_Address3, '+  
   'ORDERS.C_Address4, '+
   'ORDERS.C_ISOCntryCode, '+ 
   'ORDERS.C_Zip, '+  
   'ORDERS.Type,'+  
   'ORDERS.OrderKey,'+
   'ISNULL(PACKINFO.Weight,0),'+
   'ISNULL(PACKINFO.[Cube],0)' 
  
   SET @c_ExecStatementsMain = @c_ExecStatements + @c_ExecStatements1 + @c_ExecStatements2+ @c_ExecStatements3+ @c_ExecStatements4  
   SET @c_ExecArguments = N'@c_PickSlipNo NVARCHAR(40), ' +  
                           '@c_cartonNoStart NVARCHAR(5), ' +  --(ang01)  
                           '@c_cartonNoEnd NVARCHAR(5), ' +  --(ang01)  
                           '@c_StorerKey NVARCHAR(5), '+  
                           '@c_externorderkey_start NVARCHAR(20),'+  
                           '@c_externorderkey_end   NVARCHAR(20),'+  
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