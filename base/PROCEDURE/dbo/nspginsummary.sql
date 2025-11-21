SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspGINSummary                                      */
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

CREATE PROCedure [dbo].[nspGINSummary](
@c_storer_start NVARCHAR(15),
@c_storer_end NVARCHAR(15),
@d_receiptdate_start NVARCHAR(10),
@d_receiptdate_end NVARCHAR(10)
)
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare   @c_receiptkey NVARCHAR(10),
   @d_receiptdate datetime,
   @c_cname NVARCHAR(30),
   @c_caddr1 NVARCHAR(45),
   @c_caddr2 NVARCHAR(45),
   @c_addwho NVARCHAR(18),
   @c_notes NVARCHAR(16),
   @i_countsku int
   --select @d_receiptdate_start=convert(datetime,@c_receiptdate_start)
   --select @d_receiptdate_end=convert(datetime,@c_receiptdate_end)
   -- create a temporary table to hold the data
   create table #temp(
   rptnum NVARCHAR(10) null,
   rptdate datetime null,
   cname NVARCHAR(30) null,
   caddr1 NVARCHAR(45) null,
   caddr2 NVARCHAR(45) null,
   addwho NVARCHAR(18) null,
   notes NVARCHAR(16) null,
   countsku int null
   )
   -- cursor for navigating thru receipt and receiptdetail tables
   declare asn_cur cursor FAST_FORWARD READ_ONLY
   for
   SELECT a.receiptkey,
   a.receiptdate,
   a.carriername,
   a.carrieraddress1,
   a.carrieraddress2,
   a.addwho,
   count(b.sku)
   FROM receipt a (NOLOCK), receiptdetail b (NOLOCK)
   WHERE a.receiptdate between convert(datetime,@d_receiptdate_start) AND convert(datetime,@d_receiptdate_end)
   and a.storerkey between @c_storer_start and @c_storer_end
   AND a.receiptkey = b.receiptkey
   GROUP BY a.receiptkey,
   a.receiptdate,
   a.carriername,
   a.carrieraddress1,
   a.carrieraddress2,
   a.addwho
   ORDER BY a.receiptkey
   open asn_cur
   fetch next from asn_cur into @c_receiptkey,@d_receiptdate,@c_cname,@c_caddr1,@c_caddr2, @c_addwho,@i_countsku
   while (@@fetch_status=0)
   begin
      -- get notes from receipt
      declare note_cur cursor FAST_FORWARD READ_ONLY
      for
      select notes from receipt (nolock)
      where receiptkey=@c_receiptkey
      open note_cur
      fetch next from note_cur into @c_notes
      -- insert into the temporary table
      insert into #temp
      values(@c_receiptkey,@d_receiptdate,@c_cname,@c_caddr1,@c_caddr2,@c_addwho,@c_notes,@i_countsku)
      close note_cur
      deallocate note_cur
      -- end of getting notes from receipt
      fetch next from asn_cur into @c_receiptkey,@d_receiptdate,@c_cname,@c_caddr1,@c_caddr2, @c_addwho,@i_countsku
   end
   close asn_cur
   deallocate asn_cur
   select * from #temp
   drop table #temp
end


GO