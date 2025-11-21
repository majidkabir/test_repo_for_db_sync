SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_CC_vs_System                                           */
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
/***************************************************************************/    
CREATE PROC [dbo].[isp_monthly_by_bizgroup04](
    @c_storerkey NVARCHAR(15),
    @c_datemin NVARCHAR(10),
    @c_datemax NVARCHAR(10),
    @c_ordtype NVARCHAR(10)
 )
 as
 begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 declare @c_busr5 NVARCHAR(30),
         @c_day_fr NVARCHAR(2),
         @c_day_to NVARCHAR(2),
         @c_mth_fr NVARCHAR(2),
         @c_mth_to NVARCHAR(2),
         @c_yr_fr NVARCHAR(4),
         @c_yr_to NVARCHAR(4),
         @d_mtd_fr datetime,
         @d_mtd_to datetime,
         @d_ytd datetime,
         @c_company NVARCHAR(45),
         @d_start_date datetime
 set @c_mth_fr = substring(@c_datemin, 4, 2)
 set @c_day_fr = substring(@c_datemin, 1, 2)
 set @c_yr_fr =  substring(@c_datemin, 7, 4)
 set @c_mth_to = substring(@c_datemax, 4, 2)
 set @c_day_to = substring(@c_datemax, 1, 2)
 set @c_yr_to =  substring(@c_datemax, 7, 4)
 set @d_mtd_fr = convert(datetime,@c_day_fr+'/'+@c_mth_fr+'/'+@c_yr_fr, 103)
 set @d_mtd_to = convert(datetime,@c_day_to+'/'+@c_mth_to+'/'+@c_yr_to, 103)
 set @d_start_date = convert(datetime,"01/01/" + @c_yr_fr)
 create table #resulta(
    ptype NVARCHAR(13) null,
    mth int null,
    yr int null,
    busr5 NVARCHAR(30) null,
    mthkg decimal(10,2) null, -- Jacob 11-01-2002 SOS 3232
    mthcube decimal(10,2) null,
    mthcs decimal(10,2) null-- end SOS 3232
 )
 -- Jacob 16-01-2002 SOS 3232
 insert into #resulta
 select 'Month to Date', 0,0,b.busr5, cast(sum(b.stdgrosswgt*a.shippedqty) as decimal(10,2)), cast(sum(b.stdcube*a.shippedqty) as decimal(10,2)), cast(sum(isnull(a.shippedqty,0) / isnull(c.casecnt,1)) as decimal(10,2))
 from orderdetail a (nolock), sku b (nolock), pack c (nolock), orders d (nolock)
 where a.sku = b.sku
 and b.packkey = c.packkey
 and a.status = '9'
 and b.busr5 is not null
 and b.storerkey = @c_storerkey
 and d.orderkey = a.orderkey
 and d.orderdate >= @d_mtd_fr
 and d.orderdate < dateadd(day,1,@d_mtd_to) 
 and d.type = @c_ordtype
 and b.busr5 <> ''
 group by b.busr5
 insert into #resulta
 select 'Year to Date', month(d.orderdate),year(d.orderdate),b.busr5, cast(sum(b.stdgrosswgt*a.shippedqty) as decimal(10,2)), cast(sum(b.stdcube*a.shippedqty) as decimal(10,2)), cast(sum(isnull(a.shippedqty,0) / isnull(c.casecnt,1)) as decimal(10,2))
 from orderdetail a (nolock), sku b (nolock), pack c (nolock), orders d (nolock)
 where a.sku = b.sku
 and b.packkey = c.packkey
 and a.status = '9'
 and b.busr5 is not null
 and b.storerkey = @c_storerkey
 and d.orderkey = a.orderkey
 and d.orderdate >= @d_start_date
 and d.orderdate < dateadd(day,1,@d_mtd_to) 
 and d.type = @c_ordtype
 and b.busr5 <> ''
 group by month(d.orderdate),year(d.orderdate),b.busr5
 -- END sos 3232
 select @c_company = company
 from storer (nolock)
 where storerkey = @c_storerkey  
 select Suser_Sname(), @c_company, @c_datemin, @c_datemax, @c_ordtype, ptype, mth, yr, busr5, mthkg, mthcube, mthcs from #resulta
 drop table #resulta
 end

GO