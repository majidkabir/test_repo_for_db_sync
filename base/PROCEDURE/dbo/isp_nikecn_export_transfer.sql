SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[isp_nikecn_export_transfer](
	@c_headerprefix NVARCHAR(1),
	@c_detailprefix NVARCHAR(1),
	@c_trantype NVARCHAR(1),
	@c_transtatus NVARCHAR(1),
	@c_batchid NVARCHAR(15)
)
as
-- insert candidate records into table nikecn_trf on dtsitf db
begin
	declare @c_transmitlogkey NVARCHAR(10),
			@c_key NVARCHAR(10),
			@c_tablename NVARCHAR(30),
			@n_lines int, 
         @c_rcplottable03 NVARCHAR(18),
         @c_ordlottable03 NVARCHAR(18),
         @b_success int,
         @cBatchID NVARCHAR(10), 
         @n_err int,
         @c_errmsg NVARCHAR(200),
         @c_fromwhse NVARCHAR(10),
         @c_facility NVARCHAR(5),
         @c_fusrdef08 NVARCHAR(30),
         @c_towhse NVARCHAR(10),
         @c_fusrdef06 NVARCHAR(30),
         @c_ordfromwhse NVARCHAR(10),
         @c_ordfacility NVARCHAR(5),
         @c_ordfusrdef08 NVARCHAR(30),
         @c_ordtowhse NVARCHAR(10),
         @c_ordfusrdef06 NVARCHAR(30),
         @c_consigneekey NVARCHAR(15),
         @c_NewTranType   NVARCHAR(1),     
         @c_appointmentno NVARCHAR(10),
         @c_fusrdef11 NVARCHAR(30),
         @c_editdate NVARCHAR(11)

	select @c_transmitlogkey = ''
	while(1=1)
	begin
		select @c_transmitlogkey = min(transmitlogkey)
		from transmitlog (nolock)
		where transmitflag = '1'
			and (tablename = 'TFR' or tablename = 'TFO')
			and transmitlogkey > @c_transmitlogkey

		if @@rowcount = 0 or @c_transmitlogkey is null
			break

		select @c_key = key1,
   		    @c_tablename = tablename
		from transmitlog (nolock)
		where transmitlogkey = @c_transmitlogkey

		if @c_tablename = 'TFR'
		begin -- insert receipt records 
			-- insert receipt header
			if Exists (select 1 from dtsitf..nikecn_trf (nolock) 
					where refnum = @c_key 
					and doctype = 'R')
         BEGIN 
            DELETE FROM DTSITF..Nikecn_trf 
            WHERE refnum = @c_key 
					and doctype = 'R'
         END

         SELECT @c_rcplottable03 = ''

         WHILE (1 = 1)
         BEGIN
            SELECT @c_rcpLottable03 = MIN (Lottable03)
            FROM RECEIPTDETAIL (NOLOCK)
            WHERE RECEIPTKEY = @c_key
            AND Lottable03 > @c_rcplottable03 
          
            IF  @c_rcplottable03 is null or @c_rcplottable03 = ''
               BREAK 

            SELECT @c_facility = Facility.Facility,
                   @c_fusrdef08 = Facility.UserDefine08,
                   @c_fusrdef06 = Facility.UserDefine06,
                   @c_fusrdef11 = Facility.UserDefine11,
                   @c_appointmentno = Receipt.appointment_no,
                   @c_editdate = convert(char(11),replace(convert(char(11), Receipt.editdate, 106), ' ','-'))                  
            FROM Facility (nolock), Receipt (nolock)
            WHERE Receipt.Facility = Facility.Facility 
              AND Receipt.Receiptkey = @c_key
               
            SELECT @c_fromwhse = Codelkup.Short
            FROM  Codelkup (nolock)
            --WHERE Codelkup.Code = @c_fusrdef08
            WHERE Codelkup.Code = @c_appointmentno  
            AND Codelkup.Listname = 'Facility'
                
            SELECT @c_towhse = Codelkup.Short 
            FROM  Codelkup (nolock)
            WHERE Codelkup.Code = @c_facility
              AND Codelkup.Listname = 'Facility'

            IF dbo.fnc_RTRIM(@c_fromwhse) <> dbo.fnc_RTRIM(@c_towhse) 
               SELECT @c_NewTranType = 'O'
            ELSE
               SELECT @c_NewTranType = @c_trantype

            -- generate Batch ID
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
            "NIKEBATCHID"
            , 10
            , @cbatchid OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
               
                     
            IF @b_success = 1
            BEGIN
               BEGIN TRAN
               INSERT DTSITF..NIKECN_TRF (rectype, doctype, trantype, transtatus, batchid, refnum, trandate, 
                  whsefrom, whseto, subinvfrom, subinvto, status)
               VALUES (@c_headerprefix, 'R', @c_NewTranType, @c_transtatus, @cBatchID , @c_key, @c_editdate, 
                  @c_fromwhse, @c_towhse, @c_fusrdef11, @c_rcpLottable03, '1')
               COMMIT TRAN

               IF @@ERROR = 0
               BEGIN
	               BEGIN TRAN
                  -- insert receipt detail
                  insert dtsitf..nikecn_trf (rectype, doctype, refnum, batchid, gpc, sku, qty, status)
                  select @c_detailprefix, 'R', rd.receiptkey, @cBatchID, s.susr4, rd.sku, sum(qtyreceived), '1'
                  from receiptdetail rd (nolock) join sku s (nolock) on (rd.storerkey = s.storerkey and rd.sku = s.sku)
                  where rd.receiptkey = @c_key
                    AND rd.Lottable03 = @c_rcpLottable03
                  Group By rd.receiptkey, s.susr4, rd.sku
                  Having sum(qtyreceived) > 0

                  COMMIT TRAN
               END

               BEGIN TRAN		
               Select @n_lines = count(*)
               from dtsitf..nikecn_trf (nolock)
               where refnum = @c_key
                 and rectype = 'L'
                 and doctype = 'R'

               COMMIT TRAN

               BEGIN TRAN
               update dtsitf..nikecn_trf
               set lines = @n_lines
               where batchid = @cBatchID
               and rectype = @c_headerprefix
               and doctype = 'R'
               COMMIT TRAN

            END -- @b_success.
         END -- while
		END
		ELSE -- insert order records			
		BEGIN
         if Exists (select 1 from dtsitf..nikecn_trf (nolock) where refnum = @c_key and doctype = 'O')
         BEGIN
           DELETE FROM DTSITF..Nikecn_trf
           WHERE refnum = @c_key 
			    AND doctype = 'O'
         END
		
         SELECT @c_ordlottable03 = ''

         WHILE (1 = 1)
         BEGIN                            
            Select @c_ordlottable03 = MIN(Lottable03) 
            From   Orderdetail (nolock)
            Where  Orderkey =  @c_key
            AND Lottable03 > @c_ordlottable03

           IF  @c_ordlottable03 is null or @c_ordlottable03 = ''
               BREAK 

            SELECT @c_ordfacility = Facility.Facility,
                   @c_ordfusrdef08 = Facility.UserDefine08,
                   @c_ordfusrdef06 = Facility.UserDefine06,
                   @c_consigneekey = Orders.Consigneekey,
                   @c_editdate = convert(char(11),replace(convert(char(11), Orders.editdate, 106), ' ','-'))
            FROM Facility (nolock), Orders (nolock)
            WHERE Orders.Facility = Facility.Facility 
               AND Orders.Orderkey = @c_key

            SELECT @c_ordfromwhse = Codelkup.Short
            FROM  Codelkup (nolock)
            WHERE Codelkup.Code = @c_ordfacility
              AND Codelkup.Listname = 'Facility'
             
            SELECT @c_ordtowhse = Codelkup.Short 
            FROM  Codelkup (nolock)
            WHERE Codelkup.Code = @c_consigneekey
              AND Codelkup.Listname = 'Facility'

            IF dbo.fnc_RTRIM(@c_ordfromwhse) <> dbo.fnc_RTRIM(@c_ordtowhse) 
               SELECT @c_NewTranType = 'O'
            ELSE
               SELECT @c_NewTranType = @c_trantype
           
            -- generate Batch ID
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
               "NIKEBATCHID"
               , 10
               , @cbatchid OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
             
                     
            IF @b_success = 1
            BEGIN
               BEGIN TRAN
               -- insert order header
               insert dtsitf..nikecn_trf (rectype, doctype, trantype, transtatus, batchid, refnum, trandate, 
                  whsefrom, whseto, subinvfrom, subinvto,status)
               values (@c_headerprefix, 'O', @c_NewTranType, @c_transtatus, @cBatchiD, @c_key, @c_editdate,
                  @c_ordfromwhse, @c_ordtowhse,@c_ordlottable03,@c_ordfusrdef06,'1')
               COMMIT TRAN

               IF @@ERROR = 0
               BEGIN
                  BEGIN TRAN
                  -- insert order detail
                  insert dtsitf..nikecn_trf (rectype, doctype, refnum, batchid, gpc, sku, qty, status)
                  select @c_detailprefix, 'O', od.orderkey, @cBatchiD, s.susr4, od.sku, 
                         sum(shippedqty+qtyallocated+qtypicked), -- SOS# 13562 Modify By SHONG, 18-Aug-2003
                         '1'
                  from orderdetail od (nolock) join sku s (nolock)
                  	on od.storerkey = s.storerkey
                  	and od.sku = s.sku
                  where od.orderkey = @c_key
                  AND OD.Lottable03 = @c_ordlottable03
                  Group By od.orderkey,s.susr4, od.sku
                  Having sum(shippedqty+qtyallocated+qtypicked) > 0 -- SOS# 13562 Modify By SHONG, 18-Aug-2003
               COMMIT TRAN
               END		

               Select @n_lines = count(*)
               from dtsitf..nikecn_trf (nolock)
               where refnum = @c_key
                 and rectype = 'L'
                 and doctype = 'O'
		
   				update dtsitf..nikecn_trf
   				set lines = @n_lines
   				where batchid = @cBatchId
   					and rectype = @c_headerprefix
   					and doctype = 'O'

            END -- B_SUCCESS
         END -- WHILE
		END --
	END	
END

GO