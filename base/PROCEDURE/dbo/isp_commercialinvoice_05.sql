SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_commercialinvoice_05                           */    
/* Creation Date: 17-Jan-2019                                           */    
/* Copyright: IDS                                                       */    
/* Written by: WLCHOOI                                                  */    
/*                                                                      */    
/* Purpose:   WMS-7655 - [SG] JUUL Invoice                              */    
/*                                                                      */    
/*                                                                      */    
/* Called By: report dw = r_dw_commercialinvoice_05                     */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_commercialinvoice_05] (    
   @c_MBOLKey NVARCHAR(21)     
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    

   DECLARE @n_continue INT

   SET @n_continue = 1

   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
	   SELECT  LTRIM(RTRIM(ISNULL(ST.B_Company,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address1,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address2,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address3,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address4,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_City,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_State,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Zip,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.InvoiceNo,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Company,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address2,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address3,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address4,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_City,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_State,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Zip,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Contact1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Phone1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Company,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address2,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address3,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address4,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_City,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_State,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Zip,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Contact1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Phone1,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.IncoTerm,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.IntermodalVehicle,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.PmtTerm,'')))
					   ,PID.DropID
					   ,LTRIM(RTRIM(PID.Sku))
					   ,LTRIM(RTRIM(SKU.DESCR))
					   ,SUM(PID.Qty)
					   ,ISNULL(ORDET.UOM,'')
					   ,ISNULL(ORDET.UnitPrice,0.00)
					   ,ISNULL(ORDET.Tax01,0.00)
					   ,ISNULL(ORDET.ExtendedPrice,0.00)
					   ,ISNULL(ORD.Userdefine06,'1900-01-01 00:00:00.000')
					   ,ISNULL(ORD.BillToKey,'')
					   ,ISNULL(ORD.CurrencyCode,'')
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Contact1,'')))
					   ,ISNULL(ST.NOTES1,'')
					   ,ORD.Orderkey
					   ,CASE WHEN (ISNULL(ORD.Userdefine05,'') = '' AND ISNUMERIC(LTRIM(RTRIM(ORD.Userdefine05))) = 0 )
                   THEN 0.00 ELSE CAST(LTRIM(RTRIM(ORD.Userdefine05)) AS FLOAT ) END
                  ,LTRIM(RTRIM(ISNULL((SELECT STORER.EMAIL1 FROM STORER (NOLOCK) WHERE STORER.STORERKEY = ORD.CONSIGNEEKEY AND STORER.CONSIGNEEFOR = 'JUUL'),'')))
	   FROM MBOLDETAIL MD (NOLOCK)
	   JOIN ORDERS ORD (NOLOCK) ON MD.ORDERKEY = ORD.ORDERKEY
	   JOIN ORDERDETAIL ORDET (NOLOCK) ON ORDET.ORDERKEY = ORD.ORDERKEY
	   JOIN STORER ST (NOLOCK) ON ST.STORERKEY = ORD.STORERKEY
	   JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = ORDET.ORDERKEY AND PID.OrderLineNumber = ORDET.OrderLineNumber
									   AND PID.Sku = ORDET.Sku
	   JOIN SKU (NOLOCK) ON SKU.SKU = ORDET.SKU AND ORD.StorerKey = SKU.StorerKey
	   JOIN PACK (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY
	   WHERE MD.MbolKey = @c_MBOLKey
	   GROUP BY LTRIM(RTRIM(ISNULL(ST.B_Company,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address1,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address2,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address3,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Address4,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_City,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_State,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Zip,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.B_Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.InvoiceNo,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Company,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address2,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address3,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Address4,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_City,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_State,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Zip,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Contact1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Phone1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Company,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address2,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address3,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Address4,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_City,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_State,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Zip,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Contact1,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Phone1,'')))
					   ,LTRIM(RTRIM(ISNULL(ST.Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.C_Country,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.IncoTerm,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.IntermodalVehicle,'')))
					   ,LTRIM(RTRIM(ISNULL(ORD.PmtTerm,'')))
					   ,PID.DropID
					   ,LTRIM(RTRIM(PID.Sku))
					   ,LTRIM(RTRIM(SKU.DESCR))
					   ,ISNULL(ORDET.UOM,'')
					   ,ISNULL(ORDET.UnitPrice,0.00)
					   ,ISNULL(ORDET.Tax01,0.00)
					   ,ISNULL(ORDET.ExtendedPrice,0.00)
					   ,ISNULL(ORD.Userdefine06,'1900-01-01 00:00:00.000')
					   ,ISNULL(ORD.BillToKey,'')
					   ,ISNULL(ORD.CurrencyCode,'')
					   ,LTRIM(RTRIM(ISNULL(ORD.B_Contact1,'')))
					   ,ISNULL(ST.NOTES1,'')
					   ,ORD.Orderkey
                  ,CASE WHEN (ISNULL(ORD.Userdefine05,'') = '' AND ISNUMERIC(LTRIM(RTRIM(ORD.Userdefine05))) = 0 )
                   THEN 0.00 ELSE CAST(LTRIM(RTRIM(ORD.Userdefine05)) AS FLOAT ) END
                  ,ORD.Consigneekey
			   ORDER BY ORD.Orderkey ASC
	END

QUIT:    
END    


GO