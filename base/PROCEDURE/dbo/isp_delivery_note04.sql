SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Delivery_Note04    	      						   */
/* Creation Date: 04/01/2010                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#199965                                                  */
/*                                                                      */
/* Called By: r_dw_delivery_note04                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 29-Jun-2011  NJOW    1.0   218624 - Add Logo                         */
/* 14-Mar-2012  KHLim01 1.2   Update EditDate                           */       
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note04] (@c_mbolkey NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF
               
    SELECT ORDERS.ExternOrderKey,
	  		  ORDERS.BillToKey,
	  		  ORDERS.B_Company,
	  		  ORDERS.B_Address1,
	  		  ORDERS.B_Address2,
	  		  ORDERS.B_Address3,
	  		  ORDERS.B_Address4,
	  		  ORDERS.B_Zip,
	  		  ORDERS.B_Country,
           ORDERS.ConsigneeKey,  
           ORDERS.C_Company,  
           ORDERS.C_Address1,  
           ORDERS.C_Address2,  
           ORDERS.C_Address3,  
           ORDERS.C_Address4,  
	  		  ORDERS.C_Zip,
	  		  ORDERS.C_Country,
           ORDERS.IntermodalVehicle, 
           ORDERS.DeliveryPlace,  
           ORDERS.DischargePlace,
           CAST(ORDERS.Notes AS NVARCHAR(250)) AS Notes,
           ORDERS.BuyerPO,  
           ORDERS.OrderKey, 
	  		  ORDERDETAIL.SKU,
	  		  SKU.DESCR, 
	  		  LOTATTRIBUTE.Lottable02,
	  		  LOTATTRIBUTE.Lottable04,
           SUM(PICKDETAIL.Qty) AS QtyPicked,
           CASE WHEN ISNULL(PACK.PackUOM1, '') <> ''
                THEN PACK.PackUOM1
           ELSE PACK.PackUOM3 END AS UOM,
           CASE WHEN ISNULL(PACK.PackUOM1, '') <> ''
                THEN PACK.CaseCnt
           ELSE PACK.Qty END AS PACKQty,
           Storer.Company,
           Storer.Address1,
           Storer.Address2,
           Storer.Address3,
           Storer.Address4,
           Storer.Zip,
           Storer.Country,
           ORDERS.Mbolkey,
           ORDERS.Loadkey,
           ORDERS.Printflag,
           Storer.Logo
      INTO #TMP_DO
      FROM SKU (nolock),
           PACK (nolock),  	 
           ORDERS (nolock),  
           ORDERDETAIL (nolock),
           PICKDETAIL (nolock),
           LOTATTRIBUTE (nolock),
           STORER (nolock)
     WHERE ( SKU.StorerKey = ORDERDETAIL.Storerkey ) and 
           ( SKU.Sku = ORDERDETAIL.Sku ) and 
           ( SKU.PackKey = PACK.PackKey ) and 
           ( ORDERS.OrderKey = ORDERDETAIL.OrderKey ) and  
           ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) and  
           ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber ) and  
           ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot) and  
           ( ORDERS.StorerKey = STORER.Storerkey ) and 
           ( ORDERS.Status >= '5' ) and  
           ( ORDERS.Mbolkey = @c_mbolkey )   
	  GROUP BY ORDERS.ExternOrderKey,
	  		  ORDERS.BillToKey,
	  		  ORDERS.B_Company,
	  		  ORDERS.B_Address1,
	  		  ORDERS.B_Address2,
	  		  ORDERS.B_Address3,
	  		  ORDERS.B_Address4,
	  		  ORDERS.B_Zip,
	  		  ORDERS.B_Country,
	  		  ORDERS.B_Phone1,
           ORDERS.ConsigneeKey,  
           ORDERS.C_Company,  
           ORDERS.C_Address1,  
           ORDERS.C_Address2,  
           ORDERS.C_Address3,  
           ORDERS.C_Address4, 
	  		  ORDERS.C_Zip,
	  		  ORDERS.C_Country,
           ORDERS.C_Phone1,
           ORDERS.IntermodalVehicle,  
           ORDERS.DeliveryPlace,
           ORDERS.DischargePlace, 
           CAST(ORDERS.Notes AS NVARCHAR(250)),
           ORDERS.BuyerPO,
           ORDERS.OrderKey,  
	  		  ORDERDETAIL.SKU,
	  		  SKU.DESCR,
	  		  LOTATTRIBUTE.Lottable02,
	  		  LOTATTRIBUTE.Lottable04,
           CASE WHEN ISNULL(PACK.PackUOM1, '') <> ''
                THEN PACK.PackUOM1
           ELSE PACK.PackUOM3 END,
           CASE WHEN ISNULL(PACK.PackUOM1, '') <> ''
                THEN PACK.CaseCnt
           ELSE PACK.Qty END,
           Storer.Company,
           Storer.Address1,
           Storer.Address2,
           Storer.Address3,
           Storer.Address4,
           Storer.Zip,
           Storer.Country,  
           ORDERS.Mbolkey,
           ORDERS.Loadkey,
           ORDERS.Printflag,
           Storer.Logo
     
      UPDATE ORDERS WITH (ROWLOCK)
      SET PrintFlag = 'Y',
          EditDate = GETDATE(), -- KHLim01
          TrafficCop = NULL
      WHERE Mbolkey = @c_mbolkey           
          
      SELECT * FROM #TMP_DO
END       

GO