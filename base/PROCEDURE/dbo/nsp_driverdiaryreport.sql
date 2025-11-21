SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_DriverDiaryReport                              */
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
/************************************************************************/

CREATE PROCedure [dbo].[nsp_DriverDiaryReport](
@c_mbolkey NVARCHAR(10)
)
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @i_lineno int,
   @c_orderkey NVARCHAR(10),
   @c_storerkey NVARCHAR(15),
   @c_company NVARCHAR(45),
   @c_add1 NVARCHAR(45),
   @c_add2 NVARCHAR(45),
   @c_add3 NVARCHAR(45),
   @f_casecnt float(8),
   @c_drivername NVARCHAR(30),
   @c_vehicle NVARCHAR(30),
   @f_shippedqty float(8),
   @f_ctn float(8),
   @c_externreceiptkey NVARCHAR(20),
   @c_pokey NVARCHAR(18),
   @i_ctn int

   declare @i_count int

   create table #temp(
   line_no int null,
   orderkey NVARCHAR(10)  null,
   storerkey NVARCHAR(15)  null,
   company NVARCHAR(45)  null,
   add1 NVARCHAR(45) null,
   add2 NVARCHAR(45) null,
   add3 NVARCHAR(45) null,
   ctn float(8) null,
   mbolkey NVARCHAR(10) null,
   drivername NVARCHAR(30) null,
   vehicle NVARCHAR(30) null,
   shippedqty float(8) null,
   externreceiptkey NVARCHAR(20) null
   )

   select @i_count=1,
   @f_ctn=0

   select  @c_orderkey=null,
   @c_storerkey=null,
   @c_company=null,
   @c_add1=null,
   @c_add2=null,
   @c_add3=null,
   @i_ctn=null,
   -- @c_mbolkey=null,
   @c_drivername=null,
   @c_vehicle=null,
   @f_shippedqty=null,
   @c_externreceiptkey=null


   declare receipt_cur cursor
   local dynamic
   for
   select externreceiptkey,pokey from receipt
   where mbolkey=@c_mbolkey
   order by pokey desc

   open receipt_cur

   fetch next from receipt_cur into @c_externreceiptkey,@c_pokey

   if (@@fetch_status=0)
   begin -- mbol records that have returns
      while (@@fetch_status=0)
      begin


         if (@c_pokey=null or @c_pokey="")
         begin


            insert into #temp
            values(
            @i_count,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            @c_mbolkey,
            null,
            null,
            null,
            @c_externreceiptkey

            )









         end
      else
         begin

            --select @c_pokey as pokey

            declare order_cur cursor
            local dynamic
            for
            SELECT  ORDERDETAIL.OrderKey,
            ORDERDETAIL.StorerKey,
            ORDERS.C_Company,
            ORDERS.C_Address1,
            ORDERS.C_Address2,
            ORDERS.C_Address3,
            PACK.CaseCnt,
            MBOL.MbolKey,
            MBOL.DRIVERName,
            MBOL.Vessel,
            ORDERDETAIL.ShippedQty
            FROM ORDERDETAIL,
            ORDERS,
            PACK,
            MBOL
            WHERE ( ORDERDETAIL.OrderKey = ORDERS.OrderKey ) and
            ( ORDERDETAIL.PackKey = PACK.PackKey ) and
            ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )and
            ( ORDERDETAIL.ORDERKEY = @c_pokey)

            open order_cur

            fetch next from order_cur into @c_orderkey,
            @c_storerkey,
            @c_company,
            @c_add1,
            @c_add2,
            @c_add3,
            @f_casecnt,
            @c_mbolkey,
            @c_drivername,
            @c_vehicle,
            @f_shippedqty

            select @i_ctn=0
            select @f_ctn=0

            while (@@fetch_status=0)
            begin -- while


               select @f_ctn = @f_ctn+(@f_shippedqty/@f_casecnt)


               fetch next from order_cur into @c_orderkey,
               @c_storerkey,
               @c_company,
               @c_add1,
               @c_add2,
               @c_add3,
               @f_casecnt,
               @c_mbolkey,
               @c_drivername,
               @c_vehicle,
               @f_shippedqty
            end -- while

            select @i_ctn=round(@f_ctn,0)

            insert into #temp
            values(
            @i_count,
            @c_orderkey,
            @c_storerkey,
            @c_company,
            @c_add1,
            @c_add2,
            @c_add3,
            @i_ctn,
            @c_mbolkey,
            @c_drivername,
            @c_vehicle,
            @f_shippedqty,
            @c_externreceiptkey
            )

            close order_cur
            deallocate order_cur

         end

         --initialize before fetch next
         select @c_orderkey=null,
         @c_storerkey=null,
         @c_company=null,
         @c_add1=null,
         @c_add2=null,
         @c_add3=null,
         @f_casecnt=null,
         --@c_mbolkey=null,
         @c_drivername=null,
         @c_vehicle=null,
         @f_shippedqty=null,
         @c_externreceiptkey=null,
         @c_pokey=null




         fetch next from receipt_cur into @c_externreceiptkey,@c_pokey




         select @i_count=@i_count+1
      end

      close receipt_cur
      deallocate receipt_cur

   end
