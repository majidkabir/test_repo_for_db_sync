SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_recompute_load_data]
   @c_loadkey NVARCHAR(10),
   @c_status NVARCHAR(1)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_weight decimal(15,4),
            @n_cube decimal(15,4),
            @n_palletcnt int,
            @n_casecnt int,
            @n_custcnt int,
            @n_ordercnt int,
            @n_err int,
            @c_errmsg NVARCHAR(255),
            @n_header_weight decimal(15,4),
            @n_header_cube decimal(15,4)

   if @c_status = '0' -- compute based on originalqty
   begin -- '0'
      -- compute weight and cube
      select @n_weight = sum(od.originalqty * s.stdgrosswgt),
            @n_cube = sum(od.originalqty * s.stdcube)
      from orderdetail od (nolock) join sku s (nolock)
         on od.storerkey = s.storerkey
            and od.sku = s.sku
      where od.loadkey = @c_loadkey

      -- compute casecnt and palletcnt
      select @n_palletcnt = convert(int, sum(case 
                                                when p.pallet = 0 then 0
                                                else od.originalqty / p.pallet
                                             end)),
            @n_casecnt = convert(int, sum(case 
                                             when p.casecnt = 0 then 0
                                             else od.originalqty / p.casecnt
                                          end))
      from orderdetail od (nolock) join pack p (nolock)
         on od.packkey = p.packkey
      where od.loadkey = @c_loadkey

      -- to cater for 'M' type order from HK
      select @n_header_weight = isnull(sum(o.grossweight), 0), 
            @n_header_cube = isnull(sum(o.capacity), 0)
      from orders o (nolock) left outer join orderdetail od (nolock)
         on o.orderkey = od.orderkey
      where o.loadkey = @c_loadkey
         and od.orderkey is null

      -- compute customer cnt and order cnt
      select @n_custcnt = count (distinct consigneekey),
            @n_ordercnt = count (distinct orderkey)
      from loadplandetail (nolock)
      where loadkey = @c_loadkey

      -- update loadplan with the computed data
      begin tran
      update loadplan
      set trafficcop = null,
         weight = @n_weight + @n_header_weight,
         cube = @n_cube + @n_header_cube,
         palletcnt = @n_palletcnt,
         casecnt = @n_casecnt,
         custcnt = @n_custcnt,
         ordercnt = @n_ordercnt
      where loadkey = @c_loadkey
      select @n_err = @@error
      if @n_err = 0
         commit tran
      else
      begin
         select @c_errmsg = 'Update on Loadplan Failed. (isp_recompute_load_data)'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         rollback tran
         return
      end
   end -- '0'

   if @c_status > '0' -- compute based on alloc + pick + ship qtys
   begin -- > '0'
      -- compute weight and cube
      select @n_weight = sum((od.qtyallocated + od.qtypicked + od.shippedqty) * s.stdgrosswgt),
            @n_cube = sum((od.qtyallocated + od.qtypicked + od.shippedqty) * s.stdcube)
      from orderdetail od (nolock) join sku s (nolock)
         on od.storerkey = s.storerkey
            and od.sku = s.sku
      where od.loadkey = @c_loadkey

      -- compute casecnt and palletcnt
      select @n_palletcnt = convert(int, sum(case 
                                                when p.pallet = 0 then 0
                                                else (od.qtyallocated + od.qtypicked + od.shippedqty) / p.pallet
                                             end)),
            @n_casecnt = convert(int, sum(case 
                                             when p.casecnt = 0 then 0
                                             else (od.qtyallocated + od.qtypicked + od.shippedqty) / p.casecnt
                                          end))
      from orderdetail od (nolock) join pack p (nolock)
         on od.packkey = p.packkey
      where od.loadkey = @c_loadkey

      -- to cater for 'M' type order from HK
      select @n_header_weight = isnull(sum(o.grossweight), 0), 
            @n_header_cube = isnull(sum(o.capacity), 0)
      from orders o (nolock) left outer join orderdetail od (nolock)
         on o.orderkey = od.orderkey
      where o.loadkey = @c_loadkey
         and od.orderkey is null

      -- compute customer cnt and order cnt
      select @n_custcnt = count (distinct consigneekey),
            @n_ordercnt = count (distinct orderkey)
      from loadplandetail (nolock)
      where loadkey = @c_loadkey

      -- update loadplan with the computed data
      begin tran
      update loadplan
      set trafficcop = null,
         allocatedweight = @n_weight + @n_header_weight,
         allocatedcube = @n_cube + @n_header_cube,
         allocatedpalletcnt = @n_palletcnt,
         allocatedcasecnt = @n_casecnt,
         allocatedcustcnt = @n_custcnt,
         allocatedordercnt = @n_ordercnt
      where loadkey = @c_loadkey
      select @n_err = @@error
      if @n_err = 0
         commit tran
      else
      begin
         select @c_errmsg = 'Update on Loadplan Failed. (isp_recompute_load_data)'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         rollback tran
         return
      end
   end -- > '0'
END

GO