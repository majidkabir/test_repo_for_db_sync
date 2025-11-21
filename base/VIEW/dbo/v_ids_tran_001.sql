SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


create view [dbo].[V_IDS_TRAN_001]
as
	select convert(NVARCHAR(10), rtrim(upper(itrn.itrnkey))) as 'itrn_itrnkey',
		itrn.trantype as 'itrn_trantype',
		itrn_trantype_desc = case itrn.trantype
										when 'AJ' then 'Adjustment'
										when 'DP' then 'Deposit'
										when 'WD' then 'Withdrawal'
									end,
		convert(NVARCHAR(5), rtrim(upper(loc.facility))) as 'itrn_facility',
		facility.descr as 'itrn_facility_desc',
		convert(NVARCHAR(15), rtrim(upper(itrn.storerkey))) as 'itrn_storer',
		storer.company as 'itrn_company',
		convert(NVARCHAR(20), rtrim(upper(itrn.sku))) as 'itrn_sku',
		convert(NVARCHAR(20), rtrim(upper(sku.manufacturersku))) as 'itrn_manufacturersku',
		convert(NVARCHAR(20), rtrim(upper(sku.retailsku))) as 'itrn_retailsku',
		convert(NVARCHAR(20), rtrim(upper(sku.altsku))) as 'itrn_altsku',
		sku.descr as 'itrn_description',
		(sku.busr1 + sku.busr2) as 'itrn_second_lang_descr',
		convert(NVARCHAR(18), rtrim(upper(sku.susr3))) as 'itrn_principal',
		code_principal.code_desc as 'itrn_principal_desc',
		convert(NVARCHAR(10), rtrim(upper(itrn.lot))) as 'itrn_sys_lot_no',
		convert(NVARCHAR(10), rtrim(upper(itrn.fromloc))) as 'itrn_fromloc',
		convert(NVARCHAR(18), rtrim(upper(itrn.fromid))) as 'itrn_fromid',
		convert(NVARCHAR(10), rtrim(upper(itrn.toloc))) as 'itrn_toloc',
		convert(NVARCHAR(18), rtrim(upper(itrn.toid))) as 'itrn_toid',
		convert(NVARCHAR(20), rtrim(upper(itrn.sourcekey))) as 'itrn_sourcekey',
		itrn.sourcetype as 'itrn_sourcetype',
		itrn.status as 'itrn_status',
		sku.lottable01label as 'itrn_l1_label',
		code_lottable01.code_desc as 'itrn_l1_label_desc',
		lotattribute.lottable01 as 'itrn_l1',
		sku.lottable02label as 'itrn_l2_label',
		code_lottable02.code_desc as 'itrn_l2_label_desc',
		lotattribute.lottable02 as 'itrn_l2',
		sku.lottable03label as 'itrn_l3_label',
		code_lottable03.code_desc as 'itrn_l3_label_desc',
		lotattribute.lottable03 as 'itrn_l3',
		sku.lottable04label as 'itrn_l4_label',
		code_lottable04.code_desc as 'itrn_l4_label_desc',
		lotattribute.lottable04 as 'itrn_l4',
		sku.lottable05label as 'itrn_l5_label',
		code_lottable05.code_desc as 'itrn_l5_label_desc',
		lotattribute.lottable05 as 'itrn_l5',
		itrn.casecnt as 'itrn_case_uom_qty',
		itrn.innerpack as 'itrn_inner_uom_qty',
		itrn.qty as 'itrn_qty',
		itrn.pallet as 'itrn_pallet',
		itrn.cube as 'itrn_cube',
		itrn.grosswgt as 'itrn_grosswgt',
		itrn.netwgt as 'itrn_netwgt',
		itrn.uom as 'itrn_uom',
		code_uom.code_desc as 'itrn_uom_desc',
		itrn.uomqty as 'itrn_uomqty',
		itrn.adddate as 'itrn_adddate',
		itrn.addwho as 'itrn_addwho',
		itrn.editdate as 'itrn_editdate',
		itrn.editwho as 'itrn_editwho',
		convert(NVARCHAR(10), rtrim(upper(sku.packkey))) as 'packkey',
		pack.packuom3 as 'cc_master unit',
		code_uom3.code_desc as 'cc_master_unit_desc',
		pack.qty as 'cc_mu_units',
		pack.packuom2 as 'cc_inner uom',
		code_uom2.code_desc as 'cc_inner_uom_desc',
		pack.innerpack as 'cc_inner_uom_qty',
		pack.packuom1 as 'cc_case_uom',
		code_uom1.code_desc as 'cc_case_uom_desc',
		pack.casecnt as 'cc_case_uom_qty',
		pack.packuom4 as 'cc_pl_uom',
		code_uom4.code_desc as 'cc_pl_uom_desc',
		pack.pallet as 'cc_pl_uom_qty',
		pack.palletti as 'cc_units_per_layer',
		pack.pallethi as 'cc_layers_per_pl',
		itrn_orderkey = case itrn.sourcetype
								when 'ntrpickdetailupdate' then (select convert(NVARCHAR(10), rtrim(upper(orderkey))) 
																			from pickdetail (nolock)
																			where pickdetailkey = itrn.sourcekey)
								else ''
							 end,
		itrn_orderlineno = case itrn.sourcetype
									when 'ntrpickdetailupdate' then (select convert(NVARCHAR(5), rtrim(upper(orderlinenumber))) 
																				from pickdetail (nolock)
																				where pickdetailkey = itrn.sourcekey)
									else ''
								 end,
		itrn_receiptkey = case 
									when itrn.sourcetype in ('ntrreceiptdetailadd', 'ntrreceiptdetailupdate') 
										then convert(NVARCHAR(10), rtrim(upper(substring(itrn.sourcekey,1,10))))
									else ''
								end,
		itrn_receiptlineno = case 
										when itrn.sourcetype in ('ntrreceiptdetailadd', 'ntrreceiptdetailupdate') 
											then convert(NVARCHAR(5), rtrim(upper(substring(itrn.sourcekey,11,5))))
										else ''
									end,
		itrn_kitkey = case 
							when itrn.sourcetype in ('ntrkitdetailadd','ntrkitdetailupdate')
								then convert(NVARCHAR(10), rtrim(upper(substring(itrn.sourcekey,1,10))))
							else ''
						  end,
		itrn_transferkey = case itrn.sourcetype
									when 'ntrtransferdetailupdate' 
										then convert(NVARCHAR(10), rtrim(upper(substring(itrn.sourcekey,1,10))))
								 	else ''
								 end,
	   itrn_transfer_type = case itrn.sourcetype
										when 'ntrtransferdetailupdate' 
											then (select type
													from transfer (nolock)
													where transferkey = substring(itrn.sourcekey,1,10))
									 	else ''
									end,
		itrn_transfer_type_desc = case itrn.sourcetype
											when 'ntrtransferdetailupdate' 
												then (select description
														from transfer (nolock) join codelkup (nolock)
															on transfer.type = codelkup.code
														where transferkey = substring(itrn.sourcekey,1,10)
														  and codelkup.listname = 'TRANTYPE')
										 	else ''
										end,
		itrn_transfer_reason = case itrn.sourcetype
										when 'ntrtransferdetailupdate' 
											then (select convert(NVARCHAR(10), rtrim(upper(reasoncode)))
													from transfer (nolock)
													where transferkey = substring(itrn.sourcekey,1,10))
										else ''
									  end,
		itrn_transfer_reason_desc = case itrn.sourcetype
												when 'ntrtransferdetailupdate' 
													then (select description
															from transfer (nolock) join codelkup (nolock)
																on transfer.reasoncode = codelkup.code
															where transferkey = substring(itrn.sourcekey,1,10)
															  and codelkup.listname = 'TRNREASON')
											 	else ''
											end,
		itrn_adjustmentkey = case itrn.sourcetype
										when 'ntradjustmentdetailadd' 
											then convert(NVARCHAR(10), rtrim(upper(substring(itrn.sourcekey,1,10))))
									 	else ''
									 end,
	   itrn_adjustment_type = case itrn.sourcetype
										when 'ntradjustmentdetailadd' 
											then (select convert(NVARCHAR(3), rtrim(upper(adjustment.adjustmenttype)))
													from adjustment (nolock)
													where adjustmentkey = substring(itrn.sourcekey,1,10))
									 	else ''
									end,
		itrn_adjustment_type_desc = case itrn.sourcetype
												when 'ntradjustmentdetailadd' 
													then (select description
															from adjustment (nolock) join codelkup (nolock)
																on adjustment.adjustmenttype = codelkup.code
															where adjustmentkey = substring(itrn.sourcekey,1,10)
															  and codelkup.listname = 'ADJTYPE')
											 	else ''
											end,
		itrn_adjustment_ref = case itrn.sourcetype
										when 'ntradjustmentdetailadd' 
											then (select customerrefno
													from adjustment (nolock)
													where adjustmentkey = substring(itrn.sourcekey,1,10))
									 	else ''
									end,
		itrn_adjustment_reason = case itrn.sourcetype
											when 'ntradjustmentdetailadd' 
												then (select convert(NVARCHAR(10), rtrim(upper(reasoncode)))
														from adjustmentdetail (nolock)
														where adjustmentkey = substring(itrn.sourcekey,1,10)
														  and adjustmentlinenumber = substring(itrn.sourcekey,11,5))
											else ''
										 end,
		itrn_adjustment_reason_desc = case itrn.sourcetype
													when 'ntradjustmentdetailadd' 
														then (select description
																from adjustmentdetail (nolock) join codelkup (nolock)
																	on adjustmentdetail.reasoncode = codelkup.code
																where adjustmentkey = substring(itrn.sourcekey,1,10)
														  		  and adjustmentlinenumber = substring(itrn.sourcekey,11,5)
																  and codelkup.listname = 'ADJTYPE')
												 	else ''
												end
	from itrn (nolock) join sku (nolock)
		on itrn.storerkey = sku.storerkey
			and itrn.sku = sku.sku
	join storer (nolock)
		on itrn.storerkey = storer.storerkey
	join lotattribute (nolock)
		on itrn.lot = lotattribute.lot
	join pack (nolock)
		on itrn.packkey = pack.packkey
	left outer join loc (nolock)
		on itrn.toloc = loc.loc
	left outer join facility (nolock)
		on loc.facility = facility.facility
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PRINCIPAL') as code_principal
		on sku.susr3 = code_principal.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE01') as code_lottable01
		on sku.lottable01label = code_lottable01.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE02') as code_lottable02
		on sku.lottable02label = code_lottable02.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE03') as code_lottable03
		on sku.lottable03label = code_lottable03.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE04') as code_lottable04
		on sku.lottable04label = code_lottable04.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE05') as code_lottable05
		on sku.lottable05label = code_lottable05.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname in ('QUANTITY','TMUOM')) as code_uom
		on itrn.uom = code_uom.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom1
		on pack.packuom1 = code_uom1.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom2
		on pack.packuom2 = code_uom2.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom3
		on pack.packuom3 = code_uom3.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom4
		on pack.packuom4 = code_uom4.code
	where trantype <> 'MV'





GO