else
   begin -- normal mbol and mboldetail records (no returns)

      close receipt_cur
      deallocate receipt_cur

      declare mbol_cur cursor
      local dynamic
      for
      select orderkey from mboldetail
      where mbolkey=@c_mbolkey
      group by orderkey

      open mbol_cur

      fetch next from mbol_cur into @c_orderkey

      select @i_count=1

      while (@@fetch_status=0)
      begin
         declare ord_cur cursor
         local dynamic
         for
         SELECT  ORDERDETAIL.OrderKey,
         ORDERDETAIL.StorerKey,
         ORDERS.C_Company,
         ORDERS.C_Address1,
         ORDERS.C_Address2,
         ORDERS.C_Address3,
         PACK.CaseCnt,
         MBOL.MbolKey,
         MBOL.DRIVERName,
         MBOL.Vessel,
         ORDERDETAIL.ShippedQty
         FROM ORDERDETAIL,
         ORDERS,
         PACK,
         MBOL
         WHERE ( ORDERDETAIL.OrderKey = ORDERS.OrderKey ) and
         ( ORDERDETAIL.PackKey = PACK.PackKey ) and
         ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )and
         ( ORDERDETAIL.ORDERKEY = @c_orderkey)

         open ord_cur

         fetch next from ord_cur into @c_orderkey,
         @c_storerkey,
         @c_company,
         @c_add1,
         @c_add2,
         @c_add3,
         @f_casecnt,
         @c_mbolkey,
         @c_drivername,
         @c_vehicle,
         @f_shippedqty

         while (@@fetch_status=0)
         begin

            if (@f_casecnt<>0)


            select @f_ctn=@f_ctn+(@f_shippedqty/@f_casecnt)


         else
            select @f_ctn=0

            /**	if @c_orderkey="0000000242"
            begin
            select @f_shippedqty "qty for 242"
            select @f_casecnt "casecnt for 242"
            select @f_ctn "carton for 242"
            end**/




            fetch next from ord_cur into @c_orderkey,
            @c_storerkey,
            @c_company,
            @c_add1,
            @c_add2,
            @c_add3,
            @f_casecnt,
            @c_mbolkey,
            @c_drivername,
            @c_vehicle,
            @f_shippedqty

         end





         select @i_ctn=round(@f_ctn,0)

         insert into #temp
         values(
         @i_count,
         @c_orderkey,
         @c_storerkey,
         @c_company,
         @c_add1,
         @c_add2,
         @c_add3,
         @i_ctn,
         @c_mbolkey,
         @c_drivername,
         @c_vehicle,
         @f_shippedqty,
         @c_externreceiptkey)



         select @f_ctn=0
         select @i_ctn=0
         select @f_shippedqty=0
         close ord_cur
         deallocate ord_cur

         fetch next from mbol_cur into @c_orderkey

         select @i_count=@i_count+1
      end



      close mbol_cur
      deallocate mbol_cur
   end


   UPDATE #TEMP
   SET EXTERNRECEIPTKEY = ORDERS.EXTERNORDERKEY
   FROM #TEMP, ORDERS
   WHERE #TEMP.ORDERKEY = ORDERS.ORDERKEY

   select * from #temp

   drop table #temp

end

GO