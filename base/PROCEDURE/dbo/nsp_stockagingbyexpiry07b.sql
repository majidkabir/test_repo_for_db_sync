SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[nsp_StockAgingByExpiry07b](
			@c_storerkey NVARCHAR(15),
		 	@c_fr_skugroup NVARCHAR(10),
			@c_to_skugroup NVARCHAR(10),
			@c_fr_sku NVARCHAR(20),
			@c_to_sku NVARCHAR(20),
			@c_agency_start NVARCHAR(18), -- Added By Vicky 10 June 2003 SOS#11541
         @c_agency_end NVARCHAR(18) ) -- Added By Vicky 10 June 2003 SOS#11541
AS
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
            
declare @c_storer NVARCHAR(15), @c_company NVARCHAR(20),
			@c_product_group NVARCHAR(10),
			@c_product NVARCHAR(20),
			@c_descr NVARCHAR(60),
			@c_packkey NVARCHAR(10),
			@d_expiry_date datetime,
			@i_total_qty int,
			@i_expired_qty int,
			@c_lot NVARCHAR(10),
			@c_agency NVARCHAR(18)

declare @i_lesstwo int,
			@i_twomth int,
			@i_threemth int,
			@i_fourmth int,
			@i_fivemth int,
			@i_sixmth int,
			@i_moresix int,
			@i_morenine int,
			@i_moretwelve int,
			@i_days_apart int


create table #temp_age
(
	storerkey NVARCHAR(15) null,
	skugroup NVARCHAR(20)  null,
	sku NVARCHAR(20)  null,
	lot NVARCHAR(10) null,
	descr NVARCHAR(60) null,
	packkey NVARCHAR(10) null,
	totalqty int null,
	expiredqty int null,
	lesstwo int null,
	twomth int null,	
	threemth int null,
	fourmth int null,
	fivemth int null,
	sixmth int null,
	moresix int null,
	morenine int null,
	moretwelve int null,
	agency NVARCHAR(18) null -- Added By Vicky 10 June 2003 SOS#11541
)


/** (1) cursor for getting the total quantity for each sku **/
declare sku_stock cursor
local dynamic
for
  SELECT STORER.StorerKey, STORER.Company,   
         SKU.SKUGROUP,   
         LOTxLOCxID.Sku,   
         SKU.DESCR,   
         SKU.PACKKey,     
			LOTXLOCXID.Lot,	
         sum(lotxlocxid.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)), -- Added By Vicky 05 Aug 2003 SOS#6811
         SKU.SUSR3  -- Added By Vicky 10 June 2003 SOS#11541
    FROM SKU (nolock),   
         STORER (nolock),   
         LOTxLOCxID (nolock),   
         LOTATTRIBUTE (nolock)  
   WHERE ( STORER.StorerKey = SKU.StorerKey ) and  
         ( LOTxLOCxID.StorerKey = SKU.StorerKey ) and  
         ( LOTxLOCxID.Sku = SKU.Sku ) and  
         ( LOTxLOCxID.StorerKey = LOTATTRIBUTE.StorerKey ) and  
         ( LOTxLOCxID.Sku = LOTATTRIBUTE.Sku ) and  
         ( LOTxLOCxID.Lot = LOTATTRIBUTE.Lot ) and  
         ( LOTxLOCxID.StorerKey = @c_storerkey ) AND  
         ( SKU.SKUGROUP between @c_fr_skugroup and @c_to_skugroup ) AND  
         ( LOTxLOCxID.Sku between @c_fr_sku and @c_to_sku ) and
         ( ISNULL(SKU.SUSR3,'') between @c_agency_start and @c_agency_end )  -- Added By Vicky 10 June 2003 SOS#11541
   GROUP BY STORER.StorerKey, STORER.Company,   
         SKU.SKUGROUP,   
         LOTxLOCxID.Sku,   
         SKU.DESCR,   
         SKU.PACKKey,
			LOTXLOCXID.Lot,
			SKU.SUSR3  -- Added By Vicky 10 June 2003 SOS#11541

open sku_stock

fetch next from sku_stock into 	@c_storer, @c_company,
				@c_product_group,
				@c_product,
				@c_descr,
				@c_packkey,
				@c_lot,
				@i_total_qty,
				@c_agency -- Added By Vicky 10 June 2003 SOS#11541
 
