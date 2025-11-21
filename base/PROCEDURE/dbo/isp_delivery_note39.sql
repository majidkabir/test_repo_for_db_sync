SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note39                                 */
/* Creation Date: 2019-09-19                                             */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-10610 -[SG] SG-WGSSG – DN Special Handling Remark        */
/*                                                                       */
/* Called By: r_dw_delivery_note39                                       */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 22-Jan-2020  CSCHONG 1.1   WMS-11829 add qrcode (CS01)                */
/*************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note39] 
         (  @c_Orderkey    NVARCHAR(10) )           
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ShowLuxuryWording NVARCHAR(1) = ''

   IF EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK) 
              JOIN SKU (NOLOCK) ON ORDERDETAIL.SKU = SKU.SKU
              AND ORDERDETAIL.STORERKEY = SKU.STORERKEY WHERE ORDERDETAIL.ORDERKEY = @c_Orderkey
              AND SKU.SKUGroup = 'LUXURY' )
   BEGIN
      SET @c_ShowLuxuryWording = 'Y'
   END
   ELSE
   BEGIN
      SET @c_ShowLuxuryWording = ''
   END

   SELECT ORDERS.C_Company,   
          ORDERS.C_Address1,   
          ORDERS.C_Address2,   
          ORDERS.C_Address3,   
          ORDERS.C_Address4,   
          ORDERS.Notes,   
          STORER.Company,   
          ORDERS.AddDate,   
          ORDERS.ExternOrderKey,   
          ORDERS.OrderKey,   
          ORDERS.Door,   
          ORDERS.Route,   
          SKU.DESCR,   
          SUM(PICKDET.Qty) AS ORDERDETAIL_QtyPicked,   
          ORDERDETAIL.SKU  ,
          ORDERS.DeliveryNote,
          PACK.CaseCnt,  
          ORDERS.Rdd,  
          STORER.Logo,
          ORDERS.BuyerPO,
          Signatory = CASE WHEN ISNULL(RTRIM(ST.Contact2),'') = '' THEN 'LF Logistics' ELSE ST.Contact2 END,
          LOTT.Lottable01,
          LOTT.Lottable02,
          MD.Containerkey,
          ORDERS.Storerkey,
          ORDERS.Deliverydate,
          ISNULL(CLR.short,'N') as ShowField,
          ISNULL(CLR1.short,'N') as Showlogo,
          ISNULL(CLR3.short,'N') as Showmbolkey,
          ORDERS.Mbolkey  as Mbolkey,
          ISNULL(CLR4.short,'N') as ShowBarcode,
          ISNULL(CLR5.short,'N') as ShowAvailQty,
          CASE WHEN ISNULL(CLR5.short,'N') = 'Y' THEN LLI.Qty ELSE 0 END AS LLIQty,
          ISNULL(CLR6.short,'N') as ShowLast4CharsOfNRIC,
          @c_ShowLuxuryWording as ShowLuxuryWording
         ,ISNULL(CLR7.short,'N') as Showqrcode            --CS01
   FROM ORDERS WITH (nolock) 
   JOIN STORER WITH (nolock)      ON ( ORDERS.StorerKey = STORER.StorerKey )
   JOIN ORDERDETAIL WITH (nolock) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )  
   JOIN SKU         WITH (nolock) ON ( ORDERDETAIL.StorerKey = SKU.StorerKey ) and
                                      ( ORDERDETAIL.Sku = SKU.Sku )    
   JOIN PACK        WITH (nolock) ON ( SKU.PackKey = PACK.PackKey ) 
   LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = 'IDS')    
   LEFT JOIN STORER ST1 WITH (nolock)      ON ( ORDERS.consigneekey = ST1.StorerKey )
   LEFT JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = ORDERS.Orderkey)     
   CROSS APPLY (select DISTINCT storerkey,sku,lot,sum(qty) as qty  FROM PICKDETAIL PIDET WITH (NOLOCK) WHERE PIDET.Orderkey=ORDERDETAIL.Orderkey AND PIDET.Storerkey=ORDERDETAIL.Storerkey 
                AND PIDET.OrderLineNumber=ORDERDETAIL.OrderLineNumber GROUP BY  storerkey,sku,lot) AS PICKDET 
   CROSS APPLY (SELECT SUM(Qty) AS Qty FROM LOTxLOCxID (NOLOCK) 
                WHERE LOTxLOCxID.LOT = PICKDET.LOT AND LOTxLOCxID.STORERKEY = PICKDET.STORERKEY AND LOTxLOCxID.SKU = PICKDET.SKU)  AS LLI
   LEFT JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.storerkey = PICKDET.storerkey AND LOTT.sku=PICKDET.sku  AND LOTT.Lot=PICKDET.lot)
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_delivery_note39' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWLOGO'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_delivery_note39' AND ISNULL(CLR1.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR3.Storerkey AND CLR3.Code = 'SHOWMBOLKEY'   
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_delivery_note39' AND ISNULL(CLR3.Short,'') <> 'N')  
   LEFT OUTER JOIN Codelkup CLR4 (NOLOCK) ON (Orders.Storerkey = CLR4.Storerkey AND CLR4.Code = 'ShowBarcode'   
                                       AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_delivery_note39' AND ISNULL(CLR4.Short,'') <> 'N') 
   LEFT OUTER JOIN Codelkup CLR5  (NOLOCK) ON (Orders.Storerkey = CLR5.Storerkey AND CLR5.Code = 'ShowAvailQty'   
                                       AND CLR5.Listname = 'REPORTCFG' AND CLR5.Long = 'r_dw_delivery_note39' AND ISNULL(CLR5.Short,'') <> 'N') 
   LEFT OUTER JOIN Codelkup CLR6  (NOLOCK) ON (Orders.Storerkey = CLR6.Storerkey AND CLR6.Code = 'ShowLast4CharsOfNRIC'   
                                       AND CLR6.Listname = 'REPORTCFG' AND CLR6.Long = 'r_dw_delivery_note39' AND ISNULL(CLR6.Short,'') <> 'N') 
   LEFT JOIN CODELKUP CLR7 WITH (NOLOCK) ON CLR7.LISTNAME='REPORTCFG' AND CLR7.Long='r_dw_delivery_note39' --CS01
                                       AND CLR7.code = 'SHOWQRCODE' AND CLR7.Storerkey=ORDERS.storerkey
                                        AND ISNULL(CLR7.Short,'') <> 'N'
   WHERE  ( ORDERS.Orderkey = @c_Orderkey)
   GROUP BY ORDERS.C_Company,   
            ORDERS.C_Address1,   
            ORDERS.C_Address2,   
            ORDERS.C_Address3,   
            ORDERS.C_Address4,   
            ORDERS.Notes,   
            STORER.Company,   
            ORDERS.AddDate,   
            ORDERS.ExternOrderKey,   
            ORDERS.OrderKey,   
            ORDERS.Door,   
            ORDERS.Route,   
            SKU.DESCR,   
            --PICKDET.Qty,   
            ORDERDETAIL.SKU  ,
            ORDERS.DeliveryNote,
            PACK.CaseCnt,  
            ORDERS.Rdd,  
            STORER.Logo,
            ORDERS.BuyerPO,
            ST.Contact2 ,
            LOTT.Lottable01,
            LOTT.Lottable02,
            MD.Containerkey,
            ORDERS.Storerkey,
            ORDERS.Deliverydate,
            ISNULL(CLR.short,'N'), 
            ISNULL(CLR1.short,'N'), 
            ISNULL(CLR3.short,'N'), 
            ORDERS.Mbolkey,
            ISNULL(CLR4.short,'N'), 
            ISNULL(CLR5.short,'N'),
            CASE WHEN ISNULL(CLR5.short,'N') = 'Y' THEN LLI.Qty ELSE 0 END,
            ISNULL(CLR6.short,'N')
           ,ISNULL(CLR7.short,'N') -- (CS01)
             
QUIT_SP:  
END       

GO