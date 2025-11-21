SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_delivery_note61_rdt                                 */
/* Creation Date: 26-SEP-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-20445 -JP_PopSockets_DeliveryNote(B2B)_Datawindow_New   */
/*        :                                                             */
/* Called By: r_dw_delivery_note61_rdt                                  */
/*																                        */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 26-SEP-2022 Mingle   1.0   DevOps Combine Script(Created)            */ 
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note61_rdt]
            @c_orderkey     NVARCHAR(20) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


        SELECT ISNULL(CLR.Notes,'') AS CLRNotes,
			ORDERS.OrderKey,
			ISNULL(CLR1.Long,'') AS CLR1Long,
			ISNULL(CLR2.Long,'') AS CLR2Notes,
			ISNULL(ORDERS.B_Contact1,'') AS B_contact1,
			ISNULL(ORDERS.B_Address1,'') AS B_address1,   
         ISNULL(ORDERS.B_Address2,'') AS B_address2, 
			ISNULL(ORDERS.B_City,'') AS B_city,
			ISNULL(ORDERS.B_State,'') AS B_state,
			ISNULL(ORDERS.B_Zip,'') AS B_zip,
			ISNULL(ORDERS.C_Contact1,'') AS C_contact1,  
         ISNULL(ORDERS.C_Address1,'') AS C_address1,   
         ISNULL(ORDERS.C_Address2,'') AS C_address2,   
         ISNULL(ORDERS.C_City,'') AS C_city,   
         ISNULL(ORDERS.C_State,'') AS C_state,  
			ISNULL(ORDERS.C_Zip,'') AS C_zip,
			ORDERS.ExternOrderKey, 
			ORDERS.BuyerPO,
			FORMAT(ORDERS.OrderDate,'YYYY/MM/DD'),
			ORDERDETAIL.ExternLineNo,
			ORDERDETAIL.SKU,
			SKU.DESCR,
			ORDERDETAIL.OriginalQty,
			PICKDETAIL.Qty
    FROM ORDERS WITH (NOLOCK) 
    JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey  )  
    JOIN SKU         WITH (NOLOCK) ON ( ORDERDETAIL.StorerKey = SKU.StorerKey ) AND
                                      ( ORDERDETAIL.Sku = SKU.Sku )  
	 JOIN PICKDETAIL WITH (NOLOCK) ON (  ORDERS.Orderkey = PICKDETAIL.Orderkey AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber 
											AND ORDERDETAIL.SKU = PICKDETAIL.SKU)
	 JOIN PACKHEADER WITH (NOLOCK) ON PackHeader.LoadKey = ORDERS.LoadKey
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'LOGO' AND CLR.Listname = 'DN')  
    LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'NAME' AND CLR1.Listname = 'CUST_INFO') 
    LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'FULL_ADDR' AND CLR2.Listname = 'CUST_INFO')                                           
    --WHERE  ( ORDERS.Orderkey = @c_orderkey)
	 WHERE  ( PACKHEADER.PICKSLIPNO = @c_orderkey)
    GROUP BY ISNULL(CLR.Notes,''),
			ORDERS.OrderKey,
			ISNULL(CLR1.Long,''),
			ISNULL(CLR2.Long,''),
			ISNULL(ORDERS.B_Contact1,''),
			ISNULL(ORDERS.B_Address1,''),   
         ISNULL(ORDERS.B_Address2,''), 
			ISNULL(ORDERS.B_City,''),
			ISNULL(ORDERS.B_State,''),
			ISNULL(ORDERS.B_Zip,''),
			ISNULL(ORDERS.C_Contact1,''),  
         ISNULL(ORDERS.C_Address1,''),   
         ISNULL(ORDERS.C_Address2,''),   
         ISNULL(ORDERS.C_City,''),   
         ISNULL(ORDERS.C_State,''),  
			ISNULL(ORDERS.C_Zip,''),
			ORDERS.ExternOrderKey, 
			ORDERS.BuyerPO,
			ORDERS.OrderDate,
			ORDERDETAIL.ExternLineNo,
			ORDERDETAIL.SKU,
			SKU.DESCR,
			ORDERDETAIL.OriginalQty,
			PICKDETAIL.Qty
   
   
END -- procedure

GO