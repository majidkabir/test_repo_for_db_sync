SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspDeliveryPerformanceReport                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2014-Mar-21  TLTING   1.1  SQL20112 Bug                            */
/* 2018-Dec-17  TLTING01 1.2  missing nolock                            */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspDeliveryPerformanceReport    Script Date: 09/20/1999 5:18:29 PM ******/
/****** Object:  Stored Procedure dbo.nspDeliveryPerformanceReport    Script Date: 8/23/99 11:15:28 AM ******/
/****** Object:  Stored Procedure dbo.nspDeliveryPerformanceReport    Script Date: 14/07/1999 11:31:08 PM ******/
CREATE PROC [dbo].[nspDeliveryPerformanceReport] (
@OrderkeyFrom           NVARCHAR(10),
@OrderkeyTO             NVARCHAR(10),
@RouteFrom              NVARCHAR(10),
@RouteTo                NVARCHAR(10),
@consigneefrom          NVARCHAR(15),
@consigneeto            NVARCHAR(15) ,
@datefrom		datetime,
@dateto			datetime 
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @storerkey NVARCHAR(15)
DECLARE @orderkey  NVARCHAR(10)
DECLARE @consigneekey NVARCHAR(30)
DECLARE @route NVARCHAR(10) 
DECLARE @amount decimal(28,6) 
declare @quantity integer 
declare @editdate datetime
declare @deliverydate datetime 

declare @totalinvoices decimal (26,8)
declare @withinleadtime decimal (26,8)
declare @Percentagstqty decimal(28,6) 
declare @PercentTotalAmt decimal(28,6)  
declare @totalamount decimal(28,6)  


declare @beyondleadtime decimal (26,8)
declare @Percentagstqtybeyond decimal(28,6) 
declare @PercentTotalAmtbeyond decimal(28,6)    


/*create empty table */


select orders.orderkey, 
       orders.invoiceno invoiceno, 
       CONVERT(decimal (26,8),0) totalinvoices, 
       CONVERT(decimal (26,8), 0.0)  withinleadtime,
       CONVERT(decimal (26,8),0.00) Percentagstqty,
       CONVERT(decimal (26,8),0.00) PercentTotalAmt, 
        CONVERT(decimal (26,8),0.0)  beyondleadtime,
        CONVERT(decimal (26,8),0.00) Percentagstqtybeyond,
        CONVERT(decimal (26,8),0.00) PercentTotalAmtbeyond,       
       orders.route, 
       orders.consigneekey , 
       convert(datetime, convert(char(10), orders.editdate, 101)) editdate, 
       convert(datetime, convert(char(10), orders.deliverydate, 101)) deliverydate, 
       sum(orderdetail.ShippedQty) quantity,
       orders.InvoiceAmount  invoiceamount 
into #RESULT 
 from orders (NOLOCK), orderdetail (NOLOCK)
where orders.orderkey = orderdetail.orderkey 
      and orders.orderkey >= @orderkeyfrom 
      and orders.orderkey <= @orderkeyTo
      and orders.consigneekey > = @consigneefrom
      and orders.consigneekey <= @consigneeto
      and orders.route >= @routefrom

      and route <= @routeto 
      and  ( orders.editdate >= (select Convert( datetime, @datefrom )))
     AND orders.editdate < (select DateAdd( day, 1, Convert( datetime, @dateto ) ) ) and
     orders.status = '9' 
group by 
     orders.orderkey, 
       orders.route, 
       orders.consigneekey ,   
       orders.invoiceno , 
      orders.InvoiceAmount ,
       convert(datetime, convert(char(10), orders.editdate, 101)),
       convert(datetime, convert(char(10), orders.deliverydate, 101)) 
order by convert(datetime, convert(char(10), orders.deliverydate, 101))



select  count(distinct invoiceno) totalinvoices, 
        withinleadtime,
        Percentagstqty,
        PercentTotalAmt, 
        beyondleadtime,
        Percentagstqtybeyond,
        PercentTotalAmtbeyond,       
        route, 
        consigneekey ,  
        deliverydate, 
        sum(quantity) quantity, 
        sum(invoiceamount ) invoiceamount 
into #RESULT1
 from #result 
group by 
     withinleadtime,
        Percentagstqty,
        PercentTotalAmt, 
        beyondleadtime,

        Percentagstqtybeyond,
        PercentTotalAmtbeyond,       
        route, 
        consigneekey ,  
        deliverydate 
order by deliverydate 



   DECLARE GetNextRec cursor FAST_FORWARD READ_ONLY for 
   
    select deliverydate , 
       route, 
       consigneekey 
    from #result 
    group by deliverydate,
             route, 
             consigneekey, 
             deliverydate  
    order by deliverydate, consigneekey, route 


       
   open GetNextRec
   FETCH NEXT FROM GetNextRec 
         INTO  @deliverydate, @route , @consigneekey  
   
WHILE (@@FETCH_STATUS = 0)
     BEGIN  /* fetch loop */
      
     /*-------------- get value for total invoices ----------------*/
          SELECT @withinleadtime = CONVERT(decimal (26,8), count(invoiceno)) , 
                 @totalamount = CONVERT(decimal (26,8), sum(invoiceamount)) 
          from #result 
          where deliverydate = @deliverydate 
          AND   route = @route
          AND   consigneekey = @consigneekey 
          AND deliverydate <= editdate 
       

          UPDATE #result1
          set #result1.withinleadtime = 
                                   CASE

                                    WHEN @withinleadtime = null then 0.0
                                    ELSE
                                      @withinleadtime
                                    END , 
              #result1.Percentagstqty = CASE 
                                           WHEN @withinleadtime = 0.0 then 100
                                           else #result1.totalinvoices / @withinleadtime * 100 end  , 
              #result1.PercentTotalAmt = CASE 
                                           WHEN #result1.PercentTotalAmt = 0 then 100
                                           else @totalamount / #result1.PercentTotalAmt * 100 end ,
              #result1.beyondleadtime = #result1.totalinvoices - @withinleadtime ,
              #result1.Percentagstqtybeyond = CASE 
                                           WHEN @withinleadtime = 0 then 100
                                           else (#result1.totalinvoices - @withinleadtime) / @withinleadtime * 100 end,
              #result1.PercentTotalAmtbeyond = CASE 
                                           WHEN #result1.PercentTotalAmt = 0 then 100
                                           else (#result1.PercentTotalAmt - @totalamount) / #result1.PercentTotalAmt * 100 end 
                    WHERE  #result1.deliverydate = @deliverydate 
          AND    #result1.route = @route
          AND    #result1.consigneekey = @consigneekey 

       FETCH NEXT FROM GetNextRec 

         INTO  @deliverydate, @route , @consigneekey  
    

      END  /* cursor loop */

     close GetNextRec
     deallocate GetNextRec
    
   /* ================== return ================================================== */

       select * 
     from  #RESULT1  
     order by deliverydate, route 



END


GO