while (@@fetch_status=0)
begin
   select	@i_expired_qty=null,
            @i_lesstwo=null,
   			@i_twomth=null,
   			@i_threemth=null,
   			@i_fourmth=null,
   			@i_fivemth=null,
   			@i_sixmth=null,
   			@i_moresix=null,
   			@i_morenine=null,
   			@i_moretwelve=null


            SELECT @d_expiry_date=LOTATTRIBUTE.Lottable04,   
                   @i_expired_qty=sum(lotxlocxid.qty - (lotxlocxid.Qtyallocated + lotxlocxid.QtyPicked)) -- Added By Vicky 05 Aug 2003 SOS#6811
                FROM SKU (nolock),   
                     STORER (nolock),   
                     LOTxLOCxID (nolock),   
                     LOTATTRIBUTE (nolock)  
               WHERE ( STORER.StorerKey = SKU.StorerKey ) and  
                     ( LOTxLOCxID.StorerKey = SKU.StorerKey ) and  
                     ( LOTxLOCxID.Sku = SKU.Sku ) and  
                     ( LOTxLOCxID.Lot = LOTATTRIBUTE.Lot ) and  
                     ( LOTxLOCxID.StorerKey = @c_storer ) AND  
                     ( SKU.SKUGROUP = @c_product_group ) AND  
                     ( LOTxLOCxID.Sku = @c_product ) AND  
            			( LOTXLOCXID.Lot = @c_lot) and
                     ( LOTATTRIBUTE.Lottable04 > getdate() ) and
                     ( SKU.SUSR3 = @c_agency ) -- Added By Vicky 10 June 2003 SOS#11541
            GROUP BY LOTATTRIBUTE.Lottable04   

            if (@@FETCH_STATUS=0)
            begin
            	select @i_days_apart=datediff(day,@d_expiry_date,getdate())
            	
            	if abs(@i_days_apart) < 60 
            		select @i_lesstwo = @i_expired_qty
		
         		if @i_lesstwo=0
         			select @i_lesstwo=null
            	else 
            		if ((abs(@i_days_apart) >= 60 ) and (abs(@i_days_apart) < 90 ))

         		select @i_twomth=@i_expired_qty
         
         		if @i_twomth=0 
         			select @i_twomth=null
            	else 
            		if ((abs(@i_days_apart) >= 90 ) and (abs(@i_days_apart) < 120))
               		select @i_threemth=@i_expired_qty
	
         		if @i_threemth=0
         			select @i_threemth=null
            	else
            		if ((abs(@i_days_apart) >= 120 ) and (abs(@i_days_apart) < 150))
		
         		select @i_fourmth=@i_expired_qty
         
         		if @i_fourmth=0
         			select @i_fourmth=null
            	else
            		if ((abs(@i_days_apart) >= 150 ) and (abs(@i_days_apart) < 180))
		
         		select @i_fivemth=@i_expired_qty

         		if @i_fivemth=0
         			select @i_fivemth=null
            	else
            		if ((abs(@i_days_apart) >= 180) and (abs(@i_days_apart) < 210))
		
         		select @i_sixmth=@i_expired_qty

         		if @i_sixmth=0
         			select @i_sixmth=null

            	-- another if statement for qty more than 6, 9 , 12 months
            	if ((abs(@i_days_apart) >= 210) and (abs(@i_days_apart) < 270))
            		select @i_moresix=@i_expired_qty
            
            	else
            		if ((abs(@i_days_apart) >= 270) and (abs(@i_days_apart) < 360))
               		select @i_morenine=@i_expired_qty
               	else
               		if abs(@i_days_apart) >= 360 
      	            	select @i_moretwelve=@i_expired_qty
	
               	insert into #temp_age
               		values(	@c_storer, 
               					@c_product_group,
               					@c_product,
               					@c_lot,
               					@c_descr,
               					@c_packkey,
               					@i_total_qty,
               					@i_expired_qty,
               					@i_lesstwo,
               					@i_twomth,
               					@i_threemth,
               					@i_fourmth,
               					@i_fivemth,
               					@i_sixmth,
               					@i_moresix,
               					@i_morenine,
               					@i_moretwelve,
               					@c_agency) -- Added By Vicky 10 June 2003 SOS#11541              
            end
   
            fetch next from sku_stock into 	@c_storer, @c_company,
            				@c_product_group,
            				@c_product,
            				@c_descr,
            				@c_packkey,
            				@c_lot,
            				@i_total_qty,
            				@c_agency -- Added By Vicky 10 June 2003 SOS#11541
end


--close stock_age
--deallocate stock_age

close sku_stock
deallocate sku_stock

-- Added by SHONG
-- SOS# 8277
-- Replace the code I commented above
-- Remove all the sku that have ZERO qty expired
Delete #temp_age
From #temp_age
Join ( select storerkey, sku, sum( isnull(expiredqty,0)) as expiredqty
       from  #temp_age 
       group by storerkey, sku
       having sum( isnull(expiredqty,0)) = 0) as non_expired
   on non_expired.storerkey = #temp_age.storerkey and non_expired.sku = #temp_age.sku 
-- End

select 
	storerkey, skugroup, sku, descr = max(descr), packkey, totalqty = sum(totalqty), expiredqty = sum(expiredqty),
	lesstwo = sum(lesstwo), twomth = sum(twomth), threemth = sum(threemth), fourmth = sum(fourmth), fivemth = sum(fivemth),
	sixmth = sum(sixmth), moresix = sum(moresix), morenine = sum(morenine), moretwelve = sum(moretwelve), agency
from #temp_age 
group by storerkey, skugroup, sku, packkey, agency

drop table #temp_age

end

GO