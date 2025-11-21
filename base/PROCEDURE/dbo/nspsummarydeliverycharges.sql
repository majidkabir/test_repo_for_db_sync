SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nspSummaryDeliveryCharges                          */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */  
/* 25-JAN-2017  JayLim   1.2  SQL2012 compatibility modification (Jay01)*/  
/************************************************************************/  
  
CREATE PROC    [dbo].[nspSummaryDeliveryCharges]  
@c_storerkey_start NVARCHAR(15),  
@c_storerkey_end NVARCHAR(15),  
@c_MMYYYY NVARCHAR(6),  
@n_cube_per_order numeric,  -- cube per order rate, $25.00  
@n_min_charges numeric    -- minimum charges per order, $85.00  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
   @Storerkey NVARCHAR(15),  
   @OrderDate datetime,  
   @number int,  
   @OrderKey NVARCHAR(10),  
   @ExternOrderKey NVARCHAR(30),  
   @Priority NVARCHAR(10),  
   @TransMethod  NVARCHAR(1),  
   @OrderDate_FirstLine datetime,  
   @cube_per_order float,  
   @rates float,  
   @charges float,  
   @start_date datetime,  
   @end_date datetime,  
   @total_orders int,  
   @m3_p_ord float,  
   @InvoiceAmount float,  
   @FirstLine int,  
   @cnt int  
   set nocount on  
   /*-- Get the start date of the month --, month, day, year*/  
   select @start_date = substring(@c_MMYYYY,1,2) + '/01/'+ substring(@c_MMYYYY,3,4)  
   /*-- Get the end date of the month --, month, day, year*/  
   select @end_date = convert(char, convert(int,substring(@c_MMYYYY,1,2))+1) + '/01/'+ substring(@c_MMYYYY,3,4)  
   /*-- Create the First Line count orders,  
   this is the consolidation of orders where all the orders  
   are assigned to minimum charges --*/  
   SELECT CAST(a.storerkey as NVARCHAR(15)) as StorerKey,  
   CAST(NULL  as datetime ) as OrderDate,  -- Date  
   CAST(count(*) as int ) as Number, -- count the number of orders  
   CAST(NULL as NVARCHAR(10)) as OrderKey,  -- Order Number  
   CAST(NULL as float) as m3_p_ord, -- cube per order  
   CAST(@n_min_charges as float) as Rates,  
   CAST(  ROUND((@n_min_charges * count(*)), 2  ) as float) as Charges  
   INTO #tmp  
   FROM ORDERS a(nolock), MBOLDETAIL b(nolock), MBOL c(nolock)  
   where a.orderkey = b.orderkey  
   and b.mbolkey = c.mbolkey  
   and a.OrderDate >= @start_date  
   and a.OrderDate < @end_date  
   and a.Priority = '50'  
   and a.storerkey between @c_storerkey_start and @c_storerkey_end  
   and (b.[cube] * @n_cube_per_order) < @n_min_charges  
   and c.TransMethod = 'T'  
   GROUP BY a.storerkey  
   ORDER BY a.storerkey  
   /*-- Create the subsequent Line count orders , this will display  
   the particular line order whereby each order is being charged  
   at a cubic rate --*/  
   INSERT INTO #tmp  
   SELECT a.storerkey,  
   a.orderdate,  
   1, -- always one  
   a.OrderKey,  
   ROUND(b.[cube], 1),  
   @n_cube_per_order,  
   ROUND((b.[cube] * @n_cube_per_order), 2)  
   FROM ORDERS a(nolock), MBOLDETAIL b(nolock), MBOL c(nolock)  
   where a.orderkey = b.orderkey  
   and b.mbolkey = c.mbolkey  
   and a.OrderDate >= @start_date  
   and a.OrderDate < @end_date  
   and a.Priority = '50'  
   and a.storerkey between @c_storerkey_start and @c_storerkey_end  
   and (b.[cube] * @n_cube_per_order ) >= @n_min_charges  
   and c.TransMethod = 'T'  
   order by a.storerkey, a.orderkey  
   select * from #tmp  
   order by storerkey, orderdate  
END  

GO