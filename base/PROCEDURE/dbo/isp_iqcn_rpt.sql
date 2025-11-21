SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_IQCn_Rpt                                               */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 26-Nov-2013  TLTING    1.1   Change user_name() to SUSER_SNAME()        */
/* 28-Jan-2019  TLTING    1.2  enlarge externorderkey field length         */
/***************************************************************************/    
CREATE PROC [dbo].[isp_iqcn_rpt] (
   @c_storerkey NVARCHAR(15),
   @d_orderdate_start datetime,
   @d_orderdate_end datetime
)
as 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
declare @d_orderdate datetime,
        @c_orderkey NVARCHAR(10),
        @c_orderlinenumber NVARCHAR(5),
        @c_externorderkey NVARCHAR(50),   --tlting_ext
        @c_sku NVARCHAR(20),
        @n_openqty int,
        @n_originalqty int,
        @c_status NVARCHAR(10),
        @n_sum_pickedqty int,
        @n_sum_shippedqty int,
        @n_shippedqty int

select ORDERS.OrderDate,   
       ORDERS.OrderKey,   
       ORDERS.ExternOrderKey,   
       ORDERDETAIL.Sku,   
       SUM (OrderDetail.OriginalQty) AS OriginalQty,
       SUM (OrderDetail.ShippedQty) AS ShippedQty,
       SUser_SName() AS User_Name,
       Storer.Company,
       @d_orderdate_start as StartDate,
       @d_orderdate_end as EndDate
INTO #Ord
 FROM ORDERS (nolock)
     JOIN OrderDetail (nolock) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey )-- AND OrderDetail.OpenQty <> 0)
     JOIN Storer (nolock) ON (ORDERS.StorerKey = Storer.StorerKey) 
WHERE 1 = 2
GROUP BY ORDERS.OrderDate, ORDERS.OrderKey, ORDERS.ExternOrderKey, ORDERDETAIL.Sku, Storer.Company, Orders.Status

INSERT INTO #Ord
    select ORDERS.OrderDate,   
           ORDERS.OrderKey,   
           ORDERS.ExternOrderKey,   
           ORDERDETAIL.Sku,   
           SUM (OrderDetail.OriginalQty) AS OriginalQty,
           SUM (OrderDetail.ShippedQty) AS ShippedQty,
           SUser_SName() AS User_Name,
           Storer.Company,
           @d_orderdate_start as StartDate,
           @d_orderdate_end as EndDate
     FROM ORDERS (nolock)
         JOIN OrderDetail (nolock) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
         JOIN Storer (nolock) ON (ORDERS.StorerKey = Storer.StorerKey) 
    WHERE
          ORDERS.Status = '9' and
          ORDERS.OrderDate between Cast (Convert (char(8), @d_orderdate_start, 112) as DateTime) and Cast (Convert (char(8), @d_orderdate_end, 112) as DateTime) and
          ORDERS.StorerKey = @c_storerkey and
      --    OrderDetail.OpenQty <> 0 and 
      --    OrderDetail.ShippedQty + OrderDetail.OpenQty <> OrderDetail.OriginalQty
          OrderDetail.ShippedQty <> OrderDetail.OriginalQty 
    GROUP BY ORDERS.OrderDate, ORDERS.OrderKey, ORDERS.ExternOrderKey, ORDERDETAIL.Sku, Storer.Company, Orders.Status

  
SELECT #Ord.*
  FROM #Ord
--      LEFT OUTER JOIN PickDetail ON (PickDetail.OrderKey = #Ord.OrderKey AND PickDetail.Sku = #Ord.Sku)

DROP TABLE #Ord


GO