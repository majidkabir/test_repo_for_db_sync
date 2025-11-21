SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspMonthlyStorageReport                            */
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

CREATE PROC    [dbo].[nspMonthlyStorageReport]
@c_storerkey NVARCHAR(10),
@c_MMYYYY NVARCHAR(6),
@d_day1 NVARCHAR(2),
@d_day2 NVARCHAR(2),
@d_day3 NVARCHAR(2)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @d_cut_offdate datetime     -- the ending date
   declare @storerkey NVARCHAR(10)         -- itrn
   declare @skugroup NVARCHAR(10)          -- sku
   declare @adddate datetime           -- itrn
   declare @trantype NVARCHAR(10)          -- itrn
   declare @locationcategory NVARCHAR(10)  -- loc
   declare @locationhandling NVARCHAR(10)  -- loc
   declare @toid NVARCHAR(18)              -- itrn
   declare @fromloc NVARCHAR(10)           -- itrn
   declare @toloc NVARCHAR(10)             -- itrn
   declare @qty int                    -- itrn
   declare @sourcekey NVARCHAR(20)         -- itrn
   declare @sourcetype NVARCHAR(30)        -- itrn
   declare @cnt int
   declare @agingdate datetime,
   @d_agingdate1 datetime,
   @d_agingdate2 datetime,
   @d_agingdate3 datetime
   select @cnt = 1
   /*---------------------------------------------------------------------------------------------------------*/
   /* Date conversion and create table to store the aging date                                                */
   /*---------------------------------------------------------------------------------------------------------*/
   select @d_agingdate1 = substring(@c_MMYYYY,1,2) + '/' + substring(@d_day1,1,2) + '/'+ substring(@c_MMYYYY,3,4)
   select @d_agingdate2 = substring(@c_MMYYYY,1,2) + '/' + substring(@d_day2,1,2) + '/'+ substring(@c_MMYYYY,3,4)
   select @d_agingdate3 = substring(@c_MMYYYY,1,2) + '/' + substring(@d_day3,1,2) + '/'+ substring(@c_MMYYYY,3,4)
   create table #AGING ( agingdate datetime )
   insert into #AGING values ( @d_agingdate1 + 1 )
   insert into #AGING values ( @d_agingdate2 + 1 )
   insert into #AGING values ( @d_agingdate3 + 1 )
   /*---------------------------------------------------------------------------------------------------------*/
   /* Create Temp table                                                                                       */
   /*---------------------------------------------------------------------------------------------------------*/
   CREATE TABLE #temp(
   Storerkey NVARCHAR(15),
   Skugroup NVARCHAR(10),
   D1_Normal int ,
   D1_Aircon int ,
   D1_Total int ,
   D1_Total_ft int ,
   D2_Normal int ,
   D2_Aircon int ,
   D2_Total int ,
   D2_Total_ft int ,
   D3_Normal int ,
   D3_Aircon int ,
   D3_Total int ,
   D3_Total_ft int ,
   A_Normal int ,
   A_Aircon int ,
   A_Total int ,
   A_Total_ft int,
   day1 NVARCHAR(2) NULL,
   day2 NVARCHAR(2) NULL,
   day3 NVARCHAR(2) NULL
   )
   CREATE UNIQUE INDEX temp_idx ON #temp (storerkey, skugroup)
   /*---------------------------------------------------------------------------------------------------------*/
   declare aging_cursor cursor FAST_FORWARD READ_ONLY for select agingdate from #aging
   open aging_cursor
   fetch next from aging_cursor into @agingdate
   while ( @@fetch_status = 0 )
   begin
      /*--------------------------------------------------------------------------------------------*/
      /*BODY START                                                                                  */
      /*--------------------------------------------------------------------------------------------*/
      CREATE TABLE #Pallet_Loc (
      skugroup NVARCHAR(10),
      palletid NVARCHAR(18),
      loc NVARCHAR(10),
      locationcategory NVARCHAR(10),
      locationhandling NVARCHAR(10),
      bal_qty int
      )
      CREATE UNIQUE INDEX Pallet_Loc_idx ON #Pallet_Loc ( skugroup, palletid, loc )
      DECLARE Pallet_cursor CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT a.Storerkey,
      b.skugroup,
      a.adddate,
      a.trantype,
      c.locationcategory,
      c.locationhandling,
      a.toid,
      a.fromloc,
      a.toloc,
      a.qty,
      a.sourcekey,
      a.sourcetype
      FROM itrn a(nolock), sku b(nolock), loc c(nolock)
      WHERE a.sku = b.sku
      and a.toloc = c.loc
      and a.ToID <> ''
      and a.storerkey = @c_storerkey
      and a.effectivedate < @agingdate
      ORDER BY a.storerkey, b.skugroup, a.toid, a.adddate
      OPEN Pallet_cursor
      FETCH NEXT FROM Pallet_cursor INTO
      @storerkey, @skugroup, @adddate, @trantype, @locationcategory, @locationhandling, @toid, @fromloc, @toloc, @qty, @sourcekey, @sourcetype
      IF @@FETCH_STATUS <> 0
      PRINT "         <<No Books>>"
      WHILE @@FETCH_STATUS = 0
      BEGIN
         if (@trantype = 'DP')
         begin
            if EXISTS(SELECT * FROM #pallet_loc WHERE skugroup = @skugroup and palletid = @toid and loc = @toloc)
            begin
               update #pallet_loc set bal_qty = bal_qty + @qty where skugroup = @skugroup and palletid = @toid and loc = @toloc
            end
         else
            begin
               insert into #pallet_loc values (@skugroup, @toid, @toloc, @locationcategory, @locationhandling, @qty)
            end
         end
      else if ( @trantype = 'MV' )
         begin
            update #pallet_loc set bal_qty = bal_qty - @qty where skugroup = @skugroup and palletid = @toid and loc = @fromloc
            if EXISTS(SELECT * FROM #pallet_loc WHERE skugroup = @skugroup and palletid = @toid and loc = @toloc)
            begin
               update #pallet_loc set bal_qty = bal_qty + @qty where skugroup = @skugroup and palletid = @toid and loc = @toloc
            end
         else
            begin
               insert into #pallet_loc values (@skugroup, @toid, @toloc, @locationcategory, @locationhandling, @qty)
            end
         end
      else if ( @trantype = 'WD' )
         begin
            update #pallet_loc set bal_qty = bal_qty + @qty where skugroup = @skugroup and palletid = @toid and loc = @toloc
         end
      else if ( @trantype = 'AJ' )
         begin
            update #pallet_loc set bal_qty = bal_qty + @qty where skugroup = @skugroup and palletid = @toid and loc = @toloc
         end
         FETCH NEXT FROM Pallet_cursor INTO
         @storerkey, @skugroup, @adddate, @trantype, @locationcategory, @locationhandling, @toid, @fromloc, @toloc, @qty, @sourcekey, @sourcetype
      END  /* pallet_cursor pallet */
      CLOSE Pallet_cursor
      DEALLOCATE Pallet_cursor
      /*------------------------------------------------------------------------------------------------------
      CALCULATE TOTAL NORMAL   select * from #pallet_loc
      ------------------------------------------------------------------------------------------------------*/
      select skugroup ,
      locationcategory,
      palletid,
      sum(bal_qty) as qty
      into #p_normal1
      from #pallet_loc
      where locationcategory <> 'BULK'
      and locationcategory <> 'AIRCON'
      and locationhandling <> 'SHELF'
      group by skugroup,
      locationcategory,
      palletid
      having sum(bal_qty) > 0
      /**/
      select skugroup ,
      locationcategory,
      palletid,
      sum(bal_qty) as qty
      into #p_normal2
      from #pallet_loc
      where locationcategory <> 'BULK'
      and locationcategory <> 'AIRCON'
      and locationhandling = 'SHELF'
      group by skugroup,
      locationcategory,
      palletid
      having sum(bal_qty) > 0
      /**/
      select skugroup, count(*) as cnt
      into #p_normal1a
      from #p_normal1
      group by skugroup
      /**/
      select skugroup, count(*)/9 as cnt_div_9
      into #p_normal2a
      from #p_normal2
      group by skugroup
      /*perform join for normal*/
      select a.skugroup, (a.cnt + isnull(b.cnt_div_9,0)) as total_normal
      into #normalfinal
      from #p_normal1a as a FULL JOIN #p_normal2a as b
      ON a.skugroup = b.skugroup
      /*------------------------------------------------------------------------------------------------------
      CALCULATE TOTAL AIRCON
      ------------------------------------------------------------------------------------------------------*/
      select skugroup ,
      locationcategory,
      palletid,
      sum(bal_qty) as qty
      into #p_aircon1
      from #pallet_loc
      where locationcategory <> 'BULK'
      and locationcategory = 'AIRCON'
      and locationhandling <> 'SHELF'
      group by skugroup,
      locationcategory,
      palletid
      having sum(bal_qty) > 0
      /**/
      select skugroup ,
      locationcategory,
      palletid,
      sum(bal_qty) as qty
      into #p_aircon2
      from #pallet_loc
      where locationcategory <> 'BULK'
      and locationcategory = 'AIRCON'
      and locationhandling = 'SHELF'
      group by skugroup,
      locationcategory,
      palletid
      having sum(bal_qty) > 0
      /**/
      select skugroup, count(*) as cnt
      into #p_aircon1a
      from #p_aircon1
      group by skugroup
      /**/
      select skugroup, count(*)/9 as cnt_div_9
      into #p_aircon2a
      from #p_aircon2
      group by skugroup
      /*perform join for aircon*/
      select a.skugroup, (a.cnt + isnull(b.cnt_div_9,0)) as total_aircon
      into #airconfinal
      from #p_aircon1a as a FULL JOIN #p_aircon2a as b
      ON a.skugroup = b.skugroup
      /*perform join for normal and aircon*/
      select a.skugroup,
      a.total_normal,
      isnull(b.total_aircon,0) as total_aircon,
      ( a.total_normal + isnull(b.total_aircon,0) ) as total,
      (( a.total_normal + isnull(b.total_aircon,0) ) * 12) as total_sq_ft
      into #final
      from #normalfinal as a FULL JOIN #airconfinal as b
      ON a.skugroup = b.skugroup
      /* writing to #temp, monthly storage utilization report */
      declare  @sg NVARCHAR(10), @tn int, @ta int, @t int, @tsf int
      declare insertion_cursor cursor FAST_FORWARD READ_ONLY for select skugroup, total_normal, total_aircon, total, total_sq_ft from #final
      open insertion_cursor
      fetch next from insertion_cursor into @sg, @tn, @ta, @t, @tsf
      while ( @@fetch_status = 0 )
      begin
         if @cnt = 1
         begin
            insert into #temp values (@c_storerkey, @sg, @tn, @ta, @t, @tsf, 0,0,0,0, 0,0,0,0, 0,0,0,0,@d_day1,@d_day2,@d_day3)
         end
      else if @cnt = 2
         begin
            if exists(select * from #temp where storerkey = @c_storerkey and skugroup = @sg)
            begin
               update #temp
               set D2_Normal = @tn,
               D2_Aircon = @ta,
               D2_Total = @t,
               D2_Total_ft = @tsf
               where storerkey = @c_storerkey
               and skugroup = @sg
            end
         else
            begin
               insert into #temp values (@c_storerkey, @sg, 0,0,0,0, @tn, @ta, @t, @tsf, 0,0,0,0, 0,0,0,0,@d_day1,@d_day2,@d_day3)
            end
         end
      else if @cnt = 3
         begin
            if exists (select * from #temp where storerkey = @c_storerkey and skugroup = @sg)
            begin
               update #temp
               set D3_Normal = @tn,
               D3_Aircon = @ta,
               D3_Total = @t,
               D3_Total_ft = @tsf
               where storerkey = @c_storerkey
               and skugroup = @sg
            end
         else
            begin
               insert into #temp values (@c_storerkey, @sg, 0,0,0,0, 0,0,0,0, @tn, @ta, @t, @tsf, 0,0,0,0,@d_day1,@d_day2,@d_day3)
            end
         end
         fetch next from insertion_cursor into @sg, @tn, @ta, @t, @tsf
      end
      CLOSE insertion_cursor
      DEALLOCATE insertion_cursor
      /*drop normal*/
      drop table #p_normal1
      drop table #p_normal1a
      drop table #p_normal2
      drop table #p_normal2a
      drop table #normalfinal
      /*drop aircon*/
      drop table #p_aircon1
      drop table #p_aircon1a
      drop table #p_aircon2
      drop table #p_aircon2a
      drop table #airconfinal
      drop table #final
      drop table #Pallet_Loc
      /*--------------------------------------------------------------------------------------------*/
      /*BODY END                                                                                    */
      /*--------------------------------------------------------------------------------------------*/
      FETCH NEXT FROM aging_cursor INTO @agingdate
      select @cnt = @cnt + 1
   end /*end while aging_cursor*/
   close aging_cursor
   deallocate aging_cursor
   update #temp
   set A_Normal = (D1_Normal + D2_Normal + D3_Normal)/3,
   A_Aircon = (D1_Aircon + D2_Aircon + D3_Aircon)/3,
   A_Total = (D1_Total + D2_Total + D3_Total)/3,
   A_Total_ft = (D1_Total_ft + D2_Total_ft + D3_Total_ft)/3
   select * from #temp
END


GO