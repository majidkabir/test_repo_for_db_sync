SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCedure [dbo].[nsp_ShowShippedDate](
    @c_storerkey NVARCHAR(15),
    @c_orderkey NVARCHAR(10)
)
as
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   declare @c_mbolkey NVARCHAR(10),
   @d_ord_date datetime,
   @d_ship_date datetime,
   @c_show_del_date NVARCHAR(10),
   @d_date      datetime

   select @d_ord_date = orders.orderdate, 
          @c_mbolkey = orders.mbolkey,
          @d_ship_date= mbol.editdate  
   from orders (nolock) 
   join mbol (nolock) on mbol.mbolkey = orders.mbolkey 
   where orderkey=@c_orderkey
   and storerkey=@c_storerkey

   if  (month(@d_ord_date) < month(@d_ship_date)) or ( year(@d_ord_date) < year(@d_ship_date) )
   begin
      if month(@d_ord_date) + 1 > 12 
         select @d_date = convert(datetime, cast(year(@d_ord_date) + 1 as NVARCHAR(4)) + '0101')
      else      
         select @d_date= convert(datetime, cast(year(@d_ord_date) as NVARCHAR(4)) + right('0' + dbo.fnc_RTrim(cast(month(@d_ord_date) + 1 as NVARCHAR(2))),2) + '01') 

      select @d_date = DateAdd(day, -1, @d_date) 

      select @c_show_del_date=convert(char(10), @d_date, 103)
   end
   else
      select @c_show_del_date=convert(char(10),@d_ship_date,103)

   select @c_show_del_date
end


GO