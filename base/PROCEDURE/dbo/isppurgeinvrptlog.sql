SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispPurgeInvRptLog] 
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
declare @c_invrptlogkey NVARCHAR(10),
         @c_tablename NVARCHAR(30),
         @c_key NVARCHAR(10),
         @d_adddate datetime

select @c_invrptlogkey = ''

while (1=1)
begin
   select @c_invrptlogkey = min(invrptlogkey)
   from invrptlog (nolock)
   where invrptlogkey > @c_invrptlogkey

   if @@rowcount = 0 or @c_invrptlogkey is null
      break

   select @c_tablename = tablename, @c_key = key1, @d_adddate = adddate
   from invrptlog (nolock)
   where invrptlogkey = @c_invrptlogkey

   if @c_tablename = 'ORDDETAIL'
   begin
      if not exists(select orderkey from orders (nolock) where orderkey = @c_key 
							and storerkey Between 'C4LG000000' and 'C4LGZZZZZZ')
      begin 
         print 'deleting ORDDETAIL key : ' + @c_key
         delete invrptlog 
         where key1 = @c_key
            and tablename = @c_tablename
         continue
      end      
   end
   
   if @c_tablename = 'RECEIPT'
   begin
      if not exists(select receiptkey from receipt (nolock) where receiptkey = @c_key 
							and storerkey Between 'C4LG000000' and 'C4LGZZZZZZ') 
      begin
         print 'deleting RECEIPT key : ' + @c_key
         delete invrptlog 
         where key1 = @c_key
            and tablename = @c_tablename
         continue
      end
   end

   if datediff(day, @d_adddate, getdate()) > 30
   begin
      print 'deleting INVRPTLOG key : ' + @c_invrptlogkey

      delete invrptlog
      where invrptlogkey = @c_invrptlogkey
         and invrptflag = '9'
   end
end

GO