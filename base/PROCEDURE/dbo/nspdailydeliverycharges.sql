SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspDailyDeliveryCharges                            */
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
/************************************************************************/

CREATE PROC    [dbo].[nspDailyDeliveryCharges]
@c_storerkey_start NVARCHAR(15),
@c_storerkey_end NVARCHAR(15),
@c_MMYYYY NVARCHAR(6)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @storerkey NVARCHAR(15),
   @curr_date_ptr datetime,
   @Van_Normal int,
   @Van_Critical int,
   @Truck_Normal int,
   @Truck_Critical int,
   @Van_Normal_wStand int,
   @Display_Stand int,
   @Will_Call int,
   @Total_no int,
   @Van_multi_trip_order int,
   @Van_multi_trip_trip int,
   @Truck_multi_trip_order int,
   @Truck_multi_trip_trip int,
   @start_date datetime,
   @end_date datetime,
   @OrderKey NVARCHAR(10),
   @OrderDate datetime,
   @MyDate datetime,
   @DeliveryDate datetime,
   @Priority NVARCHAR(10),
   @cnt_unique int,
   @skugroup_rtn int,
   @TransMethod NVARCHAR(1)


   CREATE TABLE #temp(
   StorerKey  NVARCHAR(15),
   mydate datetime,
   Van_Normal int,
   Van_Critical int,
   Truck_Normal int,
   Truck_Critical int,
   Van_Normal_wStand int,
   Display_Stand int,
   Will_Call int,
   Total_no int,
   Van_multi_trip_order int,
   Van_multi_trip_trip int,
   Truck_multi_trip_order int,
   Truck_multi_trip_trip int)

   Create unique index storer_id on #temp(StorerKey,mydate)
   set nocount on
   /*-- Get the start date of the month --, month, day, year*/
   select @start_date = substring(@c_MMYYYY,1,2) + '/01/'+ substring(@c_MMYYYY,3,4)

   /*-- Get the end date of the month --, month, day, year*/
   select @end_date = convert(char, convert(int,substring(@c_MMYYYY,1,2))+1) + '/01/'+ substring(@c_MMYYYY,3,4)

   /*-- Create cursor --*/
   DECLARE Orders_cursor CURSOR FAST_FORWARD READ_ONLY FOR
   (select a.StorerKey, a.OrderDate, a.OrderKey,  a.DeliveryDate, a.Priority, c.TransMethod
   from ORDERS a(nolock), MBOLDETAIL b(nolock), MBOL c(nolock)
   where a.OrderDate >= @start_date
   and a.OrderDate < @end_date
   and b.mbolkey = c.mbolkey
   and b.orderkey = a.orderkey)

   OPEN Orders_cursor
   FETCH NEXT FROM Orders_cursor INTO @StorerKey, @OrderDate, @OrderKey,  @DeliveryDate, @Priority, @TransMethod

   WHILE @@FETCH_STATUS = 0
   BEGIN
      /*mycode.Start*/
      /*--eliminate off the time so to make the date unique, this is because the OrderDate is part of the unique key --*/

      if @StorerKey between @c_storerkey_start and @c_storerkey_end
      BEGIN /*Storerkey, order date.begin*/
         /*-- Initialization --*/
         select @Van_Normal = 0,	@Van_Critical = 0, @Truck_Normal = 0, @Truck_Critical = 0,
         @Van_Normal_wStand = 0, @Display_Stand = 0, @Will_Call = 0, @Total_no = 0, @Van_multi_trip_order = 0,
         @Van_multi_trip_trip = 0, @Truck_multi_trip_order = 0, @Truck_multi_trip_trip = 0

         SELECT @MyDate =  convert(datetime,convert(char(10),@OrderDate,101))

         if @Priority = '10'
         begin -- start priority=10
            select @Will_Call = @Will_Call + 1
            select @Total_no = @Total_no + 1
         end -- end.priority='10'
      else
         if @TransMethod = 'V'
         /*------------------------------------------------------------------------
         For VAN

         Sku with stand is denoted as sku.skugroup = 'CLASS'

         skugroup	--> SOME sku with stand
         --------
         GL-ADVERT	unique = 2 -- many skugroup
         GL-ADVERT	return > 0 -- some or all sku with stand
         CLASS

         skugroup	--> ALL sku with stand
         --------
         CLASS		unique = 1 -- only one skugroup
         CLASS		return > 0 -- some or all sku with stand
         CLASS

         skugroup	--> NONE OF sku with stand
         --------
         GL-ADVERT	unique = 1
         GL-ADVERT	return = 0 -- no sku with stand

         ------------------------------------------------------------------------*/
         begin /*start VAN*/

            select @cnt_unique=0, @skugroup_rtn=0

            select @cnt_unique = count(distinct b.skugroup)
            from orderdetail a(nolock), sku b(nolock)
            where a.sku = b.sku
            and a.orderkey = @OrderKey
            and a.storerkey = @StorerKey

            select @skugroup_rtn = count(*)
            from orderdetail a(nolock), sku b(nolock)
            where a.sku = b.sku
            and a.orderkey = @OrderKey
            and a.storerkey = @StorerKey
            and b.skugroup = 'CLASS'
            group by b.skugroup


            --select @skugroup_rtn = @@rowcount /*-- @@rowcount > 0 implies that 'some or all skus with stand */

            if @skugroup_rtn = 0 /*-- no sku with stand --*/
            begin
               /*-- NONE OF sku with stand --*/
               if @Priority = '50'
               begin
                  select @Van_Normal = @Van_Normal + 1
                  select @Total_no = @Total_no + 1
               end
            else
               if @Priority = '30'
               begin
                  select @Van_Critical = @Van_Critical + 1
                  select @Total_no = @Total_no + 1
               end
            end
         else
            begin
               if @cnt_unique>1
               begin
                  /* SOME skus with stand */
                  select @Van_Normal_wStand = @Van_Normal_wStand + 1
                  select @Total_no = @Total_no + 1
               end
            else
               begin
                  /* ALL skus with stand */
                  select @Display_Stand = @Display_Stand + 1
                  select @Total_no = @Total_no + 1
               end
            end

         end /*end VAN*/
      else
         if @TransMethod = 'T'
         begin /*start truck*/
            if @Priority = '50'
            begin
               select @Truck_Normal = @Truck_Normal + 1
               select @Total_no = @Total_no + 1
            end
         else
            if @Priority = '30'
            begin
               select @Truck_Critical = @Truck_Critical + 1
               select @Total_no = @Total_no + 1
            end
         end /*end truck*/



         --select @Total_no = @Total_no + @Van_Normal + @Van_Critical + @Truck_Normal + @Truck_Critical + @Van_Normal_wStand
         --		+ @Display_Stand + @Will_Call

         if @TransMethod = 'V'
         begin
            select @Van_multi_trip_order = @Van_multi_trip_order + 1

            /*no of trips pertainning to that order for VAN services */
            select @Van_multi_trip_trip = count(*)
            from loadplandetail
            where orderkey = @orderkey
         end

         if @TransMethod = 'T'
         begin
            select @Truck_multi_trip_order = @Truck_multi_trip_order + 1

            /* no of trips pertainning to that order for TRUCK services */
            select @Truck_multi_trip_trip = count(*)
            from loadplandetail
            where orderkey = @orderkey
         end

         if NOT EXISTS (select * from #temp WHERE storerkey = @storerkey and mydate = @MyDate)
         begin /*record not found*/
            INSERT INTO #temp VALUES (@storerkey, @MyDate, @Van_Normal, @Van_Critical, @Truck_Normal, @Truck_Critical,
            @Van_Normal_wStand , @Display_Stand ,@Will_Call ,@Total_no,
            @Van_multi_trip_order , @Van_multi_trip_trip, @Truck_multi_trip_order, @Truck_multi_trip_trip)
         end
      else
         begin
            /*record found and update the temporary file */
            UPDATE #temp
            SET Van_Normal = Van_Normal + @Van_Normal,
            Van_Critical = Van_Critical + @Van_Critical,
            Truck_Normal = Truck_Normal + @Truck_Normal,
            Truck_Critical = Truck_Critical + @Truck_Critical,
            Van_Normal_wStand = Van_Normal_wStand + @Van_Normal_wStand,
            Display_Stand = Display_Stand + @Display_Stand,
            Will_Call = Will_Call + @Will_Call,
            Total_no = Total_no + @Total_no,
            Van_multi_trip_order = Van_multi_trip_order + @Van_multi_trip_order,
            Van_multi_trip_trip = Van_multi_trip_trip + @Van_multi_trip_trip,
            Truck_multi_trip_order = Truck_multi_trip_order + @Truck_multi_trip_order,
            Truck_multi_trip_trip = Truck_multi_trip_trip + @Truck_multi_trip_trip

            WHERE storerkey = @storerkey
            and mydate = @MyDate
         end

      END  /*Storerkey, order date.end*/

      /*mycode.End*/
      FETCH NEXT FROM Orders_cursor INTO @StorerKey, @OrderDate, @OrderKey, @DeliveryDate, @Priority, @TransMethod
   END  /*-- End While --*/

   CLOSE Orders_cursor
   DEALLOCATE Orders_cursor

   select * from #temp order by storerkey, mydate

END


GO